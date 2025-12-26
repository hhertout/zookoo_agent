const std = @import("std");

// ============================================================================
// Linux Memory Metrics Collector
// ============================================================================
//
// Collects memory metrics from /proc/meminfo on Linux systems.
//
// METRICS COLLECTED:
// ------------------
// - total:      Total usable RAM (MemTotal)
// - free:       Free RAM (MemFree)
// - available:  Available memory for new applications (MemAvailable)
// - buffers:    Memory used by kernel buffers (Buffers)
// - cached:     Memory used for page cache (Cached)
// - swap_total: Total swap space (SwapTotal)
// - swap_free:  Free swap space (SwapFree)
//
// All values are in bytes.
//
// USAGE:
// ------
//   const memory = @import("collectors/memory.zig");
//
//   var metrics = try memory.collect();
//   std.debug.print("Total: {} bytes\n", .{metrics.total});
//   std.debug.print("Available: {} bytes\n", .{metrics.available});
//   std.debug.print("Usage: {d:.1}%\n", .{metrics.usagePercent()});
//
// ============================================================================

/// Memory metrics collected from the system
pub const MemoryMetrics = struct {
    /// Total usable RAM in bytes
    total: u64 = 0,
    /// Free RAM in bytes
    free: u64 = 0,
    /// Available memory for new applications in bytes
    available: u64 = 0,
    /// Memory used by kernel buffers in bytes
    buffers: u64 = 0,
    /// Memory used for page cache in bytes
    cached: u64 = 0,
    /// Total swap space in bytes
    swap_total: u64 = 0,
    /// Free swap space in bytes
    swap_free: u64 = 0,

    /// Calculate used memory in bytes (total - available)
    pub fn used(self: MemoryMetrics) u64 {
        if (self.available > self.total) return 0;
        return self.total - self.available;
    }

    /// Calculate memory usage percentage (0-100)
    pub fn usagePercent(self: MemoryMetrics) f64 {
        if (self.total == 0) return 0;
        return @as(f64, @floatFromInt(self.used())) / @as(f64, @floatFromInt(self.total)) * 100.0;
    }

    /// Calculate swap usage in bytes
    pub fn swapUsed(self: MemoryMetrics) u64 {
        if (self.swap_free > self.swap_total) return 0;
        return self.swap_total - self.swap_free;
    }

    /// Calculate swap usage percentage (0-100)
    pub fn swapUsagePercent(self: MemoryMetrics) f64 {
        if (self.swap_total == 0) return 0;
        return @as(f64, @floatFromInt(self.swapUsed())) / @as(f64, @floatFromInt(self.swap_total)) * 100.0;
    }
};

/// Error types for memory collection
pub const CollectError = error{
    FileNotFound,
    ReadError,
    ParseError,
    NotLinux,
};

/// Collect memory metrics from /proc/meminfo
/// Returns a MemoryMetrics struct with current memory information
pub fn collect() CollectError!MemoryMetrics {
    // Check if we're on Linux
    if (comptime @import("builtin").os.tag != .linux) {
        return CollectError.NotLinux;
    }

    return collectFromFile("/proc/meminfo");
}

/// Collect memory metrics from a specific file (useful for testing)
pub fn collectFromFile(path: []const u8) CollectError!MemoryMetrics {
    const file = std.fs.openFileAbsolute(path, .{}) catch {
        return CollectError.FileNotFound;
    };
    defer file.close();

    var metrics = MemoryMetrics{};
    var buf: [4096]u8 = undefined;

    const bytes_read = file.readAll(&buf) catch {
        return CollectError.ReadError;
    };

    const content = buf[0..bytes_read];
    var lines = std.mem.splitScalar(u8, content, '\n');

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        // Parse line format: "FieldName:     12345 kB"
        const colon_pos = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const field_name = line[0..colon_pos];
        const value_part = std.mem.trim(u8, line[colon_pos + 1 ..], " \t");

        // Extract numeric value (remove " kB" suffix if present)
        const space_pos = std.mem.indexOfScalar(u8, value_part, ' ') orelse value_part.len;
        const value_str = value_part[0..space_pos];

        const value_kb = std.fmt.parseInt(u64, value_str, 10) catch continue;
        const value_bytes = value_kb * 1024; // Convert from kB to bytes

        // Match field names
        if (std.mem.eql(u8, field_name, "MemTotal")) {
            metrics.total = value_bytes;
        } else if (std.mem.eql(u8, field_name, "MemFree")) {
            metrics.free = value_bytes;
        } else if (std.mem.eql(u8, field_name, "MemAvailable")) {
            metrics.available = value_bytes;
        } else if (std.mem.eql(u8, field_name, "Buffers")) {
            metrics.buffers = value_bytes;
        } else if (std.mem.eql(u8, field_name, "Cached")) {
            metrics.cached = value_bytes;
        } else if (std.mem.eql(u8, field_name, "SwapTotal")) {
            metrics.swap_total = value_bytes;
        } else if (std.mem.eql(u8, field_name, "SwapFree")) {
            metrics.swap_free = value_bytes;
        }
    }

    return metrics;
}

// ============================================================================
// Tests
// ============================================================================

test "MemoryMetrics.used calculation" {
    const metrics = MemoryMetrics{
        .total = 16 * 1024 * 1024 * 1024, // 16 GB
        .available = 8 * 1024 * 1024 * 1024, // 8 GB
    };
    try std.testing.expectEqual(@as(u64, 8 * 1024 * 1024 * 1024), metrics.used());
}

test "MemoryMetrics.usagePercent calculation" {
    const metrics = MemoryMetrics{
        .total = 100,
        .available = 25,
    };
    try std.testing.expectApproxEqAbs(@as(f64, 75.0), metrics.usagePercent(), 0.01);
}

test "MemoryMetrics.usagePercent with zero total" {
    const metrics = MemoryMetrics{
        .total = 0,
        .available = 0,
    };
    try std.testing.expectEqual(@as(f64, 0), metrics.usagePercent());
}

test "MemoryMetrics.swapUsed calculation" {
    const metrics = MemoryMetrics{
        .swap_total = 8 * 1024 * 1024 * 1024, // 8 GB
        .swap_free = 6 * 1024 * 1024 * 1024, // 6 GB
    };
    try std.testing.expectEqual(@as(u64, 2 * 1024 * 1024 * 1024), metrics.swapUsed());
}

test "parse meminfo content" {
    // Create a temporary test file
    const test_content =
        \\MemTotal:       16384000 kB
        \\MemFree:         2048000 kB
        \\MemAvailable:    8192000 kB
        \\Buffers:          512000 kB
        \\Cached:          4096000 kB
        \\SwapTotal:       8192000 kB
        \\SwapFree:        8000000 kB
    ;

    // Write to temp file
    const tmp_path = "/tmp/zookoo_test_meminfo";
    const tmp_file = std.fs.createFileAbsolute(tmp_path, .{}) catch return;
    defer std.fs.deleteFileAbsolute(tmp_path) catch {};
    tmp_file.writeAll(test_content) catch return;
    tmp_file.close();

    // Parse it
    const metrics = collectFromFile(tmp_path) catch return;

    try std.testing.expectEqual(@as(u64, 16384000 * 1024), metrics.total);
    try std.testing.expectEqual(@as(u64, 2048000 * 1024), metrics.free);
    try std.testing.expectEqual(@as(u64, 8192000 * 1024), metrics.available);
    try std.testing.expectEqual(@as(u64, 512000 * 1024), metrics.buffers);
    try std.testing.expectEqual(@as(u64, 4096000 * 1024), metrics.cached);
    try std.testing.expectEqual(@as(u64, 8192000 * 1024), metrics.swap_total);
    try std.testing.expectEqual(@as(u64, 8000000 * 1024), metrics.swap_free);
}
