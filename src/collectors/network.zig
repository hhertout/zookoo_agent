const std = @import("std");

pub const Metric = struct {
    rx_bytes: ?u64,
    rx_packets: ?u64,
    rx_errors: ?u64,
    rx_dropped: ?u64,
    rx_fifo: ?u64,
    rx_frame: ?u64,
    rx_compressed: ?u64,
    rx_multicast: ?u64,
    tx_bytes: ?u64,
    tx_packets: ?u64,
    tx_errors: ?u64,
    tx_dropped: ?u64,
    tx_fifo: ?u64,
    tx_colls: ?u64,
    tx_carrier: ?u64,
    tx_compressed: ?u64,

    fn init() Metric {
        return Metric{
            .rx_bytes = null,
            .rx_packets = null,
            .rx_errors = null,
            .rx_dropped = null,
            .rx_fifo = null,
            .rx_frame = null,
            .rx_compressed = null,
            .rx_multicast = null,
            .tx_bytes = null,
            .tx_packets = null,
            .tx_errors = null,
            .tx_dropped = null,
            .tx_fifo = null,
            .tx_colls = null,
            .tx_carrier = null,
            .tx_compressed = null,
        };
    }

    pub fn display(self: *const Metric, buf: []u8) ![]u8 {
        return std.fmt.bufPrint(buf, "rx_bytes={d} rx_packets={d} rx_errors={d} rx_dropped={d} rx_fifo={d} rx_frame={d} rx_compressed={d} rx_multicast={d} tx_bytes={d} tx_packets={d} tx_errors={d} tx_dropped={d} tx_fifo={d} tx_colls={d} tx_carrier={d} tx_compressed={d}", .{
            self.rx_bytes orelse 0,
            self.rx_packets orelse 0,
            self.rx_errors orelse 0,
            self.rx_dropped orelse 0,
            self.rx_fifo orelse 0,
            self.rx_frame orelse 0,
            self.rx_compressed orelse 0,
            self.rx_multicast orelse 0,
            self.tx_bytes orelse 0,
            self.tx_packets orelse 0,
            self.tx_errors orelse 0,
            self.tx_dropped orelse 0,
            self.tx_fifo orelse 0,
            self.tx_colls orelse 0,
            self.tx_carrier orelse 0,
            self.tx_compressed orelse 0,
        });
    }

    fn addFrom(self: *Metric, other: Metric) void {
        self.rx_bytes = (self.rx_bytes orelse 0) + (other.rx_bytes orelse 0);
        self.rx_packets = (self.rx_packets orelse 0) + (other.rx_packets orelse 0);
        self.rx_errors = (self.rx_errors orelse 0) + (other.rx_errors orelse 0);
        self.rx_dropped = (self.rx_dropped orelse 0) + (other.rx_dropped orelse 0);
        self.rx_fifo = (self.rx_fifo orelse 0) + (other.rx_fifo orelse 0);
        self.rx_frame = (self.rx_frame orelse 0) + (other.rx_frame orelse 0);
        self.rx_compressed = (self.rx_compressed orelse 0) + (other.rx_compressed orelse 0);
        self.rx_multicast = (self.rx_multicast orelse 0) + (other.rx_multicast orelse 0);
        self.tx_bytes = (self.tx_bytes orelse 0) + (other.tx_bytes orelse 0);
        self.tx_packets = (self.tx_packets orelse 0) + (other.tx_packets orelse 0);
        self.tx_errors = (self.tx_errors orelse 0) + (other.tx_errors orelse 0);
        self.tx_dropped = (self.tx_dropped orelse 0) + (other.tx_dropped orelse 0);
        self.tx_fifo = (self.tx_fifo orelse 0) + (other.tx_fifo orelse 0);
        self.tx_colls = (self.tx_colls orelse 0) + (other.tx_colls orelse 0);
        self.tx_carrier = (self.tx_carrier orelse 0) + (other.tx_carrier orelse 0);
        self.tx_compressed = (self.tx_compressed orelse 0) + (other.tx_compressed orelse 0);
    }
};

// read /proc/net/dev and return parsed aggregated metrics
fn readNetDev() !Metric {
    const file = try std.fs.cwd().openFile("/proc/net/dev", .{});
    defer file.close();

    var buffer: [8192]u8 = undefined;
    const bytes_read = try file.readAll(&buffer);
    const content = buffer[0..bytes_read];

    return parseNetDev(content);
}

// parse /proc/net/dev content to extract aggregated metrics across all interfaces
fn parseNetDev(fileContent: []const u8) !Metric {
    var metrics = Metric.init();
    var lines = std.mem.splitScalar(u8, fileContent, '\n');

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        // skip header lines (lines without ':')
        const colon_pos = std.mem.indexOfScalar(u8, line, ':') orelse continue;

        // parse the values after the colon
        const values_part = line[colon_pos + 1 ..];
        const iface_metric = parseInterfaceLine(values_part) orelse continue;

        // aggregate across all interfaces
        metrics.addFrom(iface_metric);
    }

    return metrics;
}

// parse a single interface line values (after the colon)
// format: rx_bytes rx_packets rx_errors rx_dropped rx_fifo rx_frame rx_compressed rx_multicast tx_bytes tx_packets tx_errors tx_dropped tx_fifo tx_colls tx_carrier tx_compressed
fn parseInterfaceLine(values: []const u8) ?Metric {
    var metric = Metric.init();
    var tokens = std.mem.tokenizeAny(u8, values, " \t");

    metric.rx_bytes = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.rx_packets = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.rx_errors = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.rx_dropped = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.rx_fifo = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.rx_frame = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.rx_compressed = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.rx_multicast = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.tx_bytes = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.tx_packets = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.tx_errors = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.tx_dropped = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.tx_fifo = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.tx_colls = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.tx_carrier = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;
    metric.tx_compressed = std.fmt.parseInt(u64, tokens.next() orelse return null, 10) catch return null;

    return metric;
}

/// Collect error type
pub const CollectError = error{
    FileNotFound,
    ReadError,
};

// Retrieve all network metrics.
pub fn getNetworkMetrics() CollectError!Metric {
    const metrics = readNetDev() catch {
        return CollectError.ReadError;
    };

    return metrics;
}

// ============================================================================
// Tests
// ============================================================================

test "parseInterfaceLine with valid data" {
    const line = "  1234567   12345    1    2    3     4          5         6  9876543   98765    7    8    9    10       11          12";
    const metric = parseInterfaceLine(line).?;

    try std.testing.expectEqual(@as(u64, 1234567), metric.rx_bytes.?);
    try std.testing.expectEqual(@as(u64, 12345), metric.rx_packets.?);
    try std.testing.expectEqual(@as(u64, 1), metric.rx_errors.?);
    try std.testing.expectEqual(@as(u64, 2), metric.rx_dropped.?);
    try std.testing.expectEqual(@as(u64, 3), metric.rx_fifo.?);
    try std.testing.expectEqual(@as(u64, 4), metric.rx_frame.?);
    try std.testing.expectEqual(@as(u64, 5), metric.rx_compressed.?);
    try std.testing.expectEqual(@as(u64, 6), metric.rx_multicast.?);
    try std.testing.expectEqual(@as(u64, 9876543), metric.tx_bytes.?);
    try std.testing.expectEqual(@as(u64, 98765), metric.tx_packets.?);
    try std.testing.expectEqual(@as(u64, 7), metric.tx_errors.?);
    try std.testing.expectEqual(@as(u64, 8), metric.tx_dropped.?);
    try std.testing.expectEqual(@as(u64, 9), metric.tx_fifo.?);
    try std.testing.expectEqual(@as(u64, 10), metric.tx_colls.?);
    try std.testing.expectEqual(@as(u64, 11), metric.tx_carrier.?);
    try std.testing.expectEqual(@as(u64, 12), metric.tx_compressed.?);
}

test "parseInterfaceLine with incomplete data returns null" {
    const line = "  1234567   12345";
    const result = parseInterfaceLine(line);
    try std.testing.expect(result == null);
}

test "parseNetDev with valid content" {
    const test_content =
        \\Inter-|   Receive                                                |  Transmit
        \\ face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
        \\    lo: 1000   100    0    0    0     0          0         0  2000   200    0    0    0     0       0          0
        \\  eth0: 5000   500    1    2    0     0          0         1  3000   300    0    1    0     0       0          0
    ;

    const metrics = try parseNetDev(test_content);

    // lo + eth0 aggregated
    try std.testing.expectEqual(@as(u64, 6000), metrics.rx_bytes.?);
    try std.testing.expectEqual(@as(u64, 600), metrics.rx_packets.?);
    try std.testing.expectEqual(@as(u64, 1), metrics.rx_errors.?);
    try std.testing.expectEqual(@as(u64, 2), metrics.rx_dropped.?);
    try std.testing.expectEqual(@as(u64, 0), metrics.rx_fifo.?);
    try std.testing.expectEqual(@as(u64, 0), metrics.rx_frame.?);
    try std.testing.expectEqual(@as(u64, 0), metrics.rx_compressed.?);
    try std.testing.expectEqual(@as(u64, 1), metrics.rx_multicast.?);
    try std.testing.expectEqual(@as(u64, 5000), metrics.tx_bytes.?);
    try std.testing.expectEqual(@as(u64, 500), metrics.tx_packets.?);
    try std.testing.expectEqual(@as(u64, 0), metrics.tx_errors.?);
    try std.testing.expectEqual(@as(u64, 1), metrics.tx_dropped.?);
    try std.testing.expectEqual(@as(u64, 0), metrics.tx_fifo.?);
    try std.testing.expectEqual(@as(u64, 0), metrics.tx_colls.?);
    try std.testing.expectEqual(@as(u64, 0), metrics.tx_carrier.?);
    try std.testing.expectEqual(@as(u64, 0), metrics.tx_compressed.?);
}

test "parseNetDev with single interface" {
    const test_content =
        \\Inter-|   Receive                                                |  Transmit
        \\ face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
        \\  eth0: 429457665  190448    0    0    0     0          0         1  6577574   12574    0    0    0     0       0          0
    ;

    const metrics = try parseNetDev(test_content);

    try std.testing.expectEqual(@as(u64, 429457665), metrics.rx_bytes.?);
    try std.testing.expectEqual(@as(u64, 190448), metrics.rx_packets.?);
    try std.testing.expectEqual(@as(u64, 6577574), metrics.tx_bytes.?);
    try std.testing.expectEqual(@as(u64, 12574), metrics.tx_packets.?);
}

test "parseNetDev with empty content" {
    const test_content =
        \\Inter-|   Receive                                                |  Transmit
        \\ face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    ;

    const metrics = try parseNetDev(test_content);

    // no interfaces, all fields should be null
    try std.testing.expect(metrics.rx_bytes == null);
    try std.testing.expect(metrics.tx_bytes == null);
}

test "addFrom aggregates correctly" {
    var m1 = Metric.init();
    m1.rx_bytes = 100;
    m1.tx_bytes = 200;
    m1.rx_packets = 10;
    m1.tx_packets = 20;

    var m2 = Metric.init();
    m2.rx_bytes = 300;
    m2.tx_bytes = 400;
    m2.rx_packets = 30;
    m2.tx_packets = 40;

    m1.addFrom(m2);

    try std.testing.expectEqual(@as(u64, 400), m1.rx_bytes.?);
    try std.testing.expectEqual(@as(u64, 600), m1.tx_bytes.?);
    try std.testing.expectEqual(@as(u64, 40), m1.rx_packets.?);
    try std.testing.expectEqual(@as(u64, 60), m1.tx_packets.?);
}

test "display formats correctly" {
    var metrics = Metric.init();
    metrics.rx_bytes = 1024;
    metrics.tx_bytes = 2048;
    metrics.rx_packets = 100;
    metrics.tx_packets = 200;

    var buf: [1024]u8 = undefined;
    const result = try metrics.display(&buf);

    try std.testing.expect(std.mem.indexOf(u8, result, "rx_bytes=1024") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "tx_bytes=2048") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "rx_packets=100") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "tx_packets=200") != null);
}
