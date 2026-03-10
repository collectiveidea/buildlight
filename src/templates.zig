const std = @import("std");
const build_options = @import("build_options");
const models = @import("models.zig");

/// Load a template by name. In release mode, returns embedded content.
/// In debug mode, reads from the filesystem for hot-reload.
fn loadTemplate(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    if (build_options.embed_assets) {
        return getEmbedded(name) orelse error.TemplateNotFound;
    }
    // Dev mode: read from disk
    const path = try std.fmt.allocPrint(allocator, "templates/{s}", .{name});
    defer allocator.free(path);
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return file.readToEndAlloc(allocator, 1024 * 1024);
}

fn getEmbedded(name: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, name, "layout.html")) return @embedFile("../templates/layout.html");
    if (std.mem.eql(u8, name, "red.html")) return @embedFile("../templates/red.html");
    return null;
}

/// Render the main layout with traffic light UI.
pub fn renderLayout(allocator: std.mem.Allocator, colors: models.Colors) ![]const u8 {
    const template = try loadTemplate(allocator, "layout.html");

    const status = colors.statusString();

    // Build body attributes
    var attrs_buf: [64]u8 = undefined;
    var attrs_fbs = std.io.fixedBufferStream(&attrs_buf);
    const attrs_writer = attrs_fbs.writer();
    try attrs_writer.writeAll(if (colors.red > 0) " data-failing" else " data-passing");
    if (colors.yellow) try attrs_writer.writeAll(" data-building");
    const body_attrs = attrs_fbs.getWritten();

    // Build favicon path using statusString (passing/failing/passing-building/failing-building)
    var fav_buf: [64]u8 = undefined;
    const favicon = std.fmt.bufPrint(&fav_buf, "/public/favicon-{s}.ico", .{status}) catch "";

    // Build failing count message
    var count_buf: [64]u8 = undefined;
    const count_msg: []const u8 = if (colors.red == 0)
        ""
    else if (colors.red == 1)
        "1 project is"
    else
        std.fmt.bufPrint(&count_buf, "{d} projects are", .{colors.red}) catch "";

    // Simple template replacement
    var result = try allocator.dupe(u8, template);
    result = try replaceAll(allocator, result, "{{.BodyAttrs}}", body_attrs);
    result = try replaceAll(allocator, result, "{{.Favicon}}", favicon);
    result = try replaceAll(allocator, result, "{{.FailingCount}}", count_msg);

    return result;
}

/// Render the red/failing projects page.
pub fn renderRed(allocator: std.mem.Allocator, statuses: []const models.Status) ![]const u8 {
    const template = try loadTemplate(allocator, "red.html");

    if (statuses.len == 0) {
        const no_failures =
            \\<div>&#127881;&#127881;&#127881;&#127881;&#127881;</div>
            \\<h1>You have no failing projects.</h1>
            \\<div>&#127881;&#127881;&#127881;&#127881;&#127881;</div>
        ;
        return try replaceAll(allocator, try allocator.dupe(u8, template), "{{.RedProjects}}", no_failures);
    }

    // Build the project list HTML
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);
    try list.appendSlice(allocator, "<h2>The following projects are failing</h2>\n<ul>\n");
    for (statuses) |s| {
        try list.appendSlice(allocator, "  <li>");
        try list.appendSlice(allocator, s.project_name);
        try list.appendSlice(allocator, "</li>\n");
    }
    try list.appendSlice(allocator, "</ul>");

    return try replaceAll(allocator, try allocator.dupe(u8, template), "{{.RedProjects}}", list.items);
}

/// Simple string replacement (all occurrences). Frees the input haystack and
/// returns a new allocation.
fn replaceAll(allocator: std.mem.Allocator, haystack: []u8, needle: []const u8, replacement: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < haystack.len) {
        if (std.mem.indexOfPos(u8, haystack, i, needle)) |pos| {
            try result.appendSlice(allocator, haystack[i..pos]);
            try result.appendSlice(allocator, replacement);
            i = pos + needle.len;
        } else {
            try result.appendSlice(allocator, haystack[i..]);
            break;
        }
    }
    allocator.free(haystack);
    return result.toOwnedSlice(allocator);
}
