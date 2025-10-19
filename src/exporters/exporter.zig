const std = @import("std");

const ExporterType = enum {
    otel,

    pub fn fromString(str: []const u8) ?ExporterType {
        return std.meta.stringToEnum(ExporterType, str);
    }
};

const Exporter = struct {
    pub fn send(_: std.mem.Allocator, exporter_type: ExporterType) !void {
        switch (exporter_type) {
            .otel => {},
        }
    }
};
