const std = @import("std");
const Logger = @import("./logger.zig").Logger;

pub const State = struct {
    logger: Logger,

    pub fn init(logger: Logger) State {
        return State{ .logger = logger };
    }
};
