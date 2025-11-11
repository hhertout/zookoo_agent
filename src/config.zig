const std = @import("std");

// define the global section on the config file
pub const ConfigSection = enum {
    cpu,
    memory,
    processor,
    exporter,

    pub fn fromString(str: []const u8) ?ConfigSection {
        return std.meta.stringToEnum(ConfigSection, str);
    }
};

// define the configuration object where the config file will be parsed
const Configuration = struct {
    cpu: CpuConfig,
    memory: MemoryConfig,
    processor: ProcessorConfig,
    exporter: ExporterConfig,

    const CpuConfig = struct { enable: bool = false };

    const MemoryConfig = struct { enable: bool = false };

    const ProcessorConfig = struct {
        batch_size: usize = 100,
    };

    const ExporterConfig = struct {
        url: []const u8 = "http://localhost:4317",

        pub fn deinit(self: *ExporterConfig, allocator: std.mem.Allocator) void {
            if (self.url.len > 0) {
                allocator.free(self.url);
            }
        }
    };

    pub fn init() Configuration {
        return Configuration{
            .cpu = .{},
            .memory = .{},
            .processor = .{},
            .exporter = .{},
        };
    }

    pub fn deinit(self: *Configuration, allocator: std.mem.Allocator) void {
        self.exporter.deinit(allocator);
    }
};

pub fn parseConfigFromFile(allocator: std.mem.Allocator, path: []const u8) !Configuration {
    const content = try readFile(allocator, path);
    defer allocator.free(content);

    return try parseConfig(allocator, content);
}

// Parser Engine
fn parseConfig(allocator: std.mem.Allocator, content: []const u8) !Configuration {
    var config = Configuration.init();

    var lines = std.mem.splitScalar(u8, content, '\n');
    var current_section: ?ConfigSection = null;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // skip if comment
        if (trimmed.len == 0 or trimmed[0] == '#' or trimmed[0] == ';') {
            continue;
        }

        // set current section if detected, then continue
        if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
            current_section = ConfigSection.fromString(trimmed[1 .. trimmed.len - 1]);
            continue;
        }

        // parse key value pair
        const separator_pos = std.mem.indexOfAny(u8, line, "=") orelse continue;
        const key = std.mem.trim(u8, trimmed[0..separator_pos], " \t");
        const value = std.mem.trim(u8, trimmed[separator_pos + 1 ..], " \t\"'");

        // struct association from key value association
        if (current_section) |section| {
            switch (section) {
                .cpu => {
                    if (std.mem.eql(u8, key, "enable")) {
                        config.cpu.enable = parseBool(value);
                    }
                },
                .memory => {
                    if (std.mem.eql(u8, key, "enable")) {
                        config.memory.enable = parseBool(value);
                    }
                },
                .processor => {
                    if (std.mem.eql(u8, key, "batch_size")) {
                        config.processor.batch_size = try std.fmt.parseInt(usize, value, 10);
                    }
                },
                .exporter => {
                    if (std.mem.eql(u8, key, "url")) {
                        config.exporter.url = try allocator.dupe(u8, value);
                    }
                },
            }
        }
    }

    return config;
}

fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const buffer = try allocator.alloc(u8, stat.size);
    errdefer allocator.free(buffer);

    const bytes_read = try file.readAll(buffer);
    return buffer[0..bytes_read];
}

fn parseBool(value: []const u8) bool {
    return std.mem.eql(u8, value, "true") or
        std.mem.eql(u8, value, "1") or
        std.mem.eql(u8, value, "yes");
}

test "parseBool with true values" {
    try std.testing.expect(parseBool("true") == true);
    try std.testing.expect(parseBool("1") == true);
    try std.testing.expect(parseBool("yes") == true);
}

test "parseBool with false values" {
    try std.testing.expect(parseBool("false") == false);
    try std.testing.expect(parseBool("0") == false);
    try std.testing.expect(parseBool("no") == false);
    try std.testing.expect(parseBool("") == false);
    try std.testing.expect(parseBool("TRUE") == false);
    try std.testing.expect(parseBool("True") == false);
    try std.testing.expect(parseBool("random") == false);
}
