const std = @import("std");

pub const Metric = struct {
    mem_total: ?u64,
    mem_free: ?u64,
    mem_available: ?u64,
    mem_buffers: ?u64,
    mem_cached: ?u64,
    mem_swap_total: ?u64,
    mem_swap_free: ?u64,
    mem_used: ?u64,
    mem_usage_percent: ?u64,
    swap_used: ?u64,
    swap_usage_percent: ?u64,

    fn init() Metric {
        return Metric{
            .mem_total = null,
            .mem_free = null,
            .mem_available = null,
            .mem_buffers = null,
            .mem_cached = null,
            .mem_swap_total = null,
            .mem_swap_free = null,
            .mem_used = null,
            .mem_usage_percent = null,
            .swap_used = null,
            .swap_usage_percent = null,
        };
    }

    pub fn display(self: *const Metric, buf: []u8) ![]u8 {
        return std.fmt.bufPrint(buf, "mem_total={d} mem_free={d} mem_available={d} mem_buffers={d} mem_cached={d} mem_swap_total={d} mem_swap_free={d} mem_used={d} mem_usage_percent={d} swap_used={d} swap_usage_percent={d}", .{
            self.mem_total orelse 0,
            self.mem_free orelse 0,
            self.mem_available orelse 0,
            self.mem_buffers orelse 0,
            self.mem_cached orelse 0,
            self.mem_swap_total orelse 0,
            self.mem_swap_free orelse 0,
            self.mem_used orelse 0,
            self.mem_usage_percent orelse 0,
            self.swap_used orelse 0,
            self.swap_usage_percent orelse 0,
        });
    }

    fn computeMemUsed(self: *Metric) void {
        const total = self.mem_total orelse 0;
        const available = self.mem_available orelse 0;
        if (available > total) {
            self.mem_used = 0;
        } else {
            self.mem_used = total - available;
        }
    }

    fn computeMemUsagePercent(self: *Metric) void {
        const total = self.mem_total orelse 0;
        const used = self.mem_used orelse 0;
        if (total == 0) {
            self.mem_usage_percent = 0;
        } else {
            self.mem_usage_percent = 100 * used / total;
        }
    }

    fn computeSwapUsed(self: *Metric) void {
        const total = self.mem_swap_total orelse 0;
        const free = self.mem_swap_free orelse 0;
        if (free > total) {
            self.swap_used = 0;
        } else {
            self.swap_used = total - free;
        }
    }

    fn computeSwapUsagePercent(self: *Metric) void {
        const total = self.mem_swap_total orelse 0;
        const used = self.swap_used orelse 0;
        if (total == 0) {
            self.swap_usage_percent = 0;
        } else {
            self.swap_usage_percent = 100 * used / total;
        }
    }
};

// read /proc/meminfo and return raw metrics
fn readMemInfo() !Metric {
    const file = try std.fs.cwd().openFile("/proc/meminfo", .{});
    defer file.close();

    var buffer: [4096]u8 = undefined;
    const bytes_read = try file.readAll(&buffer);
    const content = buffer[0..bytes_read];

    return parseMemInfo(content);
}

// parse /proc/meminfo content to extract metrics
fn parseMemInfo(fileContent: []const u8) !Metric {
    var metrics = Metric.init();
    var lines = std.mem.splitScalar(u8, fileContent, '\n');

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        // Format: "FieldName:     12345 kB"
        const colon_pos = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const field_name = line[0..colon_pos];
        const value_part = std.mem.trim(u8, line[colon_pos + 1 ..], " \t");

        // Extract numeric value (remove " kB" suffix)
        const space_pos = std.mem.indexOfScalar(u8, value_part, ' ') orelse value_part.len;
        const value_str = value_part[0..space_pos];

        const value_kb = std.fmt.parseInt(u64, value_str, 10) catch continue;
        const value_bytes = value_kb * 1024; // Convert kB to bytes

        if (std.mem.eql(u8, field_name, "MemTotal")) {
            metrics.mem_total = value_bytes;
        } else if (std.mem.eql(u8, field_name, "MemFree")) {
            metrics.mem_free = value_bytes;
        } else if (std.mem.eql(u8, field_name, "MemAvailable")) {
            metrics.mem_available = value_bytes;
        } else if (std.mem.eql(u8, field_name, "Buffers")) {
            metrics.mem_buffers = value_bytes;
        } else if (std.mem.eql(u8, field_name, "Cached")) {
            metrics.mem_cached = value_bytes;
        } else if (std.mem.eql(u8, field_name, "SwapTotal")) {
            metrics.mem_swap_total = value_bytes;
        } else if (std.mem.eql(u8, field_name, "SwapFree")) {
            metrics.mem_swap_free = value_bytes;
        }
    }

    return metrics;
}

/// Collect error type
pub const CollectError = error{
    FileNotFound,
    ReadError,
};

// retrieve all memory metrics - returns error instead of using state logger
pub fn getMemoryMetrics() CollectError!Metric {
    var metrics = readMemInfo() catch {
        return CollectError.ReadError;
    };

    // compute derived metrics
    metrics.computeMemUsed();
    metrics.computeMemUsagePercent();
    metrics.computeSwapUsed();
    metrics.computeSwapUsagePercent();

    return metrics;
}

// ============================================================================
// Tests
// ============================================================================

test "parseMemInfo with valid content" {
    const test_content =
        \\MemTotal:       16384000 kB
        \\MemFree:         2048000 kB
        \\MemAvailable:    8192000 kB
        \\Buffers:          512000 kB
        \\Cached:          4096000 kB
        \\SwapTotal:       8192000 kB
        \\SwapFree:        8000000 kB
    ;

    const metrics = try parseMemInfo(test_content);

    try std.testing.expectEqual(@as(u64, 16384000 * 1024), metrics.mem_total.?);
    try std.testing.expectEqual(@as(u64, 2048000 * 1024), metrics.mem_free.?);
    try std.testing.expectEqual(@as(u64, 8192000 * 1024), metrics.mem_available.?);
    try std.testing.expectEqual(@as(u64, 512000 * 1024), metrics.mem_buffers.?);
    try std.testing.expectEqual(@as(u64, 4096000 * 1024), metrics.mem_cached.?);
    try std.testing.expectEqual(@as(u64, 8192000 * 1024), metrics.mem_swap_total.?);
    try std.testing.expectEqual(@as(u64, 8000000 * 1024), metrics.mem_swap_free.?);
}

test "computeMemUsed calculation" {
    var metrics = Metric.init();
    metrics.mem_total = 16 * 1024 * 1024 * 1024; // 16 GB
    metrics.mem_available = 8 * 1024 * 1024 * 1024; // 8 GB

    metrics.computeMemUsed();

    try std.testing.expectEqual(@as(u64, 8 * 1024 * 1024 * 1024), metrics.mem_used.?);
}

test "computeMemUsagePercent calculation" {
    var metrics = Metric.init();
    metrics.mem_total = 100;
    metrics.mem_used = 75;

    metrics.computeMemUsagePercent();

    try std.testing.expectEqual(@as(u64, 75), metrics.mem_usage_percent.?);
}

test "computeSwapUsed calculation" {
    var metrics = Metric.init();
    metrics.mem_swap_total = 8 * 1024 * 1024 * 1024; // 8 GB
    metrics.mem_swap_free = 6 * 1024 * 1024 * 1024; // 6 GB

    metrics.computeSwapUsed();

    try std.testing.expectEqual(@as(u64, 2 * 1024 * 1024 * 1024), metrics.swap_used.?);
}

test "display formats correctly" {
    var metrics = Metric.init();
    metrics.mem_total = 1024;
    metrics.mem_free = 512;
    metrics.mem_available = 768;

    var buf: [512]u8 = undefined;
    const result = try metrics.display(&buf);

    try std.testing.expect(std.mem.indexOf(u8, result, "mem_total=1024") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "mem_free=512") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "mem_available=768") != null);
}
