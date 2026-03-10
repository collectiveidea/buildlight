const std = @import("std");
const httpz = @import("httpz");
const build_options = @import("build_options");

const models = @import("models.zig");
const parsers = @import("parsers.zig");
const ws = @import("websocket.zig");
const templates = @import("templates.zig");
const pg = @import("pg");

pub const Handler = struct {
    pool: *pg.Pool,
    hub: *ws.Hub,
    allocator: std.mem.Allocator,
    host: []const u8,
    particle_token: ?[]const u8,
    debug: bool,

    // Required by httpz for WebSocket support
    pub const WebsocketHandler = ws.WsClient;

    // Called when no route matches
    pub fn notFound(_: *Handler, _: *httpz.Request, res: *httpz.Response) !void {
        res.status = 404;
        if (build_options.embed_assets) {
            res.body = @embedFile("../public/404.html");
        } else {
            res.body = "Not Found";
        }
    }

    // Called when a handler returns an error
    pub fn uncaughtError(_: *Handler, req: *httpz.Request, res: *httpz.Response, err: anyerror) void {
        std.log.err("{s} {s}: {}", .{ @tagName(req.method), req.url.path, err });
        res.status = 500;
        if (build_options.embed_assets) {
            res.body = @embedFile("../public/500.html");
        } else {
            res.body = "Internal Server Error";
        }
    }
};

pub fn healthCheck(_: *Handler, _: *httpz.Request, res: *httpz.Response) !void {
    res.status = 200;
    res.body = "OK";
}

/// Hand-rolled static file handler. In production on Fly.io, the [[statics]]
/// config serves these from the CDN. This handler covers local development.
pub fn serveStatic(_: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const path = req.url.path;

    // Strip leading "/public/" to get filename
    if (!std.mem.startsWith(u8, path, "/public/")) {
        res.status = 404;
        return;
    }
    const filename = path["/public/".len..];

    // Prevent directory traversal
    if (std.mem.indexOf(u8, filename, "..") != null) {
        res.status = 403;
        return;
    }

    if (build_options.embed_assets) {
        // In release mode, serve from embedded files
        const content = getEmbeddedPublicFile(filename) orelse {
            res.status = 404;
            return;
        };
        res.content_type = contentTypeForExtension(filename);
        res.body = content;
    } else {
        // In dev mode, read from filesystem
        const full_path = std.fmt.allocPrint(res.arena, "public/{s}", .{filename}) catch {
            res.status = 500;
            return;
        };
        const file = std.fs.cwd().openFile(full_path, .{}) catch {
            res.status = 404;
            return;
        };
        defer file.close();
        const content = file.readToEndAlloc(res.arena, 1024 * 1024 * 2) catch {
            res.status = 500;
            return;
        };
        res.content_type = contentTypeForExtension(filename);
        res.body = content;
    }
}

fn contentTypeForExtension(filename: []const u8) httpz.ContentType {
    if (std.mem.endsWith(u8, filename, ".css")) return .CSS;
    if (std.mem.endsWith(u8, filename, ".js")) return .JS;
    if (std.mem.endsWith(u8, filename, ".html")) return .HTML;
    // Fly.io [[statics]] serves these with proper MIME types in production.
    return .TEXT;
}

fn getEmbeddedPublicFile(name: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, name, "application.css")) return @embedFile("../public/application.css");
    if (std.mem.eql(u8, name, "websocket.js")) return @embedFile("../public/websocket.js");
    if (std.mem.eql(u8, name, "favicon.ico")) return @embedFile("../public/favicon.ico");
    if (std.mem.eql(u8, name, "favicon-failing.ico")) return @embedFile("../public/favicon-failing.ico");
    if (std.mem.eql(u8, name, "favicon-passing.ico")) return @embedFile("../public/favicon-passing.ico");
    if (std.mem.eql(u8, name, "favicon-failing-building.ico")) return @embedFile("../public/favicon-failing-building.ico");
    if (std.mem.eql(u8, name, "favicon-passing-building.ico")) return @embedFile("../public/favicon-passing-building.ico");
    if (std.mem.eql(u8, name, "404.html")) return @embedFile("../public/404.html");
    if (std.mem.eql(u8, name, "422.html")) return @embedFile("../public/422.html");
    if (std.mem.eql(u8, name, "500.html")) return @embedFile("../public/500.html");
    if (std.mem.eql(u8, name, "robots.txt")) return @embedFile("../public/robots.txt");
    if (std.mem.eql(u8, name, "icon.png")) return @embedFile("../public/icon.png");
    if (std.mem.eql(u8, name, "icon.svg")) return @embedFile("../public/icon.svg");
    if (std.mem.eql(u8, name, "collectiveidea.gif")) return @embedFile("../public/collectiveidea.gif");
    return null;
}

pub fn wsUpgrade(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const ctx = ws.WsClient.Context{ .hub = handler.hub };
    if (try httpz.upgradeWebsocket(ws.WsClient, req, res, &ctx) == false) {
        res.status = 400;
        res.body = "invalid websocket handshake";
    }
}

pub fn webhookCreate(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const content_type = req.header("content-type") orelse "";

    // Travis CI sends form-encoded payload
    if (std.mem.startsWith(u8, content_type, "application/x-www-form-urlencoded")) {
        const form_data = try req.formData();
        var it = form_data.iterator();
        while (it.next()) |kv| {
            if (std.mem.eql(u8, kv.key, "payload")) {
                parsers.parseTravis(handler.pool, handler.hub, kv.value, handler.host, handler.particle_token, handler.debug, handler.allocator) catch |err| {
                    std.log.err("ParseTravis error: {}", .{err});
                };
                res.status = 200;
                return;
            }
        }
    }

    // Read JSON body
    const body = req.body() orelse {
        res.status = 400;
        return;
    };

    // Check for CircleCI (has Circleci-Event-Type header)
    if (req.header("circleci-event-type") != null) {
        parsers.parseCircle(handler.pool, handler.hub, body, handler.host, handler.particle_token, handler.debug, handler.allocator) catch |err| {
            std.log.err("ParseCircle error: {}", .{err});
        };
        res.status = 200;
        return;
    }

    // GitHub Actions sends JSON with "repository" containing "owner/repo"
    const parsed = std.json.parseFromSlice(std.json.Value, res.arena, body, .{}) catch {
        res.status = 400;
        return;
    };
    defer parsed.deinit();

    const is_github = switch (parsed.value) {
        .object => |obj| if (obj.get("repository")) |repo| switch (repo) {
            .string => |s| std.mem.indexOf(u8, s, "/") != null,
            else => false,
        } else false,
        else => false,
    };

    if (!is_github) {
        res.status = 400;
        return;
    }

    parsers.parseGithub(handler.pool, handler.hub, body, handler.host, handler.particle_token, handler.debug, handler.allocator) catch |err| {
        std.log.err("ParseGithub error: {}", .{err});
    };
    res.status = 200;
}

pub fn colorsIndex(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    try renderColors(handler, req, res, null);
}

pub fn colorsShow(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const raw_id = req.param("id") orelse {
        res.status = 404;
        return;
    };

    if (std.mem.endsWith(u8, raw_id, ".ryg")) {
        try streamRyg(handler, res, raw_id[0 .. raw_id.len - 4]);
        return;
    }

    if (std.mem.endsWith(u8, raw_id, ".json")) {
        try renderColorsJson(handler, res, raw_id[0 .. raw_id.len - 5]);
        return;
    }

    try renderColors(handler, req, res, raw_id);
}

fn parseUsernames(allocator: std.mem.Allocator, id: []const u8) ![]const []const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    var iter = std.mem.splitSequence(u8, id, ",");
    while (iter.next()) |part| {
        if (part.len > 0) {
            try list.append(allocator, part);
        }
    }
    return list.toOwnedSlice(allocator);
}

/// Extract a string field from a JSON Value object, returning null if not found
/// or if the value is not a string.
fn jsonString(value: std.json.Value, key: []const u8) ?[]const u8 {
    return switch (value) {
        .object => |obj| if (obj.get(key)) |v| switch (v) {
            .string => |s| s,
            else => null,
        } else null,
        else => null,
    };
}

/// Check if the client wants JSON (via Accept header or ?format=json).
fn wantsJson(req: *httpz.Request) !bool {
    const accept = req.header("accept") orelse "";
    if (std.mem.indexOf(u8, accept, "application/json") != null) return true;
    const query = try req.query();
    const format = query.get("format") orelse return false;
    return std.mem.eql(u8, format, "json");
}

fn renderColors(handler: *Handler, req: *httpz.Request, res: *httpz.Response, id: ?[]const u8) !void {
    if (try wantsJson(req)) {
        try renderColorsJson(handler, res, id);
        return;
    }

    const usernames: ?[]const []const u8 = if (id) |i| try parseUsernames(res.arena, i) else null;
    const colors = try models.getColors(handler.pool, usernames);
    try renderColorsHtml(res, colors);
}

fn renderColorsJson(handler: *Handler, res: *httpz.Response, id: ?[]const u8) !void {
    const usernames: ?[]const []const u8 = if (id) |i| try parseUsernames(res.arena, i) else null;
    const colors = try models.getColors(handler.pool, usernames);
    res.content_type = .JSON;
    try colors.writeJson(res.writer());
}

fn renderColorsHtml(res: *httpz.Response, colors: models.Colors) !void {
    res.content_type = .HTML;
    const html = try templates.renderLayout(res.arena, colors);
    res.body = html;
}

/// Stream RYG format. Uses res.chunk() for chunked transfer encoding.
/// Each chunk is 3 bytes (e.g., "rYG") followed by a 1-second sleep.
/// WARNING: This blocks a worker thread per connection. Keep the httpz
/// worker thread count high enough to handle a few concurrent .ryg streams.
fn streamRyg(handler: *Handler, res: *httpz.Response, id: []const u8) !void {
    res.content_type = .TEXT;
    res.header("cache-control", "no-cache");
    res.header("connection", "keep-alive");

    const usernames = try parseUsernames(res.arena, id);

    // Stream in a loop (max 1 hour to prevent infinite blocking)
    var i: usize = 0;
    while (i < 3600) : (i += 1) {
        const colors = models.getColors(handler.pool, usernames) catch break;
        var buf: [3]u8 = undefined;
        const ryg_str = colors.ryg(&buf);
        res.chunk(ryg_str) catch break;
        std.Thread.sleep(1_000_000_000); // 1 second
    }
}

pub fn deviceShow(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const id = req.param("id") orelse {
        res.status = 404;
        return;
    };

    const device = try models.findDeviceBySlugOrId(handler.pool, id) orelse {
        res.status = 404;
        return;
    };

    const colors = try models.getDeviceColors(handler.pool, device);

    if (try wantsJson(req)) {
        res.content_type = .JSON;
        try colors.writeJson(res.writer());
        return;
    }

    try renderColorsHtml(res, colors);
}

pub fn apiDeviceShow(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const id = req.param("id") orelse {
        res.status = 404;
        return;
    };

    const device = try models.findDeviceById(handler.pool, id) orelse {
        res.status = 404;
        return;
    };

    const colors = try models.getDeviceColors(handler.pool, device);

    res.content_type = .JSON;
    const writer = res.writer();
    try writer.writeAll("{\"colors\":");
    try colors.writeJsonBooleans(writer);
    try writer.writeAll(",\"ryg\":\"");
    var buf: [3]u8 = undefined;
    try writer.writeAll(colors.ryg(&buf));
    try writer.writeAll("\"}");
}

pub fn apiDeviceTrigger(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    var core_id: ?[]const u8 = null;

    // Try form data first (Particle sends form-encoded)
    const form_data = try req.formData();
    var it = form_data.iterator();
    while (it.next()) |kv| {
        if (std.mem.eql(u8, kv.key, "coreid")) {
            core_id = kv.value;
            break;
        }
    }

    // Fallback: try JSON body for "coreid" field
    if (core_id == null) {
        if (req.body()) |body| {
            const parsed = std.json.parseFromSlice(std.json.Value, res.arena, body, .{}) catch null;
            if (parsed) |p| {
                defer p.deinit();
                core_id = jsonString(p.value, "coreid");
            }
        }
    }

    if (core_id) |cid| {
        if (try models.findDeviceByIdentifier(handler.pool, cid)) |device| {
            const triggers = @import("triggers.zig");
            const colors = try models.getDeviceColors(handler.pool, device);
            if (device.webhook_url.len > 0) {
                triggers.triggerWebhook(handler.allocator, device, colors, handler.host);
            }
            if (device.identifier.len > 0) {
                triggers.triggerParticle(handler.allocator, colors.statusString(), handler.particle_token);
            }
        }
    }

    res.status = 200;
}

pub fn apiRedShow(handler: *Handler, req: *httpz.Request, res: *httpz.Response) !void {
    const id = req.param("id") orelse {
        res.status = 404;
        return;
    };

    const device = try models.findDeviceByIdentifier(handler.pool, id) orelse {
        res.status = 404;
        return;
    };

    var red_statuses = try models.getRedStatuses(res.arena, handler.pool, device);
    defer red_statuses.deinit(res.arena);

    if (try wantsJson(req)) {
        res.content_type = .JSON;
        const writer = res.writer();
        try writer.writeByte('[');
        for (red_statuses.items, 0..) |s, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.writeAll("{\"username\":\"");
            try writer.writeAll(s.username);
            try writer.writeAll("\",\"project_name\":\"");
            try writer.writeAll(s.project_name);
            try writer.writeAll("\"}");
        }
        try writer.writeByte(']');
        return;
    }

    // HTML response
    res.content_type = .HTML;
    res.body = try templates.renderRed(res.arena, red_statuses.items);
}
