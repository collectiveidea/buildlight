const std = @import("std");
const httpz = @import("httpz");
const pg = @import("pg");
const build_options = @import("build_options");

const db = @import("db.zig");
const handlers = @import("handlers.zig");
const websocket = @import("websocket.zig");
const templates = @import("templates.zig");

pub const Handler = @import("handlers.zig").Handler;

// Global server reference for signal handler
var server_instance: ?*httpz.Server(*Handler) = null;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Parse config from env
    const port_str = std.posix.getenv("PORT") orelse "8080";
    const port = std.fmt.parseInt(u16, port_str, 10) catch 8080;
    const database_url = std.posix.getenv("DATABASE_URL") orelse
        "postgres://localhost/buildlight_development?sslmode=disable";
    const host = std.posix.getenv("HOST") orelse "localhost";
    const particle_token = std.posix.getenv("PARTICLE_ACCESS_TOKEN");
    const debug = std.posix.getenv("DEBUG") != null;

    // Check for "migrate" subcommand
    var args = std.process.args();
    _ = args.next(); // skip program name
    if (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "migrate")) {
            const pool = try db.initPool(allocator, database_url);
            defer pool.deinit();
            try db.migrate(pool);
            std.log.info("Migrations complete", .{});
            return;
        }
    }

    // Init database pool
    const pool = try db.initPool(allocator, database_url);
    defer pool.deinit();

    // Run migrations on startup
    try db.migrate(pool);

    // Create WebSocket hub
    var hub = websocket.Hub.init(allocator);
    defer hub.deinit();

    // Create handler
    var handler = Handler{
        .pool = pool,
        .hub = &hub,
        .allocator = allocator,
        .host = host,
        .particle_token = particle_token,
        .debug = debug,
    };

    // Init server -- note: *Handler (pointer type) so handlers receive *Handler
    var server = try httpz.Server(*Handler).init(allocator, .{
        .address = .all(port),
        .request = .{
            // Required for Travis CI form-encoded payloads and Particle trigger
            .max_form_count = 8,
        },
    }, &handler);
    defer server.deinit();

    // Register signal handlers for graceful shutdown
    std.posix.sigaction(std.posix.SIG.INT, &.{
        .handler = .{ .handler = shutdown },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    }, null);
    std.posix.sigaction(std.posix.SIG.TERM, &.{
        .handler = .{ .handler = shutdown },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    }, null);

    // Register routes
    var router = try server.router(.{});

    // Health check
    router.get("/up", handlers.healthCheck, .{});

    // Static files
    router.get("/public/*", handlers.serveStatic, .{});

    // WebSocket
    router.get("/ws", handlers.wsUpgrade, .{});

    // API routes
    router.get("/api/devices/:id", handlers.apiDeviceShow, .{});
    router.post("/api/device/trigger", handlers.apiDeviceTrigger, .{});
    router.get("/api/device/:id/red", handlers.apiRedShow, .{});

    // Device routes
    router.get("/devices/:id", handlers.deviceShow, .{});

    // Webhook
    router.post("/", handlers.webhookCreate, .{});

    // Colors -- catch-all must be last
    router.get("/:id", handlers.colorsShow, .{});
    router.get("/", handlers.colorsIndex, .{});

    std.log.info("Listening on 0.0.0.0:{d}", .{port});

    server_instance = &server;
    try server.listen();
}

fn shutdown(_: c_int) callconv(.c) void {
    if (server_instance) |server| {
        server_instance = null;
        server.stop();
    }
}

// Re-export all test blocks so `zig build test` discovers them
comptime {
    _ = @import("db.zig");
    _ = @import("models.zig");
    _ = @import("handlers.zig");
    _ = @import("parsers.zig");
    _ = @import("websocket.zig");
    _ = @import("triggers.zig");
    _ = @import("templates.zig");
}
