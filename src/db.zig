const std = @import("std");
const pg = @import("pg");

/// Initialize a connection pool from a DATABASE_URL string.
pub fn initPool(allocator: std.mem.Allocator, url: []const u8) !*pg.Pool {
    const uri = std.Uri.parse(url) catch return error.InvalidDatabaseUrl;
    return pg.Pool.initUri(allocator, uri, .{
        .size = 5,
    });
}

/// Run all pending migrations. Each migration is embedded at compile time.
/// To add a new migration: add an entry to the `migrations` tuple below.
pub fn migrate(pool: *pg.Pool) !void {
    // Ensure schema_migrations table exists
    _ = try pool.exec(
        \\CREATE TABLE IF NOT EXISTS schema_migrations (
        \\    version VARCHAR NOT NULL
        \\)
    , .{});
    _ = try pool.exec(
        "CREATE UNIQUE INDEX IF NOT EXISTS unique_schema_migrations ON schema_migrations (version)",
        .{},
    );

    const migrations = .{
        .{ .version = "001", .sql = @embedFile("migrations/001_initial_schema.sql") },
        // Future migrations go here:
        // .{ .version = "002", .sql = @embedFile("migrations/002_add_foo.sql") },
    };

    inline for (migrations) |m| {
        // Check if already applied
        const result = try pool.query(
            "SELECT version FROM schema_migrations WHERE version = $1",
            .{m.version},
        );
        const already_applied = (try result.next()) != null;
        result.deinit();

        if (!already_applied) {
            std.log.info("Running migration {s}", .{m.version});
            _ = try pool.exec(m.sql, .{});
            _ = try pool.exec(
                "INSERT INTO schema_migrations (version) VALUES ($1)",
                .{m.version},
            );
        }
    }
}
