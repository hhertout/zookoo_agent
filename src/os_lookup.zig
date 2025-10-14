const std = @import("std");
const builtin = @import("builtin");

const RunTimeInfo = struct {
    os: []const u8,

    pub fn init(os: []const u8) RunTimeInfo {
        return RunTimeInfo{
            .os = os,
        };
    }
};

// determines the OS
pub fn getOsName() []const u8 {
    return switch (builtin.target.os.tag) {
        .linux => "Linux",
        .macos => "macOS",
        .windows => "Windows",
        else => "Unknown",
    };
}
