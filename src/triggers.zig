const std = @import("std");
const models = @import("models.zig");

/// Send a POST to the device's webhook URL with colors as JSON body.
/// Fire-and-forget: errors are logged but do not propagate.
pub fn triggerWebhook(
    allocator: std.mem.Allocator,
    device: models.Device,
    colors: models.Colors,
    host: []const u8,
) void {
    // Build JSON body
    var body_buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&body_buf);
    const writer = fbs.writer();
    writer.writeAll("{\"colors\":") catch return;
    colors.writeJsonBooleans(writer) catch return;
    writer.writeByte('}') catch return;
    const body = fbs.getWritten();

    // Build RYG header value
    var ryg_buf: [3]u8 = undefined;
    const ryg = colors.ryg(&ryg_buf);

    // Build device URL header value
    var url_buf: [256]u8 = undefined;
    const device_url = std.fmt.bufPrint(&url_buf, "https://{s}/api/devices/{s}", .{ host, device.id }) catch return;

    // Make HTTP request using fetch
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse(device.webhook_url) catch {
        std.log.err("TriggerWebhook: invalid URL {s}", .{device.webhook_url});
        return;
    };

    _ = client.fetch(.{
        .location = .{ .uri = uri },
        .method = .POST,
        .payload = body,
        .extra_headers = &.{
            .{ .name = "content-type", .value = "application/json" },
            .{ .name = "x-ryg", .value = ryg },
            .{ .name = "x-device-url", .value = device_url },
        },
    }) catch |err| {
        std.log.err("TriggerWebhook: fetch error {}", .{err});
        return;
    };
}

/// Publish a build_state event to Particle.io.
/// Fire-and-forget: errors are logged but do not propagate.
pub fn triggerParticle(
    allocator: std.mem.Allocator,
    status: []const u8,
    token: ?[]const u8,
) void {
    const access_token = token orelse return;
    if (access_token.len == 0) return;

    // Build JSON body
    var body_buf: [256]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf,
        \\{{"name":"build_state","data":"{s}","ttl":3600,"private":false}}
    , .{status}) catch return;

    // Build auth header value
    var auth_buf: [256]u8 = undefined;
    const auth = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{access_token}) catch return;

    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    _ = client.fetch(.{
        .location = .{ .url = "https://api.particle.io/v1/devices/events" },
        .method = .POST,
        .payload = body,
        .extra_headers = &.{
            .{ .name = "content-type", .value = "application/json" },
            .{ .name = "authorization", .value = auth },
        },
    }) catch |err| {
        std.log.err("TriggerParticle: fetch error {}", .{err});
        return;
    };
}
