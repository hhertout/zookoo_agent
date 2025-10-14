const std = @import("std");
const os_lookup = @import("os_lookup.zig");
const logger = @import("logger.zig");

pub fn main() !void {
    // get log level from environment variable
    const logLevel = logger.getLogLevel();

    // determine the OS
    const os = os_lookup.getOsName();
    var log = logger.Logger.init(logLevel);
    log.info("agent_started", "Zookoo agent is now started 🚀", .{});
    log.info("runtime_info", "running on {s}", .{os});
}
