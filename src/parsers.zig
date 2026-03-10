const std = @import("std");
const pg = @import("pg");
const models = @import("models.zig");
const ws = @import("websocket.zig");

const JsonObject = std.json.ObjectMap;

/// Extract a required string field from a JSON object map.
fn getString(obj: JsonObject, key: []const u8) ![]const u8 {
    const val = obj.get(key) orelse return error.MissingField;
    return switch (val) {
        .string => |s| s,
        else => error.InvalidField,
    };
}

/// Extract an optional string field from a JSON object map, returning a default.
fn getStringOr(obj: JsonObject, key: []const u8, default: []const u8) []const u8 {
    const val = obj.get(key) orelse return default;
    return switch (val) {
        .string => |s| s,
        else => default,
    };
}

/// Extract a required nested object from a JSON object map.
fn getObject(obj: JsonObject, key: []const u8) !JsonObject {
    const val = obj.get(key) orelse return error.MissingField;
    return switch (val) {
        .object => |o| o,
        else => error.InvalidField,
    };
}

/// Parse a GitHub Actions webhook payload.
/// Expected JSON: {"repository": "owner/repo", "workflow": "...", "status": "success|failure|""}
pub fn parseGithub(
    pool: *pg.Pool,
    hub: *ws.Hub,
    body: []const u8,
    host: []const u8,
    particle_token: ?[]const u8,
    debug: bool,
    allocator: std.mem.Allocator,
) !void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch
        return error.InvalidJson;
    defer parsed.deinit();
    const root = parsed.value.object;

    const repo_str = try getString(root, "repository");

    // Must contain "/" to be a GitHub payload
    const slash_idx = std.mem.indexOf(u8, repo_str, "/") orelse return error.InvalidField;
    const username = repo_str[0..slash_idx];
    const project_name = repo_str[slash_idx + 1 ..];

    const workflow = getStringOr(root, "workflow", "");
    const status_str = getStringOr(root, "status", "");

    var red: ?bool = null;
    var yellow: ?bool = false;

    if (status_str.len == 0) {
        // No status = building: set yellow but do NOT change red
        yellow = true;
    } else if (std.mem.eql(u8, status_str, "success")) {
        red = false;
    } else if (std.mem.eql(u8, status_str, "failure")) {
        red = true;
    } else {
        // Ignore unknown statuses (cancelled, skipped, etc.)
        return;
    }

    const payload: ?[]const u8 = if (debug) body else null;

    try models.upsertStatus(pool, "github", username, project_name, "", workflow, red, yellow, payload);

    broadcastStatusUpdate(allocator, pool, hub, username, project_name, host, particle_token);
}

/// Parse a Travis CI webhook payload (already extracted from form data "payload" field).
/// The payload is a JSON string.
pub fn parseTravis(
    pool: *pg.Pool,
    hub: *ws.Hub,
    payload_str: []const u8,
    host: []const u8,
    particle_token: ?[]const u8,
    debug: bool,
    allocator: std.mem.Allocator,
) !void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, payload_str, .{}) catch
        return error.InvalidJson;
    defer parsed.deinit();
    const root = parsed.value.object;

    // Ignore pull requests
    if (std.mem.eql(u8, getStringOr(root, "type", ""), "pull_request")) return;

    const repo = try getObject(root, "repository");
    const owner_name = try getString(repo, "owner_name");
    const repo_name = try getString(repo, "name");

    // Get repository ID as string (can be integer or string in JSON)
    var repo_id_buf: [32]u8 = undefined;
    const repo_id: []const u8 = if (repo.get("id")) |v| switch (v) {
        .integer => |i| std.fmt.bufPrint(&repo_id_buf, "{d}", .{i}) catch "",
        .string => |s| s,
        else => "",
    } else "";

    const status_message = getStringOr(root, "status_message", "");

    var red: ?bool = null;
    var yellow: ?bool = false;

    if (std.mem.eql(u8, status_message, "Pending")) {
        // Pending sets yellow but does NOT change red
        yellow = true;
    } else if (std.mem.eql(u8, status_message, "Passed") or
        std.mem.eql(u8, status_message, "Fixed"))
    {
        red = false;
    } else {
        red = true;
    }

    const payload: ?[]const u8 = if (debug) payload_str else null;

    try models.upsertTravisStatus(pool, owner_name, repo_name, repo_id, red, yellow, payload);
    broadcastStatusUpdate(allocator, pool, hub, owner_name, repo_name, host, particle_token);
}

/// Parse a CircleCI webhook payload.
/// Only handles "workflow-completed" events on main/master branches.
pub fn parseCircle(
    pool: *pg.Pool,
    hub: *ws.Hub,
    body: []const u8,
    host: []const u8,
    particle_token: ?[]const u8,
    debug: bool,
    allocator: std.mem.Allocator,
) !void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch
        return error.InvalidJson;
    defer parsed.deinit();
    const root = parsed.value.object;

    // Only handle workflow-completed
    if (!std.mem.eql(u8, getStringOr(root, "type", ""), "workflow-completed")) return;

    // Only process main/master branches
    const pipeline = getObject(root, "pipeline") catch return;
    const vcs = getObject(pipeline, "vcs") catch return;
    const branch = getString(vcs, "branch") catch return;
    if (!std.mem.eql(u8, branch, "main") and !std.mem.eql(u8, branch, "master")) return;

    const org_name = try getString(try getObject(root, "organization"), "name");
    const project_name = try getString(try getObject(root, "project"), "name");
    const workflow_status = try getString(try getObject(root, "workflow"), "status");

    // CircleCI always sets yellow=false
    const red: bool = !std.mem.eql(u8, workflow_status, "success");
    const payload: ?[]const u8 = if (debug) body else null;

    try models.upsertStatus(pool, "circle", org_name, project_name, "", "", red, false, payload);
    broadcastStatusUpdate(allocator, pool, hub, org_name, project_name, host, particle_token);
}

/// After a status upsert, broadcast colors to WebSocket clients and update devices.
fn broadcastStatusUpdate(
    allocator: std.mem.Allocator,
    pool: *pg.Pool,
    hub: *ws.Hub,
    username: []const u8,
    project_name: []const u8,
    host: []const u8,
    particle_token: ?[]const u8,
) void {
    // Broadcast to global colors channel
    const all_colors = models.getColors(pool, null) catch return;
    hub.broadcastColors("colors:*", all_colors);

    // Broadcast to per-username channel
    const user_colors = models.getColors(pool, &.{username}) catch return;
    var channel_buf: [256]u8 = undefined;
    const channel = std.fmt.bufPrint(&channel_buf, "colors:{s}", .{username}) catch return;
    hub.broadcastColors(channel, user_colors);

    // Update watching devices
    var devices = models.findDevicesForStatus(allocator, pool, username, project_name) catch return;
    defer devices.deinit(allocator);
    for (devices.items) |device| {
        models.updateDeviceStatus(allocator, pool, hub, device, host, particle_token) catch {};
    }
}

const db = @import("db.zig");

var test_pool: ?*pg.Pool = null;

fn getTestPool() !*pg.Pool {
    if (test_pool) |p| return p;
    const url = std.posix.getenv("TEST_DATABASE_URL") orelse
        "postgresql://gaffneyc:buildlight_test@127.0.0.1/buildlight_test";
    // Use page_allocator for the pool since it's a process-lifetime singleton.
    // Using testing.allocator would report false "leaks" for pool internals.
    test_pool = try db.initPool(std.heap.page_allocator, url);
    // Run migrations once
    try db.migrate(test_pool.?);
    return test_pool.?;
}

test "parseGithub creates a status for success" {
    const pool = try getTestPool();
    var hub = ws.Hub.init(std.testing.allocator);
    defer hub.deinit();

    // Clean up from previous runs
    _ = try pool.exec("DELETE FROM statuses WHERE service = 'github'", .{});

    const payload =
        \\{"repository":"collectiveidea/buildlight","workflow":"CI","status":"success"}
    ;

    try parseGithub(pool, &hub, payload, "localhost", null, false, std.testing.allocator);

    const result = try pool.query(
        "SELECT username, project_name, red, yellow FROM statuses WHERE service = 'github'",
        .{},
    );
    defer result.deinit();
    const row = (try result.next()) orelse return error.TestFailure;
    try std.testing.expectEqualStrings("collectiveidea", try row.get([]const u8, 0));
    try std.testing.expectEqualStrings("buildlight", try row.get([]const u8, 1));
    try std.testing.expect((try row.get(?bool, 2)) == false); // red = false
    try std.testing.expect((try row.get(?bool, 3)) == false); // yellow = false
}

test "parseGithub sets yellow when status is empty" {
    const pool = try getTestPool();
    var hub = ws.Hub.init(std.testing.allocator);
    defer hub.deinit();

    _ = try pool.exec("DELETE FROM statuses WHERE service = 'github'", .{});

    const payload =
        \\{"repository":"org/repo","workflow":"build","status":""}
    ;

    try parseGithub(pool, &hub, payload, "localhost", null, false, std.testing.allocator);

    const result = try pool.query(
        "SELECT yellow FROM statuses WHERE service = 'github' AND username = 'org'",
        .{},
    );
    defer result.deinit();
    const row = (try result.next()) orelse return error.TestFailure;
    try std.testing.expect((try row.get(?bool, 0)) == true);
}

test "parseCircle ignores non-main branches" {
    const pool = try getTestPool();
    var hub = ws.Hub.init(std.testing.allocator);
    defer hub.deinit();

    _ = try pool.exec("DELETE FROM statuses WHERE service = 'circle'", .{});

    const payload =
        \\{"type":"workflow-completed","pipeline":{"vcs":{"branch":"feature"}},"organization":{"name":"ci"},"project":{"name":"app"},"workflow":{"status":"success"}}
    ;

    try parseCircle(pool, &hub, payload, "localhost", null, false, std.testing.allocator);

    const result2 = try pool.query(
        "SELECT COUNT(*)::int FROM statuses WHERE service = 'circle'",
        .{},
    );
    defer result2.deinit();
    const row2 = (try result2.next()) orelse return error.TestFailure;
    try std.testing.expectEqual(@as(i32, 0), try row2.get(i32, 0));
}

test "parseCircle creates status for main branch success" {
    const pool = try getTestPool();
    var hub = ws.Hub.init(std.testing.allocator);
    defer hub.deinit();

    _ = try pool.exec("DELETE FROM statuses WHERE service = 'circle'", .{});

    const payload2 =
        \\{"type":"workflow-completed","pipeline":{"vcs":{"branch":"main"}},"organization":{"name":"myorg"},"project":{"name":"myapp"},"workflow":{"status":"success"}}
    ;

    try parseCircle(pool, &hub, payload2, "localhost", null, false, std.testing.allocator);

    const result3 = try pool.query(
        "SELECT username, project_name, red FROM statuses WHERE service = 'circle'",
        .{},
    );
    defer result3.deinit();
    const row3 = (try result3.next()) orelse return error.TestFailure;
    try std.testing.expectEqualStrings("myorg", try row3.get([]const u8, 0));
    try std.testing.expectEqualStrings("myapp", try row3.get([]const u8, 1));
    try std.testing.expect((try row3.get(?bool, 2)) == false); // success = not red
}

test "parseTravis ignores pull requests" {
    const pool = try getTestPool();
    var hub = ws.Hub.init(std.testing.allocator);
    defer hub.deinit();

    _ = try pool.exec("DELETE FROM statuses WHERE service = 'travis'", .{});

    const payload =
        \\{"type":"pull_request","repository":{"id":123,"owner_name":"org","name":"repo"},"status_message":"Passed"}
    ;

    try parseTravis(pool, &hub, payload, "localhost", null, false, std.testing.allocator);

    const result4 = try pool.query(
        "SELECT COUNT(*)::int FROM statuses WHERE service = 'travis'",
        .{},
    );
    defer result4.deinit();
    const row4 = (try result4.next()) orelse return error.TestFailure;
    try std.testing.expectEqual(@as(i32, 0), try row4.get(i32, 0));
}
