const std = @import("std");
const httpz = @import("httpz");
const models = @import("models.zig");

const websocket = httpz.websocket;

pub const Hub = struct {
    allocator: std.mem.Allocator,
    mu: std.Thread.Mutex = .{},
    clients: std.AutoHashMap(*WsClient, void),

    pub fn init(allocator: std.mem.Allocator) Hub {
        return .{
            .allocator = allocator,
            .clients = std.AutoHashMap(*WsClient, void).init(allocator),
        };
    }

    pub fn deinit(self: *Hub) void {
        self.clients.deinit();
    }

    pub fn register(self: *Hub, client: *WsClient) void {
        self.mu.lock();
        defer self.mu.unlock();
        self.clients.put(client, {}) catch {};
    }

    pub fn unregister(self: *Hub, client: *WsClient) void {
        self.mu.lock();
        defer self.mu.unlock();
        _ = self.clients.remove(client);
    }

    /// Broadcast a pre-formatted message to all clients subscribed to the channel.
    pub fn broadcast(self: *Hub, channel: []const u8, message: []const u8) void {
        self.mu.lock();
        defer self.mu.unlock();
        var it = self.clients.keyIterator();
        while (it.next()) |client_ptr| {
            const client = client_ptr.*;
            if (client.isSubscribed(channel)) {
                client.conn.write(message) catch {};
            }
        }
    }

    /// Convenience: broadcast colors JSON to a channel.
    pub fn broadcastColors(self: *Hub, channel: []const u8, colors: models.Colors) void {
        var buf: [512]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const writer = fbs.writer();
        writer.writeAll("{\"channel\":\"") catch return;
        writer.writeAll(channel) catch return;
        writer.writeAll("\",\"data\":{\"colors\":") catch return;
        colors.writeJson(writer) catch return;
        writer.writeAll("}}") catch return;
        self.broadcast(channel, fbs.getWritten());
    }
};

pub const WsClient = struct {
    conn: *websocket.Conn,
    hub: *Hub,
    subscriptions: std.StringHashMap(void),

    pub const Context = struct {
        hub: *Hub,
    };

    /// Called by httpz after the WebSocket handshake completes.
    /// Signature must be exactly: init(*websocket.Conn, *const Context) !WsClient
    pub fn init(conn: *websocket.Conn, ctx: *const Context) !WsClient {
        return WsClient{
            .conn = conn,
            .hub = ctx.hub,
            .subscriptions = std.StringHashMap(void).init(std.heap.page_allocator),
        };
    }

    /// Called after init when self is the stable httpz-managed pointer.
    /// Register with the hub here (not in init) to avoid dangling stack pointers.
    pub fn afterInit(self: *WsClient) !void {
        self.hub.register(self);
    }

    /// Called when the client sends a message.
    /// Protocol: {"subscribe": "colors:*"} or {"unsubscribe": "colors:foo"}
    pub fn clientMessage(self: *WsClient, data: []const u8) !void {
        const parsed = std.json.parseFromSlice(
            std.json.Value,
            std.heap.page_allocator,
            data,
            .{},
        ) catch return;
        defer parsed.deinit();

        const obj = switch (parsed.value) {
            .object => |o| o,
            else => return,
        };

        if (obj.get("subscribe")) |sub| {
            switch (sub) {
                .string => |channel| {
                    // Store a copy of the channel name
                    const owned = std.heap.page_allocator.dupe(u8, channel) catch return;
                    self.subscriptions.put(owned, {}) catch {};
                },
                else => {},
            }
        }

        if (obj.get("unsubscribe")) |unsub| {
            switch (unsub) {
                .string => |channel| {
                    if (self.subscriptions.fetchRemove(channel)) |entry| {
                        std.heap.page_allocator.free(entry.key);
                    }
                },
                else => {},
            }
        }
    }

    /// Called when the connection is closed.
    pub fn close(self: *WsClient) void {
        self.hub.unregister(self);
        // Free subscription keys
        var it = self.subscriptions.keyIterator();
        while (it.next()) |key_ptr| {
            std.heap.page_allocator.free(key_ptr.*);
        }
        self.subscriptions.deinit();
    }

    fn isSubscribed(self: *WsClient, channel: []const u8) bool {
        return self.subscriptions.contains(channel);
    }
};
