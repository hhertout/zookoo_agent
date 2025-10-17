const std = @import("std");

pub const DEFAULT_SCHEDULE_INTERVAL: u64 = 60 * 1_000_000_000; // 60 seconds

// Launch a scheduled task
// callback: function to be executed
// Sleeptime in nanoseconds
pub fn lauchScheduleTask(callback: fn () void, sleepTime: u64) void {
    // Mutex logic to spread tasks across multiple threads ??
    while (true) {
        callback();

        std.Thread.sleep(sleepTime);
    }
}
