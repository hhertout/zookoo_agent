// Create the correct output to send the telemetry for OpenTelemetry
const std = @import("std");
const http = std.http;

// ============================================================================
// OTLP (OpenTelemetry Protocol) Metrics Exporter
// ============================================================================
//
// This module exports metrics to an OpenTelemetry collector using the OTLP
// HTTP/JSON protocol (port 4318 by default).
//
// OTLP DATA FORMAT OVERVIEW:
// --------------------------
// The OTLP metrics format is hierarchical:
//
//   ExportMetricsServiceRequest
//   └── resourceMetrics[] (array of ResourceMetrics)
//       ├── resource (Resource with attributes like service.name)
//       └── scopeMetrics[] (array of ScopeMetrics)
//           ├── scope (InstrumentationScope with name/version)
//           └── metrics[] (array of Metric)
//               ├── name, description, unit
//               └── data (one of: gauge, sum, histogram, summary)
//                   └── dataPoints[] (array of data points with values)
//
// METRIC TYPES:
// -------------
// - Gauge: Instantaneous value (e.g., current temperature, memory usage)
// - Sum: Cumulative or delta counter (e.g., request count, bytes sent)
// - Histogram: Distribution of values (e.g., request latencies)
//
// USAGE EXAMPLE (Simple):
// -----------------------
//   const otel = @import("exporters/otel.zig");
//
//   // Create metric data points with attributes
//   const attrs = &[_]otel.KeyValue{
//       otel.KeyValue.string("host", "server-01"),
//   };
//   const points = &[_]otel.NumberDataPoint{
//       otel.NumberDataPoint.initInt(42, attrs),
//   };
//
//   // Create the metric
//   const metrics = &[_]otel.Metric{
//       otel.Metric.initGauge("cpu.usage", "CPU usage percentage", "%", points),
//   };
//
//   // Export using the simple helper function
//   try otel.exportMetricsSimple(allocator, "http://localhost:4318", "my-service", metrics);
//
// USAGE EXAMPLE (Full Control):
// -----------------------------
//   const otel = @import("exporters/otel.zig");
//
//   // Build the full request structure
//   const request = otel.ExportMetricsServiceRequest{
//       .resource_metrics = &[_]otel.ResourceMetrics{
//           .{
//               .resource = .{
//                   .attributes = &[_]otel.KeyValue{
//                       otel.KeyValue.string("service.name", "my-service"),
//                   },
//               },
//               .scope_metrics = &[_]otel.ScopeMetrics{
//                   .{
//                       .scope = .{ .name = "my-scope", .version = "1.0.0" },
//                       .metrics = metrics,
//                   },
//               },
//           },
//       },
//   };
//
//   try otel.exportMetrics(allocator, "http://localhost:4318", request);
//
// HTTP ENDPOINT:
// --------------
// - URL: http://<host>:4318/v1/metrics
// - Method: POST
// - Content-Type: application/json
// - Response: 200 OK on success, with optional partial_success
//
// ============================================================================

// ----------------------------------------------------------------------------
// OTLP Data Structures
// ----------------------------------------------------------------------------

/// Represents a key-value pair for attributes.
/// Attributes are used to add metadata to resources, scopes, and data points.
pub const KeyValue = struct {
    key: []const u8,
    value: AnyValue,

    /// Create a string attribute
    pub fn string(key: []const u8, val: []const u8) KeyValue {
        return .{ .key = key, .value = .{ .string_value = val } };
    }

    /// Create an integer attribute
    pub fn int(key: []const u8, val: i64) KeyValue {
        return .{ .key = key, .value = .{ .int_value = val } };
    }

    /// Create a double/float attribute
    pub fn double(key: []const u8, val: f64) KeyValue {
        return .{ .key = key, .value = .{ .double_value = val } };
    }

    /// Create a boolean attribute
    pub fn boolean(key: []const u8, val: bool) KeyValue {
        return .{ .key = key, .value = .{ .bool_value = val } };
    }
};

/// Represents any value type for attributes
pub const AnyValue = union(enum) {
    string_value: []const u8,
    int_value: i64,
    double_value: f64,
    bool_value: bool,
};

/// Resource information associated with metrics
pub const Resource = struct {
    attributes: []const KeyValue,
};

/// InstrumentationScope identifies the library/module producing metrics
pub const InstrumentationScope = struct {
    name: []const u8,
    version: []const u8 = "",
};

/// A single data point for gauge or sum metrics
pub const NumberDataPoint = struct {
    attributes: []const KeyValue = &[_]KeyValue{},
    start_time_unix_nano: u64 = 0,
    time_unix_nano: u64,
    /// Value can be int or double
    value: union(enum) {
        as_int: i64,
        as_double: f64,
    },

    /// Create a data point with an integer value
    pub fn initInt(value: i64, attributes: []const KeyValue) NumberDataPoint {
        return .{
            .attributes = attributes,
            .time_unix_nano = @intCast(std.time.nanoTimestamp()),
            .value = .{ .as_int = value },
        };
    }

    /// Create a data point with a double value
    pub fn initDouble(value: f64, attributes: []const KeyValue) NumberDataPoint {
        return .{
            .attributes = attributes,
            .time_unix_nano = @intCast(std.time.nanoTimestamp()),
            .value = .{ .as_double = value },
        };
    }

    /// Create a data point with an integer value and explicit timestamps
    pub fn initIntWithTime(value: i64, start_time: u64, end_time: u64, attributes: []const KeyValue) NumberDataPoint {
        return .{
            .attributes = attributes,
            .start_time_unix_nano = start_time,
            .time_unix_nano = end_time,
            .value = .{ .as_int = value },
        };
    }
};

/// Aggregation temporality for Sum metrics
pub const AggregationTemporality = enum(u8) {
    unspecified = 0,
    delta = 1,
    cumulative = 2,
};

/// Gauge metric data (instantaneous values)
pub const Gauge = struct {
    data_points: []const NumberDataPoint,
};

/// Sum metric data (cumulative or delta counters)
pub const Sum = struct {
    data_points: []const NumberDataPoint,
    aggregation_temporality: AggregationTemporality = .cumulative,
    is_monotonic: bool = true,
};

/// Histogram bucket for distribution metrics
pub const HistogramDataPoint = struct {
    attributes: []const KeyValue = &[_]KeyValue{},
    start_time_unix_nano: u64 = 0,
    time_unix_nano: u64,
    count: u64,
    sum: ?f64 = null,
    bucket_counts: []const u64,
    explicit_bounds: []const f64,

    /// Create a histogram data point with current timestamp
    pub fn init(
        count: u64,
        sum: ?f64,
        bucket_counts: []const u64,
        explicit_bounds: []const f64,
        attributes: []const KeyValue,
    ) HistogramDataPoint {
        return .{
            .attributes = attributes,
            .time_unix_nano = @intCast(std.time.nanoTimestamp()),
            .count = count,
            .sum = sum,
            .bucket_counts = bucket_counts,
            .explicit_bounds = explicit_bounds,
        };
    }

    /// Create a histogram data point with explicit timestamps (for testing)
    pub fn initWithTime(
        count: u64,
        sum: ?f64,
        bucket_counts: []const u64,
        explicit_bounds: []const f64,
        start_time: u64,
        end_time: u64,
        attributes: []const KeyValue,
    ) HistogramDataPoint {
        return .{
            .attributes = attributes,
            .start_time_unix_nano = start_time,
            .time_unix_nano = end_time,
            .count = count,
            .sum = sum,
            .bucket_counts = bucket_counts,
            .explicit_bounds = explicit_bounds,
        };
    }
};

/// Histogram metric data
pub const Histogram = struct {
    data_points: []const HistogramDataPoint,
    aggregation_temporality: AggregationTemporality = .cumulative,
};

/// A single metric with its data
pub const Metric = struct {
    name: []const u8,
    description: []const u8 = "",
    unit: []const u8 = "",
    data: union(enum) {
        gauge: Gauge,
        sum: Sum,
        histogram: Histogram,
    },

    /// Create a Gauge metric
    pub fn initGauge(
        name: []const u8,
        description: []const u8,
        unit: []const u8,
        data_points: []const NumberDataPoint,
    ) Metric {
        return .{
            .name = name,
            .description = description,
            .unit = unit,
            .data = .{ .gauge = .{ .data_points = data_points } },
        };
    }

    /// Create a Sum (counter) metric
    pub fn initSum(
        name: []const u8,
        description: []const u8,
        unit: []const u8,
        data_points: []const NumberDataPoint,
        is_monotonic: bool,
        temporality: AggregationTemporality,
    ) Metric {
        return .{
            .name = name,
            .description = description,
            .unit = unit,
            .data = .{ .sum = .{
                .data_points = data_points,
                .is_monotonic = is_monotonic,
                .aggregation_temporality = temporality,
            } },
        };
    }

    /// Create a Histogram metric
    pub fn initHistogram(
        name: []const u8,
        description: []const u8,
        unit: []const u8,
        data_points: []const HistogramDataPoint,
        temporality: AggregationTemporality,
    ) Metric {
        return .{
            .name = name,
            .description = description,
            .unit = unit,
            .data = .{ .histogram = .{
                .data_points = data_points,
                .aggregation_temporality = temporality,
            } },
        };
    }
};

/// Metrics grouped by instrumentation scope
pub const ScopeMetrics = struct {
    scope: InstrumentationScope,
    metrics: []const Metric,
};

/// Metrics grouped by resource
pub const ResourceMetrics = struct {
    resource: Resource,
    scope_metrics: []const ScopeMetrics,
};

/// Top-level request structure for OTLP metrics export
pub const ExportMetricsServiceRequest = struct {
    resource_metrics: []const ResourceMetrics,
};

// ----------------------------------------------------------------------------
// JSON Serialization
// ----------------------------------------------------------------------------

/// Serialize the ExportMetricsServiceRequest to OTLP JSON format
pub fn serializeToJson(allocator: std.mem.Allocator, request: ExportMetricsServiceRequest) ![]u8 {
    var buffer = std.ArrayListUnmanaged(u8){};
    errdefer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);
    try writeRequest(writer, request);

    return buffer.toOwnedSlice(allocator);
}

fn writeRequest(writer: anytype, request: ExportMetricsServiceRequest) !void {
    try writer.writeAll("{\"resourceMetrics\":[");

    for (request.resource_metrics, 0..) |rm, i| {
        if (i > 0) try writer.writeByte(',');
        try writeResourceMetrics(writer, rm);
    }

    try writer.writeAll("]}");
}

fn writeResourceMetrics(writer: anytype, rm: ResourceMetrics) !void {
    try writer.writeAll("{\"resource\":{\"attributes\":[");

    for (rm.resource.attributes, 0..) |attr, i| {
        if (i > 0) try writer.writeByte(',');
        try writeKeyValue(writer, attr);
    }

    try writer.writeAll("]},\"scopeMetrics\":[");

    for (rm.scope_metrics, 0..) |sm, i| {
        if (i > 0) try writer.writeByte(',');
        try writeScopeMetrics(writer, sm);
    }

    try writer.writeAll("]}");
}

fn writeScopeMetrics(writer: anytype, sm: ScopeMetrics) !void {
    try writer.writeAll("{\"scope\":{\"name\":\"");
    try writeEscapedString(writer, sm.scope.name);
    try writer.writeAll("\",\"version\":\"");
    try writeEscapedString(writer, sm.scope.version);
    try writer.writeAll("\"},\"metrics\":[");

    for (sm.metrics, 0..) |metric, i| {
        if (i > 0) try writer.writeByte(',');
        try writeMetric(writer, metric);
    }

    try writer.writeAll("]}");
}

fn writeMetric(writer: anytype, metric: Metric) !void {
    try writer.writeAll("{\"name\":\"");
    try writeEscapedString(writer, metric.name);
    try writer.writeAll("\",\"description\":\"");
    try writeEscapedString(writer, metric.description);
    try writer.writeAll("\",\"unit\":\"");
    try writeEscapedString(writer, metric.unit);
    try writer.writeAll("\",");

    switch (metric.data) {
        .gauge => |gauge| {
            try writer.writeAll("\"gauge\":{\"dataPoints\":[");
            for (gauge.data_points, 0..) |dp, i| {
                if (i > 0) try writer.writeByte(',');
                try writeNumberDataPoint(writer, dp);
            }
            try writer.writeAll("]}");
        },
        .sum => |sum| {
            try writer.writeAll("\"sum\":{\"dataPoints\":[");
            for (sum.data_points, 0..) |dp, i| {
                if (i > 0) try writer.writeByte(',');
                try writeNumberDataPoint(writer, dp);
            }
            try writer.print("],\"aggregationTemporality\":{d},\"isMonotonic\":{s}}}", .{
                @intFromEnum(sum.aggregation_temporality),
                if (sum.is_monotonic) "true" else "false",
            });
        },
        .histogram => |hist| {
            try writer.writeAll("\"histogram\":{\"dataPoints\":[");
            for (hist.data_points, 0..) |dp, i| {
                if (i > 0) try writer.writeByte(',');
                try writeHistogramDataPoint(writer, dp);
            }
            try writer.print("],\"aggregationTemporality\":{d}}}", .{
                @intFromEnum(hist.aggregation_temporality),
            });
        },
    }

    try writer.writeByte('}');
}

fn writeNumberDataPoint(writer: anytype, dp: NumberDataPoint) !void {
    try writer.writeAll("{\"attributes\":[");

    for (dp.attributes, 0..) |attr, i| {
        if (i > 0) try writer.writeByte(',');
        try writeKeyValue(writer, attr);
    }

    try writer.print("],\"startTimeUnixNano\":\"{d}\",\"timeUnixNano\":\"{d}\",", .{
        dp.start_time_unix_nano,
        dp.time_unix_nano,
    });

    switch (dp.value) {
        .as_int => |v| try writer.print("\"asInt\":\"{d}\"", .{v}),
        .as_double => |v| try writer.print("\"asDouble\":{d}", .{v}),
    }

    try writer.writeByte('}');
}

fn writeHistogramDataPoint(writer: anytype, dp: HistogramDataPoint) !void {
    try writer.writeAll("{\"attributes\":[");

    for (dp.attributes, 0..) |attr, i| {
        if (i > 0) try writer.writeByte(',');
        try writeKeyValue(writer, attr);
    }

    try writer.print("],\"startTimeUnixNano\":\"{d}\",\"timeUnixNano\":\"{d}\",\"count\":\"{d}\"", .{
        dp.start_time_unix_nano,
        dp.time_unix_nano,
        dp.count,
    });

    if (dp.sum) |sum| {
        try writer.print(",\"sum\":{d}", .{sum});
    }

    try writer.writeAll(",\"bucketCounts\":[");
    for (dp.bucket_counts, 0..) |count, i| {
        if (i > 0) try writer.writeByte(',');
        try writer.print("\"{d}\"", .{count});
    }

    try writer.writeAll("],\"explicitBounds\":[");
    for (dp.explicit_bounds, 0..) |bound, i| {
        if (i > 0) try writer.writeByte(',');
        try writer.print("{d}", .{bound});
    }

    try writer.writeAll("]}");
}

fn writeKeyValue(writer: anytype, kv: KeyValue) !void {
    try writer.writeAll("{\"key\":\"");
    try writeEscapedString(writer, kv.key);
    try writer.writeAll("\",\"value\":{");

    switch (kv.value) {
        .string_value => |v| {
            try writer.writeAll("\"stringValue\":\"");
            try writeEscapedString(writer, v);
            try writer.writeByte('"');
        },
        .int_value => |v| try writer.print("\"intValue\":\"{d}\"", .{v}),
        .double_value => |v| try writer.print("\"doubleValue\":{d}", .{v}),
        .bool_value => |v| try writer.print("\"boolValue\":{s}", .{if (v) "true" else "false"}),
    }

    try writer.writeAll("}}");
}

fn writeEscapedString(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(c),
        }
    }
}

// ----------------------------------------------------------------------------
// HTTP Export Function
// ----------------------------------------------------------------------------

/// Error types for the OTLP exporter
pub const ExportError = error{
    ConnectionFailed,
    RequestFailed,
    InvalidUrl,
    SerializationFailed,
    ServerError,
    OutOfMemory,
    Overflow,
    InvalidCharacter,
    UnexpectedCharacter,
    NetworkUnreachable,
    ConnectionRefused,
    ConnectionResetByPeer,
    ConnectionTimedOut,
    TemporaryNameServerFailure,
    HostLacksNetworkAddresses,
    TlsFailure,
    EndOfStream,
    HttpRedirectError,
};

/// Export metrics to an OTLP HTTP endpoint.
///
/// Parameters:
/// - allocator: Memory allocator for temporary allocations
/// - endpoint_url: Base URL of the OTLP collector (e.g., "http://localhost:4318")
/// - request: The metrics data to export
///
/// Returns: void on success, ExportError on failure
///
/// Note: This function appends "/v1/metrics" to the endpoint_url automatically.
pub fn exportMetrics(
    allocator: std.mem.Allocator,
    endpoint_url: []const u8,
    request: ExportMetricsServiceRequest,
) ExportError!void {
    // Serialize the request to JSON
    const json_body = serializeToJson(allocator, request) catch return ExportError.SerializationFailed;
    defer allocator.free(json_body);

    // Build the full URL with /v1/metrics path
    const full_url = std.fmt.allocPrint(allocator, "{s}/v1/metrics", .{endpoint_url}) catch return ExportError.OutOfMemory;
    defer allocator.free(full_url);

    // Create HTTP client
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    // Perform the request using fetch API
    const result = client.fetch(.{
        .location = .{ .url = full_url },
        .method = .POST,
        .payload = json_body,
        .extra_headers = &[_]http.Header{
            .{ .name = "Content-Type", .value = "application/json" },
        },
    }) catch return ExportError.RequestFailed;

    // Check response status
    if (result.status != .ok and result.status != .accepted) {
        return ExportError.ServerError;
    }
}

/// Export metrics with default service attributes.
/// Convenience function that creates resource attributes automatically.
///
/// Parameters:
/// - allocator: Memory allocator
/// - endpoint_url: OTLP collector URL (e.g., "http://localhost:4318")
/// - service_name: Name of your service (e.g., "my-app")
/// - metrics: Slice of metrics to export
///
/// Example:
///   const attrs = &[_]KeyValue{};
///   const points = &[_]NumberDataPoint{ NumberDataPoint.initInt(42, attrs) };
///   const metrics = &[_]Metric{ Metric.initGauge("cpu.usage", "CPU %", "%", points) };
///   try exportMetricsSimple(allocator, "http://localhost:4318", "my-service", metrics);
pub fn exportMetricsSimple(
    allocator: std.mem.Allocator,
    endpoint_url: []const u8,
    service_name: []const u8,
    metrics: []const Metric,
) ExportError!void {
    const request = ExportMetricsServiceRequest{
        .resource_metrics = &[_]ResourceMetrics{
            .{
                .resource = .{
                    .attributes = &[_]KeyValue{
                        KeyValue.string("service.name", service_name),
                    },
                },
                .scope_metrics = &[_]ScopeMetrics{
                    .{
                        .scope = .{ .name = service_name, .version = "1.0.0" },
                        .metrics = metrics,
                    },
                },
            },
        },
    };

    return exportMetrics(allocator, endpoint_url, request);
}

