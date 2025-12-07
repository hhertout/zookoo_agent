const std = @import("std");
const State = @import("../state.zig").State;

pub const Metric = struct {
    boot_time: ?u64,
    cpu_usage_percent: ?u64,
    cpu_total: ?u64,
    cpu_idle_total: ?u64,
    processes: ?u64,
    procs_blocked: ?u64,
    procs_running: ?u64,
    ctxt: ?u64,
    cpu_intr: ?u64,
    cpu_user: ?u64,
    cpu_nice: ?u64,
    cpu_system: ?u64,
    cpu_idle: ?u64,
    cpu_iowait: ?u64,
    cpu_irq: ?u64,
    cpu_softirq: ?u64,
    cpu_steal: ?u64,
    cpu_guest: ?u64,
    cpu_guest_nice: ?u64,

    fn init() Metric {
        return Metric{
            .boot_time = null,
            .cpu_usage_percent = null,
            .cpu_total = null,
            .cpu_idle_total = null,
            .processes = null,
            .procs_blocked = null,
            .procs_running = null,
            .ctxt = null,
            .cpu_intr = null,
            .cpu_user = null,
            .cpu_nice = null,
            .cpu_system = null,
            .cpu_idle = null,
            .cpu_iowait = null,
            .cpu_irq = null,
            .cpu_softirq = null,
            .cpu_steal = null,
            .cpu_guest = null,
            .cpu_guest_nice = null,
        };
    }

    pub fn display(self: *const Metric, buf: []u8) ![]u8 {
        return std.fmt.bufPrint(buf, "boot_time={d} cpu_usage_percent={d} cpu_total={d} cpu_idle_total={d} processes={d} procs_blocked={d} procs_running={d} ctxt={d} cpu_intr={d} cpu_user={d} cpu_nice={d} cpu_system={d} cpu_idle={d} cpu_iowait={d} cpu_irq={d} cpu_softirq={d} cpu_steal={d} cpu_guest={d} cpu_guest_nice={d}", .{
            self.boot_time orelse 0,
            self.cpu_usage_percent orelse 0,
            self.cpu_total orelse 0,
            self.cpu_idle_total orelse 0,
            self.processes orelse 0,
            self.procs_blocked orelse 0,
            self.procs_running orelse 0,
            self.ctxt orelse 0,
            self.cpu_intr orelse 0,
            self.cpu_user orelse 0,
            self.cpu_nice orelse 0,
            self.cpu_system orelse 0,
            self.cpu_idle orelse 0,
            self.cpu_iowait orelse 0,
            self.cpu_irq orelse 0,
            self.cpu_softirq orelse 0,
            self.cpu_steal orelse 0,
            self.cpu_guest orelse 0,
            self.cpu_guest_nice orelse 0,
        });
    }

    fn computeCpuTotal(self: *Metric) void {
        self.cpu_total = (self.cpu_user orelse 0) + (self.cpu_nice orelse 0) + (self.cpu_system orelse 0) + (self.cpu_idle orelse 0) + (self.cpu_iowait orelse 0) + (self.cpu_irq orelse 0) + (self.cpu_softirq orelse 0) + (self.cpu_steal orelse 0);
    }

    fn computeCpuIdleTotal(self: *Metric) void {
        self.cpu_idle_total = (self.cpu_idle orelse 0) + (self.cpu_iowait orelse 0);
    }

    fn computeCpuUsage(tick1: Metric, tick2: Metric) u64 {
        const totalDelta = (tick2.cpu_total orelse 0) - (tick1.cpu_total orelse 0);
        const idleDelta = (tick2.cpu_idle_total orelse 0) - (tick1.cpu_idle_total orelse 0);

        if (totalDelta == 0) return 0;

        return 100 * (totalDelta - idleDelta) / totalDelta;
    }
};

// get proc stat info and return metrics
fn tick() !Metric {
    // open file /proc/stat to get kernel CPU informations
    const file = try std.fs.cwd().openFile("/proc/stat", .{});
    defer file.close();

    // /proc files are virtual and have size=0 in stat, we need to read with a buffer
    var buffer: [8192]u8 = undefined;
    const bytes_read = try file.readAll(&buffer);
    const content = buffer[0..bytes_read];

    // Compute and set metric object
    const metrics = try parseCpuInformation(content);

    return metrics;
}

// from the content, parse the file to extract metrics
fn parseCpuInformation(fileContent: []const u8) !Metric {
    var metrics = Metric.init();
    var lines = std.mem.splitScalar(u8, fileContent, '\n');

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Parse CPU gbl if exist
        if (trimmed.len >= 4 and std.mem.startsWith(u8, trimmed, "cpu ")) {
            var split = std.mem.tokenizeScalar(u8, line, ' ');

            // ignore the first key -> cpu
            _ = split.next();

            const cpu_user = split.next() orelse return error.InvalidCpuStat;
            metrics.cpu_user = try std.fmt.parseInt(u64, cpu_user, 10);

            const cpu_nice = split.next() orelse return error.InvalidCpuStat;
            metrics.cpu_nice = try std.fmt.parseInt(u64, cpu_nice, 10);

            const cpu_system = split.next() orelse return error.InvalidCpuStat;
            metrics.cpu_system = try std.fmt.parseInt(u64, cpu_system, 10);

            const cpu_idle = split.next() orelse return error.InvalidCpuStat;
            metrics.cpu_idle = try std.fmt.parseInt(u64, cpu_idle, 10);

            const cpu_iowait = split.next() orelse return error.InvalidCpuStat;
            metrics.cpu_iowait = try std.fmt.parseInt(u64, cpu_iowait, 10);

            const cpu_irq = split.next() orelse return error.InvalidCpuStat;
            metrics.cpu_irq = try std.fmt.parseInt(u64, cpu_irq, 10);

            const cpu_softirq = split.next() orelse return error.InvalidCpuStat;
            metrics.cpu_softirq = try std.fmt.parseInt(u64, cpu_softirq, 10);

            const cpu_steal = split.next() orelse return error.InvalidCpuStat;
            metrics.cpu_steal = try std.fmt.parseInt(u64, cpu_steal, 10);

            const cpu_guest = split.next() orelse return error.InvalidCpuStat;
            metrics.cpu_guest = try std.fmt.parseInt(u64, cpu_guest, 10);

            const cpu_guest_nice = split.next() orelse return error.InvalidCpuStat;
            metrics.cpu_guest_nice = try std.fmt.parseInt(u64, cpu_guest_nice, 10);
        }

        // Parse procs_blocked line if exist
        if (trimmed.len >= 13 and std.mem.eql(u8, trimmed[0..13], "procs_blocked")) {
            var split = std.mem.tokenizeScalar(u8, line, ' ');

            _ = split.next();
            const value = split.next() orelse return error.InvalidCpuStat;
            metrics.procs_blocked = try std.fmt.parseInt(u64, value, 10);
        }

        // Parse procs_running line if exist
        if (trimmed.len >= 13 and std.mem.eql(u8, trimmed[0..13], "procs_running")) {
            var split = std.mem.tokenizeScalar(u8, line, ' ');
            _ = split.next();
            const value = split.next() orelse return error.InvalidCpuStat;
            metrics.procs_running = try std.fmt.parseInt(u64, value, 10);
        }

        // Parse processes line if exist
        if (trimmed.len >= 9 and std.mem.eql(u8, trimmed[0..9], "processes")) {
            var split = std.mem.tokenizeScalar(u8, line, ' ');
            _ = split.next();
            const value = split.next() orelse return error.InvalidCpuStat;
            metrics.processes = try std.fmt.parseInt(u64, value, 10);
        }

        // Parse btime if exist
        if (trimmed.len >= 5 and std.mem.eql(u8, trimmed[0..5], "btime")) {
            var split = std.mem.tokenizeScalar(u8, line, ' ');
            _ = split.next();
            const value = split.next() orelse return error.InvalidCpuStat;
            metrics.boot_time = try std.fmt.parseInt(u64, value, 10);
        }

        // Parse ctxt if exist
        if (trimmed.len >= 4 and std.mem.eql(u8, trimmed[0..4], "ctxt")) {
            var split = std.mem.tokenizeScalar(u8, line, ' ');
            _ = split.next();
            const value = split.next() orelse return error.InvalidCpuStat;
            metrics.ctxt = try std.fmt.parseInt(u64, value, 10);
        }

        // Parse intr if exist
        if (trimmed.len >= 4 and std.mem.eql(u8, trimmed[0..4], "intr")) {
            var split = std.mem.tokenizeScalar(u8, line, ' ');
            var total: u64 = 0;
            _ = split.next();
            while (split.next()) |value| {
                const parsed = try std.fmt.parseInt(u64, value, 10);
                total = total + parsed;
            }
            metrics.cpu_intr = total;
        }
    }

    return metrics;
}

// retrieve all the CPU metrics
pub fn getCpuMetrics(state: *const State) ?Metric {
    // get the first tick
    var tick1 = tick() catch |err| {
        state.logger.err("err_tick_failed", "error={s}", .{@errorName(err)});
        return null;
    };

    // compute totals for tick1
    tick1.computeCpuTotal();
    tick1.computeCpuIdleTotal();

    // wait 1 sec before the second tick
    std.Thread.sleep(1 * std.time.ns_per_s);

    // get the second tick
    var tick2 = tick() catch |err| {
        state.logger.err("err_tick_failed", "error={s}", .{@errorName(err)});
        return null;
    };

    // compute totals for tick2
    tick2.computeCpuTotal();
    tick2.computeCpuIdleTotal();

    // compute the CPU usage percentage between the two ticks
    tick2.cpu_usage_percent = Metric.computeCpuUsage(tick1, tick2);

    // return tick2 as source of truth as metrics generated
    return tick2;
}
