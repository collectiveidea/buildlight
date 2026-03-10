const std = @import("std");
const pg = @import("pg");

pub const Colors = struct {
    red: i32, // count of red statuses (0 means not red)
    yellow: bool,
    green: bool,

    /// Write JSON with the Rails convention: red is false when 0, integer when > 0.
    /// Example: {"red": false, "yellow": true, "green": false}
    /// Example: {"red": 3, "yellow": false, "green": false}
    pub fn writeJson(self: Colors, writer: anytype) !void {
        try writer.writeAll("{\"red\":");
        if (self.red > 0) {
            try writer.print("{d}", .{self.red});
        } else {
            try writer.writeAll("false");
        }
        try writer.writeAll(",\"yellow\":");
        try writer.writeAll(if (self.yellow) "true" else "false");
        try writer.writeAll(",\"green\":");
        try writer.writeAll(if (self.green) "true" else "false");
        try writer.writeByte('}');
    }

    /// Write booleans-only JSON: {"red": true, "yellow": false, "green": true}
    pub fn writeJsonBooleans(self: Colors, writer: anytype) !void {
        try writer.writeAll("{\"red\":");
        try writer.writeAll(if (self.red > 0) "true" else "false");
        try writer.writeAll(",\"yellow\":");
        try writer.writeAll(if (self.yellow) "true" else "false");
        try writer.writeAll(",\"green\":");
        try writer.writeAll(if (self.green) "true" else "false");
        try writer.writeByte('}');
    }

    /// Returns "RYG", "ryG", "Ryg", etc. Uppercase = active.
    pub fn ryg(self: Colors, buf: *[3]u8) []const u8 {
        buf[0] = if (self.red > 0) 'R' else 'r';
        buf[1] = if (self.yellow) 'Y' else 'y';
        buf[2] = if (self.green) 'G' else 'g';
        return buf[0..3];
    }

    /// Status string: "passing", "failing", "passing-building", "failing-building".
    pub fn statusString(self: Colors) []const u8 {
        if (self.red > 0) {
            return if (self.yellow) "failing-building" else "failing";
        }
        return if (self.yellow) "passing-building" else "passing";
    }
};

pub const Status = struct {
    id: i64,
    service: []const u8,
    project_id: []const u8,
    project_name: []const u8,
    username: []const u8,
    workflow: []const u8,
};

pub const Device = struct {
    id: []const u8,
    name: []const u8,
    identifier: []const u8,
    webhook_url: []const u8,
    slug: []const u8,
    status: []const u8,
};

/// Get aggregated colors for given usernames (null or empty = all statuses).
pub fn getColors(pool: *pg.Pool, usernames: ?[]const []const u8) !Colors {
    if (usernames) |names| {
        if (names.len > 0) return getColorsFiltered(pool, names);
    }
    return getColorsAll(pool);
}

fn getColorsAll(pool: *pg.Pool) !Colors {
    const red_result = try pool.query("SELECT COUNT(*)::int FROM statuses WHERE red = true", .{});
    defer red_result.deinit();
    const red_count: i32 = if (try red_result.next()) |row| try row.get(i32, 0) else 0;

    const yellow_result = try pool.query("SELECT EXISTS(SELECT 1 FROM statuses WHERE yellow = true)", .{});
    defer yellow_result.deinit();
    const yellow: bool = if (try yellow_result.next()) |row| try row.get(bool, 0) else false;

    return Colors{ .red = red_count, .yellow = yellow, .green = red_count == 0 };
}

fn getColorsFiltered(pool: *pg.Pool, usernames: []const []const u8) !Colors {
    const red_result = try pool.query(
        "SELECT COUNT(*)::int FROM statuses WHERE red = true AND username = ANY($1)",
        .{usernames},
    );
    defer red_result.deinit();
    const red_count: i32 = if (try red_result.next()) |row| try row.get(i32, 0) else 0;

    const yellow_result = try pool.query(
        "SELECT EXISTS(SELECT 1 FROM statuses WHERE yellow = true AND username = ANY($1))",
        .{usernames},
    );
    defer yellow_result.deinit();
    const yellow: bool = if (try yellow_result.next()) |row| try row.get(bool, 0) else false;

    return Colors{ .red = red_count, .yellow = yellow, .green = red_count == 0 };
}

/// Get colors for a specific device by querying its watched statuses.
/// Uses a subquery against the devices table so PostgreSQL handles array comparison.
pub fn getDeviceColors(pool: *pg.Pool, device: Device) !Colors {
    const result = try pool.query(
        \\SELECT s.red, s.yellow FROM statuses s
        \\JOIN devices d ON d.id::text = $1
        \\WHERE s.username = ANY(d.usernames)
        \\   OR (s.username || '/' || s.project_name) = ANY(d.projects)
    , .{device.id});
    defer result.deinit();

    var red_count: i32 = 0;
    var yellow_exists = false;
    while (try result.next()) |row| {
        const red: ?bool = try row.get(?bool, 0);
        const yellow: ?bool = try row.get(?bool, 1);
        if (red != null and red.?) red_count += 1;
        if (yellow != null and yellow.?) yellow_exists = true;
    }

    return Colors{
        .red = red_count,
        .yellow = yellow_exists,
        .green = red_count == 0,
    };
}

const device_columns =
    \\SELECT id::text, name, COALESCE(identifier,''),
    \\       COALESCE(webhook_url,''), COALESCE(slug,''), COALESCE(status,'')
    \\FROM devices
;

fn deviceFromRow(row: anytype) !Device {
    return Device{
        .id = try row.get([]const u8, 0),
        .name = try row.get([]const u8, 1),
        .identifier = try row.get([]const u8, 2),
        .webhook_url = try row.get([]const u8, 3),
        .slug = try row.get([]const u8, 4),
        .status = try row.get([]const u8, 5),
    };
}

/// Find device by slug (case-insensitive) or UUID.
pub fn findDeviceBySlugOrId(pool: *pg.Pool, id: []const u8) !?Device {
    const result = try pool.query(
        device_columns ++ " WHERE slug = $1 OR id::text = $1 LIMIT 1",
        .{id},
    );
    defer result.deinit();
    return if (try result.next()) |row| try deviceFromRow(row) else null;
}

/// Find device by UUID only.
pub fn findDeviceById(pool: *pg.Pool, id: []const u8) !?Device {
    const result = try pool.query(
        device_columns ++ " WHERE id::text = $1",
        .{id},
    );
    defer result.deinit();
    return if (try result.next()) |row| try deviceFromRow(row) else null;
}

/// Find device by Particle identifier.
pub fn findDeviceByIdentifier(pool: *pg.Pool, identifier: []const u8) !?Device {
    const result = try pool.query(
        device_columns ++ " WHERE identifier = $1",
        .{identifier},
    );
    defer result.deinit();
    return if (try result.next()) |row| try deviceFromRow(row) else null;
}

/// Upsert a status (find existing by service+username+project_name+project_id+workflow,
/// then insert or update).
pub fn upsertStatus(
    pool: *pg.Pool,
    service: []const u8,
    username: []const u8,
    project_name: []const u8,
    project_id: []const u8,
    workflow: []const u8,
    red: ?bool,
    yellow: ?bool,
    payload: ?[]const u8,
) !void {
    // Try to find existing
    const find_result = try pool.query(
        \\SELECT id FROM statuses
        \\WHERE service = $1
        \\  AND COALESCE(username,'') = COALESCE($2,'')
        \\  AND COALESCE(project_name,'') = COALESCE($3,'')
        \\  AND COALESCE(project_id,'') = COALESCE($4,'')
        \\  AND COALESCE(workflow,'') = COALESCE($5,'')
    , .{ service, username, project_name, project_id, workflow });
    defer find_result.deinit();

    if (try find_result.next()) |row| {
        const id = try row.get(i64, 0);
        _ = try pool.exec(
            \\UPDATE statuses SET red = COALESCE($1, red), yellow = COALESCE($2, yellow),
            \\       payload = $3, username = $4, project_name = $5, updated_at = NOW()
            \\WHERE id = $6
        , .{ red, yellow, payload, username, project_name, id });
    } else {
        _ = try pool.exec(
            \\INSERT INTO statuses (service, username, project_name, project_id,
            \\       workflow, red, yellow, payload, created_at, updated_at)
            \\VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW())
        , .{ service, username, project_name, project_id, workflow, red, yellow, payload });
    }
}

/// Upsert a Travis status, keyed by service + project_id only (matching Rails
/// find_or_initialize_by behavior). This ensures repo renames update in-place.
pub fn upsertTravisStatus(
    pool: *pg.Pool,
    username: []const u8,
    project_name: []const u8,
    project_id: []const u8,
    red: ?bool,
    yellow: ?bool,
    payload: ?[]const u8,
) !void {
    const find_result = try pool.query(
        "SELECT id FROM statuses WHERE service = 'travis' AND project_id = $1",
        .{project_id},
    );
    defer find_result.deinit();

    if (try find_result.next()) |row| {
        const id = try row.get(i64, 0);
        _ = try pool.exec(
            \\UPDATE statuses SET red = COALESCE($1, red), yellow = COALESCE($2, yellow),
            \\       payload = $3, username = $4, project_name = $5, updated_at = NOW()
            \\WHERE id = $6
        , .{ red, yellow, payload, username, project_name, id });
    } else {
        _ = try pool.exec(
            \\INSERT INTO statuses (service, username, project_name, project_id,
            \\       workflow, red, yellow, payload, created_at, updated_at)
            \\VALUES ('travis', $1, $2, $3, '', $4, $5, $6, NOW(), NOW())
        , .{ username, project_name, project_id, red, yellow, payload });
    }
}

/// Find devices watching a given username/project.
pub fn findDevicesForStatus(allocator: std.mem.Allocator, pool: *pg.Pool, username: []const u8, project_name: []const u8) !std.ArrayList(Device) {
    var devices: std.ArrayList(Device) = .empty;
    const name = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ username, project_name });
    defer allocator.free(name);

    const result = try pool.query(
        device_columns ++
            \\ WHERE usernames @> ARRAY[$1]::varchar[]
            \\    OR projects @> ARRAY[$2]::varchar[]
    , .{ username, name });
    defer result.deinit();

    while (try result.next()) |row| {
        try devices.append(allocator, try deviceFromRow(row));
    }
    return devices;
}

/// Get red (failing) statuses for a device.
pub fn getRedStatuses(allocator: std.mem.Allocator, pool: *pg.Pool, device: Device) !std.ArrayList(Status) {
    var statuses: std.ArrayList(Status) = .empty;

    const result = try pool.query(
        \\SELECT s.id, s.service, COALESCE(s.project_id,''), COALESCE(s.project_name,''),
        \\       COALESCE(s.username,''), COALESCE(s.workflow,'')
        \\FROM statuses s
        \\JOIN devices d ON d.id::text = $1
        \\WHERE s.red = true
        \\  AND (s.username = ANY(d.usernames) OR (s.username || '/' || s.project_name) = ANY(d.projects))
    , .{device.id});
    defer result.deinit();

    while (try result.next()) |row| {
        try statuses.append(allocator, Status{
            .id = try row.get(i64, 0),
            .service = try row.get([]const u8, 1),
            .project_id = try row.get([]const u8, 2),
            .project_name = try row.get([]const u8, 3),
            .username = try row.get([]const u8, 4),
            .workflow = try row.get([]const u8, 5),
        });
    }
    return statuses;
}

/// Update a device's status, broadcast via WebSocket, and trigger external webhooks.
pub fn updateDeviceStatus(
    allocator: std.mem.Allocator,
    pool: *pg.Pool,
    hub: anytype,
    device: Device,
    host: []const u8,
    particle_token: ?[]const u8,
) !void {
    const colors = try getDeviceColors(pool, device);
    const new_status = colors.statusString();

    // Broadcast device colors to WebSocket clients
    if (device.slug.len > 0) {
        var channel_buf: [256]u8 = undefined;
        const channel = std.fmt.bufPrint(&channel_buf, "device:{s}", .{device.slug}) catch return;
        hub.broadcastColors(channel, colors);
    }

    if (!std.mem.eql(u8, device.status, new_status)) {
        _ = try pool.exec(
            "UPDATE devices SET status = $1, status_changed_at = NOW(), updated_at = NOW() WHERE id::text = $2",
            .{ new_status, device.id },
        );

        // Trigger external notifications
        const triggers = @import("triggers.zig");
        if (device.webhook_url.len > 0) {
            triggers.triggerWebhook(allocator, device, colors, host);
        }
        if (device.identifier.len > 0) {
            triggers.triggerParticle(allocator, new_status, particle_token);
        }
    }
}

test "Colors.ryg returns correct string" {
    var buf: [3]u8 = undefined;

    const passing = Colors{ .red = 0, .yellow = false, .green = true };
    try std.testing.expectEqualStrings("ryG", passing.ryg(&buf));

    const failing = Colors{ .red = 2, .yellow = false, .green = false };
    try std.testing.expectEqualStrings("Ryg", failing.ryg(&buf));

    const building = Colors{ .red = 0, .yellow = true, .green = true };
    try std.testing.expectEqualStrings("rYG", building.ryg(&buf));

    const all = Colors{ .red = 1, .yellow = true, .green = false };
    try std.testing.expectEqualStrings("RYg", all.ryg(&buf));
}

test "Colors.writeJson produces Rails-compatible output" {
    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    const passing = Colors{ .red = 0, .yellow = false, .green = true };
    try passing.writeJson(fbs.writer());
    try std.testing.expectEqualStrings(
        "{\"red\":false,\"yellow\":false,\"green\":true}",
        fbs.getWritten(),
    );

    fbs.reset();
    const failing = Colors{ .red = 3, .yellow = true, .green = false };
    try failing.writeJson(fbs.writer());
    try std.testing.expectEqualStrings(
        "{\"red\":3,\"yellow\":true,\"green\":false}",
        fbs.getWritten(),
    );
}

test "Colors.writeJsonBooleans always uses booleans" {
    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);

    const failing = Colors{ .red = 3, .yellow = true, .green = false };
    try failing.writeJsonBooleans(fbs.writer());
    try std.testing.expectEqualStrings(
        "{\"red\":true,\"yellow\":true,\"green\":false}",
        fbs.getWritten(),
    );
}
