const std = @import("std");
const State = @import("../state.zig").State;
const cpu = @import("../collectors/cpu.zig");

pub fn launch(_: std.mem.Allocator, state: *const State) !void {
    state.logger.info("agent_launched", "agent lauched", .{});

    const result = cpu.getCpuMetrics(state);
    if (result) |metrics| {
        state.logger.info("metric_received", "cpu_usage={d} cpu_idle={d} cpu_user={d}", .{
            metrics.cpu_usage_percent orelse 0,
            metrics.cpu_idle orelse 0,
            metrics.cpu_user orelse 0,
        });
    } else {
        state.logger.err("metric_obj_is_null", "err=metric is null", .{});
    }
}
