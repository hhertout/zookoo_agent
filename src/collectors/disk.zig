const std = @import("std");

pub const Metric = struct {
    disk_reads_completed: ?u64,
    disk_reads_merged: ?u64,
    disk_sectors_read: ?u64,
    disk_time_reading: ?u64,
    disk_writes_completed: ?u64,
    disk_writes_merged: ?u64,
    disk_sectors_written: ?u64,
    disk_time_writing: ?u64,
    disk_ios_in_progress: ?u64,
    disk_time_io: ?u64,
    disk_time_weighted_io: ?u64,

    fn init() Metric {
        return Metric{
            .disk_reads_completed = null,
            .disk_reads_merged = null,
            .disk_sectors_read = null,
            .disk_time_reading = null,
            .disk_writes_completed = null,
            .disk_writes_merged = null,
            .disk_sectors_written = null,
            .disk_time_writing = null,
            .disk_ios_in_progress = null,
            .disk_time_io = null,
            .disk_time_weighted_io = null,
        };
    }

    pub fn display(self: *const Metric, buf: []u8) ![]u8 {
        return std.fmt.bufPrint(buf, "disk_reads_completed={d} disk_reads_merged={d} disk_sectors_read={d} disk_time_reading={d} disk_writes_completed={d} disk_writes_merged={d} disk_sectors_written={d} disk_time_writing={d} disk_ios_in_progress={d} disk_time_io={d} disk_time_weighted_io={d}", .{
            self.disk_reads_completed orelse 0,
            self.disk_reads_merged orelse 0,
            self.disk_sectors_read orelse 0,
            self.disk_time_reading orelse 0,
            self.disk_writes_completed orelse 0,
            self.disk_writes_merged orelse 0,
            self.disk_sectors_written orelse 0,
            self.disk_time_writing orelse 0,
            self.disk_ios_in_progress orelse 0,
            self.disk_time_io orelse 0,
            self.disk_time_weighted_io orelse 0,
        });
    }
};

/// Collect error type
pub const CollectError = error{
    FileNotFound,
    ReadError,
};

// read /proc/diskstats and return raw metrics
fn readDiskStats() !Metric {
    const file = try std.fs.cwd().openFile("/proc/diskstats", .{});
    defer file.close();

    var buffer: [8192]u8 = undefined;
    const bytes_read = try file.readAll(&buffer);
    const content = buffer[0..bytes_read];

    return parseDiskStats(content);
}

// parse /proc/diskstats content to extract aggregated metrics
//
// Format of /proc/diskstats (kernel 4.18+):
//   major minor name reads_completed reads_merged sectors_read time_reading
//   writes_completed writes_merged sectors_written time_writing
//   ios_in_progress time_io time_weighted_io
fn parseDiskStats(fileContent: []const u8) !Metric {
    var metrics = Metric.init();
    var lines = std.mem.splitScalar(u8, fileContent, '\n');

    // Accumulate totals across all devices
    var total_reads_completed: u64 = 0;
    var total_reads_merged: u64 = 0;
    var total_sectors_read: u64 = 0;
    var total_time_reading: u64 = 0;
    var total_writes_completed: u64 = 0;
    var total_writes_merged: u64 = 0;
    var total_sectors_written: u64 = 0;
    var total_time_writing: u64 = 0;
    var total_ios_in_progress: u64 = 0;
    var total_time_io: u64 = 0;
    var total_time_weighted_io: u64 = 0;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        var split = std.mem.tokenizeScalar(u8, trimmed, ' ');

        // Skip major and minor numbers
        _ = split.next() orelse continue;
        _ = split.next() orelse continue;

        // Device name
        const name = split.next() orelse continue;

        // Only aggregate whole-disk devices (skip partitions like sda1, nvme0n1p1)
        if (!isWholeDisk(name)) continue;

        const reads_completed = split.next() orelse continue;
        total_reads_completed += std.fmt.parseInt(u64, reads_completed, 10) catch continue;

        const reads_merged = split.next() orelse continue;
        total_reads_merged += std.fmt.parseInt(u64, reads_merged, 10) catch continue;

        const sectors_read = split.next() orelse continue;
        total_sectors_read += std.fmt.parseInt(u64, sectors_read, 10) catch continue;

        const time_reading = split.next() orelse continue;
        total_time_reading += std.fmt.parseInt(u64, time_reading, 10) catch continue;

        const writes_completed = split.next() orelse continue;
        total_writes_completed += std.fmt.parseInt(u64, writes_completed, 10) catch continue;

        const writes_merged = split.next() orelse continue;
        total_writes_merged += std.fmt.parseInt(u64, writes_merged, 10) catch continue;

        const sectors_written = split.next() orelse continue;
        total_sectors_written += std.fmt.parseInt(u64, sectors_written, 10) catch continue;

        const time_writing = split.next() orelse continue;
        total_time_writing += std.fmt.parseInt(u64, time_writing, 10) catch continue;

        const ios_in_progress = split.next() orelse continue;
        total_ios_in_progress += std.fmt.parseInt(u64, ios_in_progress, 10) catch continue;

        const time_io = split.next() orelse continue;
        total_time_io += std.fmt.parseInt(u64, time_io, 10) catch continue;

        const time_weighted_io = split.next() orelse continue;
        total_time_weighted_io += std.fmt.parseInt(u64, time_weighted_io, 10) catch continue;
    }

    metrics.disk_reads_completed = total_reads_completed;
    metrics.disk_reads_merged = total_reads_merged;
    metrics.disk_sectors_read = total_sectors_read;
    metrics.disk_time_reading = total_time_reading;
    metrics.disk_writes_completed = total_writes_completed;
    metrics.disk_writes_merged = total_writes_merged;
    metrics.disk_sectors_written = total_sectors_written;
    metrics.disk_time_writing = total_time_writing;
    metrics.disk_ios_in_progress = total_ios_in_progress;
    metrics.disk_time_io = total_time_io;
    metrics.disk_time_weighted_io = total_time_weighted_io;

    return metrics;
}

// Check if a device name represents a whole disk (not a partition)
// Whole disks: sda, vda, xvda, nvme0n1, mmcblk0
// Partitions: sda1, vda2, nvme0n1p1, mmcblk0p1
fn isWholeDisk(name: []const u8) bool {
    // NVMe disks: nvme<N>n<N> (whole disk) vs nvme<N>n<N>p<N> (partition)
    if (std.mem.startsWith(u8, name, "nvme")) {
        return std.mem.indexOfScalar(u8, name, 'p') == null or !endsWithDigit(name);
    }

    // MMC/SD cards: mmcblk<N> (whole disk) vs mmcblk<N>p<N> (partition)
    if (std.mem.startsWith(u8, name, "mmcblk")) {
        return std.mem.indexOf(u8, name, "p") == null or !endsWithDigit(name);
    }

    // SCSI/virtio/xen disks: sd<letter>, vd<letter>, xvd<letter>
    // Whole disk ends with letter, partition ends with digit
    if (std.mem.startsWith(u8, name, "sd") or
        std.mem.startsWith(u8, name, "vd") or
        std.mem.startsWith(u8, name, "xvd") or
        std.mem.startsWith(u8, name, "hd"))
    {
        return !endsWithDigit(name);
    }

    // Skip loop, ram, dm- and other virtual devices
    return false;
}

fn endsWithDigit(s: []const u8) bool {
    if (s.len == 0) return false;
    return s[s.len - 1] >= '0' and s[s.len - 1] <= '9';
}

// retrieve all disk metrics
pub fn getDiskMetrics() CollectError!Metric {
    const metrics = readDiskStats() catch {
        return CollectError.ReadError;
    };

    return metrics;
}

// ============================================================================
// Tests
// ============================================================================

test "parseDiskStats with valid content" {
    const test_content =
        \\   8       0 sda 12345 678 91011 1213 14151 617 181920 2122 0 2324 2526
        \\   8       1 sda1 100 200 300 400 500 600 700 800 0 900 1000
        \\   8      16 sdb 5000 1000 20000 3000 7000 2000 30000 4000 5 6000 7000
        \\   7       0 loop0 0 0 0 0 0 0 0 0 0 0 0
    ;

    const metrics = try parseDiskStats(test_content);

    // Only sda and sdb should be aggregated (sda1 is a partition, loop0 is virtual)
    try std.testing.expectEqual(@as(u64, 12345 + 5000), metrics.disk_reads_completed.?);
    try std.testing.expectEqual(@as(u64, 678 + 1000), metrics.disk_reads_merged.?);
    try std.testing.expectEqual(@as(u64, 91011 + 20000), metrics.disk_sectors_read.?);
    try std.testing.expectEqual(@as(u64, 1213 + 3000), metrics.disk_time_reading.?);
    try std.testing.expectEqual(@as(u64, 14151 + 7000), metrics.disk_writes_completed.?);
    try std.testing.expectEqual(@as(u64, 617 + 2000), metrics.disk_writes_merged.?);
    try std.testing.expectEqual(@as(u64, 181920 + 30000), metrics.disk_sectors_written.?);
    try std.testing.expectEqual(@as(u64, 2122 + 4000), metrics.disk_time_writing.?);
    try std.testing.expectEqual(@as(u64, 0 + 5), metrics.disk_ios_in_progress.?);
    try std.testing.expectEqual(@as(u64, 2324 + 6000), metrics.disk_time_io.?);
    try std.testing.expectEqual(@as(u64, 2526 + 7000), metrics.disk_time_weighted_io.?);
}

test "parseDiskStats with nvme devices" {
    const test_content =
        \\   259       0 nvme0n1 1000 200 3000 400 5000 600 7000 800 1 900 1000
        \\   259       1 nvme0n1p1 100 20 300 40 500 60 700 80 0 90 100
        \\   259       2 nvme0n1p2 50 10 150 20 250 30 350 40 0 45 50
    ;

    const metrics = try parseDiskStats(test_content);

    // Only nvme0n1 should be counted (p1, p2 are partitions)
    try std.testing.expectEqual(@as(u64, 1000), metrics.disk_reads_completed.?);
    try std.testing.expectEqual(@as(u64, 200), metrics.disk_reads_merged.?);
    try std.testing.expectEqual(@as(u64, 3000), metrics.disk_sectors_read.?);
    try std.testing.expectEqual(@as(u64, 5000), metrics.disk_writes_completed.?);
    try std.testing.expectEqual(@as(u64, 7000), metrics.disk_sectors_written.?);
}

test "parseDiskStats with empty content" {
    const test_content = "";

    const metrics = try parseDiskStats(test_content);

    try std.testing.expectEqual(@as(u64, 0), metrics.disk_reads_completed.?);
    try std.testing.expectEqual(@as(u64, 0), metrics.disk_writes_completed.?);
}

test "isWholeDisk identifies whole disks correctly" {
    // Whole disks
    try std.testing.expect(isWholeDisk("sda"));
    try std.testing.expect(isWholeDisk("sdb"));
    try std.testing.expect(isWholeDisk("vda"));
    try std.testing.expect(isWholeDisk("xvda"));
    try std.testing.expect(isWholeDisk("hda"));

    // Partitions (should return false)
    try std.testing.expect(!isWholeDisk("sda1"));
    try std.testing.expect(!isWholeDisk("sdb2"));
    try std.testing.expect(!isWholeDisk("vda1"));

    // Virtual devices (should return false)
    try std.testing.expect(!isWholeDisk("loop0"));
    try std.testing.expect(!isWholeDisk("dm-0"));
    try std.testing.expect(!isWholeDisk("ram0"));
}

test "display formats correctly" {
    var metrics = Metric.init();
    metrics.disk_reads_completed = 1000;
    metrics.disk_writes_completed = 2000;
    metrics.disk_sectors_read = 500;

    var buf: [512]u8 = undefined;
    const result = try metrics.display(&buf);

    try std.testing.expect(std.mem.indexOf(u8, result, "disk_reads_completed=1000") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "disk_writes_completed=2000") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "disk_sectors_read=500") != null);
}
