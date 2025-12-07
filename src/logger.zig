const std = @import("std");
const os_lookup = @import("os_lookup.zig");

const LogLevel = enum(u8) { debug = 1, info = 2, warn = 3, err = 4 };

const DEFAULT_LOG_LEVEL = LogLevel.info;

// returns the log level from the LOG_LEVEL environment variable, or "info" by default if not set
pub fn getLogLevel() LogLevel {
    const allocator = std.heap.page_allocator;
    const timestamp = std.time.timestamp();

    const logLevel = std.process.getEnvVarOwned(allocator, "LOG_LEVEL") catch {
        std.debug.print("level=warn timestamp={d} log_level=info\n", .{timestamp});
        return LogLevel.info;
    };

    defer allocator.free(logLevel);

    if (std.mem.eql(u8, logLevel, "debug")) {
        std.debug.print("level=warn timestamp={d} log_level=debug", .{timestamp});
        return LogLevel.debug;
    } else if (std.mem.eql(u8, logLevel, "info")) {
        std.debug.print("level=warn timestamp={d} log_level=info", .{timestamp});
        return LogLevel.info;
    } else if (std.mem.eql(u8, logLevel, "warn")) {
        std.debug.print("level=warn timestamp={d} log_level=warn", .{timestamp});
        return LogLevel.warn;
    } else if (std.mem.eql(u8, logLevel, "err")) {
        std.debug.print("level=warn timestamp={d} log_level=err", .{timestamp});
        return LogLevel.err;
    } else {
        return DEFAULT_LOG_LEVEL;
    }
}

// returns the HOST environment variable, or "HOST_NOT_SET" if not set
pub fn getHostEnvVariable() []const u8 {
    const host = std.process.getEnvVarOwned(std.heap.page_allocator, "HOST") catch null;
    if (host) |h| return h else return "HOST_NOT_SET";
}

pub const Logger = struct {
    level: LogLevel = DEFAULT_LOG_LEVEL,
    host: []const u8,

    pub fn init(level: LogLevel) Logger {
        const host = getHostEnvVariable();

        return Logger{ .level = level, .host = host };
    }

    // Log a info message
    pub fn info(self: *const Logger, comptime kind: []const u8, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) > @intFromEnum(LogLevel.info)) return;
        var buf: [4096]u8 = undefined;
        var stdout = std.fs.File.stdout().writer(&buf);

        const timestamp = std.time.timestamp();
        stdout.interface.print("level=info timestamp={d} host={s}", .{ timestamp, self.host }) catch return;
        stdout.interface.print(" job=zookoo_agent", .{}) catch return;
        stdout.interface.print(" type={s}", .{kind}) catch return;
        stdout.interface.print(" message=\"" ++ fmt ++ "\"\n", args) catch return;
        stdout.interface.flush() catch return;
    }

    // Log a debug message
    pub fn debug(self: *const Logger, comptime kind: []const u8, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) > @intFromEnum(LogLevel.debug)) return;
        var buf: [4096]u8 = undefined;
        var stdout = std.fs.File.stdout().writer(&buf);

        const timestamp = std.time.timestamp();
        stdout.interface.print("level=debug timestamp={d} host={s}", .{ timestamp, self.host }) catch return;
        stdout.interface.print(" job=zookoo_agent", .{}) catch return;
        stdout.interface.print(" type={s}", .{kind}) catch return;
        stdout.interface.print(" message=\"" ++ fmt ++ "\"\n", args) catch return;
        stdout.interface.flush() catch return;
    }

    // Log a warning message
    pub fn warn(self: *const Logger, comptime kind: []const u8, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) > @intFromEnum(LogLevel.warn)) return;
        var buf: [4096]u8 = undefined;
        var stdout = std.fs.File.stdout().writer(&buf);

        const timestamp = std.time.timestamp();
        stdout.interface.print("level=warn timestamp={d} host={s}", .{ timestamp, self.host }) catch return;
        stdout.interface.print(" job=zookoo_agent", .{}) catch return;
        stdout.interface.print(" type={s}", .{kind}) catch return;
        stdout.interface.print(" message=\"" ++ fmt ++ "\"\n", args) catch return;
        stdout.interface.flush() catch return;
    }

    // Log an error message
    pub fn err(self: *const Logger, comptime kind: []const u8, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) > @intFromEnum(LogLevel.err)) return;
        var buf: [4096]u8 = undefined;
        var stdout = std.fs.File.stderr().writer(&buf);

        const timestamp = std.time.timestamp();
        stdout.interface.print("level=err timestamp={d} host={s}", .{ timestamp, self.host }) catch return;
        stdout.interface.print(" job=zookoo_agent", .{}) catch return;
        stdout.interface.print(" type={s}", .{kind}) catch return;
        stdout.interface.print(" error=\"" ++ fmt ++ "\"\n", args) catch return;
        stdout.interface.flush() catch return;
    }
};
