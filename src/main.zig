const std = @import("std");
const os_lookup = @import("os_lookup.zig");
const logger = @import("logger.zig");
const scheduler = @import("utils/scheduler.zig");
const batch = @import("utils/batch.zig");
const config = @import("config.zig");
const agent = @import("core/agent.zig");
const State = @import("./state.zig").State;

pub fn testFunc() void {
    return;
}

pub fn main() !void {
    // get log level from environment variable
    const logLevel = logger.getLogLevel();

    // init logger
    var log = logger.Logger.init(logLevel);

    // init gpa
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // parse configuration
    var configParsed = try config.parseConfigFromFile(allocator, "zookoo.ini");
    defer configParsed.deinit(allocator);
    log.debug("config", "config = {any}", .{configParsed});

    // start the engine
    const os = os_lookup.getOsName();
    log.info("agent_started", "Zookoo agent is now started 🚀", .{});
    log.info("runtime_info", "running on {s}", .{os});

    const state = State.init(log);
    try agent.launch(allocator, &state);
    // TODO
}
