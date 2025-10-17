const std = @import("std");

pub const DEFAULT_BATCH_SIZE: u32 = 100;

pub const Batch = struct {
    allocator: std.mem.Allocator,
    contents: std.ArrayListUnmanaged(u32),
    maxBatchSize: u32,

    pub fn init(allocator: std.mem.Allocator, maxBatchSize: ?u32) !Batch {
        const size = maxBatchSize orelse DEFAULT_BATCH_SIZE;

        var list = std.ArrayListUnmanaged(u32){};
        try list.ensureTotalCapacity(allocator, @intCast(size));

        return Batch{
            .allocator = allocator,
            .contents = list,
            .maxBatchSize = size,
        };
    }

    pub fn deinit(self: *Batch) void {
        self.contents.deinit(self.allocator);
    }
};
