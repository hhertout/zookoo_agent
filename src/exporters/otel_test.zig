const std = @import("std");
const otel = @import("otel.zig");

const KeyValue = otel.KeyValue;
const NumberDataPoint = otel.NumberDataPoint;
const HistogramDataPoint = otel.HistogramDataPoint;
const Metric = otel.Metric;
const ScopeMetrics = otel.ScopeMetrics;
const ResourceMetrics = otel.ResourceMetrics;
const Resource = otel.Resource;
const InstrumentationScope = otel.InstrumentationScope;
const ExportMetricsServiceRequest = otel.ExportMetricsServiceRequest;
const AggregationTemporality = otel.AggregationTemporality;
const serializeToJson = otel.serializeToJson;

// ----------------------------------------------------------------------------
// KeyValue Tests
// ----------------------------------------------------------------------------

test "KeyValue.string creates string attribute" {
    const kv = KeyValue.string("key1", "value1");
    try std.testing.expectEqualStrings("key1", kv.key);
    try std.testing.expectEqualStrings("value1", kv.value.string_value);
}

test "KeyValue.int creates integer attribute" {
    const kv = KeyValue.int("count", 42);
    try std.testing.expectEqualStrings("count", kv.key);
    try std.testing.expectEqual(@as(i64, 42), kv.value.int_value);
}

test "KeyValue.double creates double attribute" {
    const kv = KeyValue.double("temperature", 36.6);
    try std.testing.expectEqualStrings("temperature", kv.key);
    try std.testing.expectEqual(@as(f64, 36.6), kv.value.double_value);
}

test "KeyValue.boolean creates boolean attribute" {
    const kv_true = KeyValue.boolean("enabled", true);
    const kv_false = KeyValue.boolean("disabled", false);

    try std.testing.expect(kv_true.value.bool_value);
    try std.testing.expect(!kv_false.value.bool_value);
}

// ----------------------------------------------------------------------------
// NumberDataPoint Tests
// ----------------------------------------------------------------------------

test "NumberDataPoint.initInt creates integer data point" {
    const attrs = &[_]KeyValue{
        KeyValue.string("host", "localhost"),
    };

    const dp = NumberDataPoint.initInt(100, attrs);
    try std.testing.expectEqual(@as(i64, 100), dp.value.as_int);
    try std.testing.expect(dp.time_unix_nano > 0);
    try std.testing.expectEqual(@as(usize, 1), dp.attributes.len);
}

test "NumberDataPoint.initDouble creates double data point" {
    const attrs = &[_]KeyValue{};

    const dp = NumberDataPoint.initDouble(3.14, attrs);
    try std.testing.expectEqual(@as(f64, 3.14), dp.value.as_double);
    try std.testing.expect(dp.time_unix_nano > 0);
}

test "NumberDataPoint.initIntWithTime sets explicit timestamps" {
    const attrs = &[_]KeyValue{};
    const start: u64 = 1000000000;
    const end: u64 = 2000000000;

    const dp = NumberDataPoint.initIntWithTime(42, start, end, attrs);
    try std.testing.expectEqual(start, dp.start_time_unix_nano);
    try std.testing.expectEqual(end, dp.time_unix_nano);
    try std.testing.expectEqual(@as(i64, 42), dp.value.as_int);
}

// ----------------------------------------------------------------------------
// Metric Tests
// ----------------------------------------------------------------------------

test "Metric.initGauge creates gauge metric" {
    const attrs = &[_]KeyValue{};
    const points = &[_]NumberDataPoint{
        NumberDataPoint.initInt(42, attrs),
    };

    const metric = Metric.initGauge("cpu.usage", "CPU usage", "%", points);
    try std.testing.expectEqualStrings("cpu.usage", metric.name);
    try std.testing.expectEqualStrings("CPU usage", metric.description);
    try std.testing.expectEqualStrings("%", metric.unit);
    try std.testing.expectEqual(@as(usize, 1), metric.data.gauge.data_points.len);
}

test "Metric.initSum creates sum metric with correct temporality" {
    const attrs = &[_]KeyValue{};
    const points = &[_]NumberDataPoint{
        NumberDataPoint.initInt(100, attrs),
    };

    const metric = Metric.initSum(
        "http.requests",
        "Total requests",
        "1",
        points,
        true,
        .cumulative,
    );

    try std.testing.expectEqualStrings("http.requests", metric.name);
    try std.testing.expect(metric.data.sum.is_monotonic);
    try std.testing.expectEqual(AggregationTemporality.cumulative, metric.data.sum.aggregation_temporality);
}

test "Metric.initHistogram creates histogram metric" {
    const attrs = &[_]KeyValue{};
    const buckets = &[_]u64{ 1, 5, 10, 20, 5 };
    const bounds = &[_]f64{ 0.01, 0.05, 0.1, 0.5 };

    const points = &[_]HistogramDataPoint{
        HistogramDataPoint.init(41, 1.5, buckets, bounds, attrs),
    };

    const metric = Metric.initHistogram("http.latency", "Request latency", "s", points, .cumulative);

    try std.testing.expectEqualStrings("http.latency", metric.name);
    try std.testing.expectEqual(@as(usize, 1), metric.data.histogram.data_points.len);
    try std.testing.expectEqual(@as(u64, 41), metric.data.histogram.data_points[0].count);
}

// ----------------------------------------------------------------------------
// JSON Serialization Tests
// ----------------------------------------------------------------------------

// Test data defined at comptime to avoid dangling pointer issues
const test_gauge_attrs = [_]KeyValue{
    KeyValue.string("host", "test-host"),
};

const test_gauge_points = [_]NumberDataPoint{
    NumberDataPoint.initIntWithTime(42, 1000, 2000, &test_gauge_attrs),
};

const test_gauge_metrics = [_]Metric{
    Metric.initGauge("test.gauge", "Test gauge", "1", &test_gauge_points),
};

const test_resource_attrs = [_]KeyValue{
    KeyValue.string("service.name", "test-service"),
};

const test_scope_metrics = [_]ScopeMetrics{
    .{
        .scope = .{ .name = "test-scope", .version = "1.0.0" },
        .metrics = &test_gauge_metrics,
    },
};

const test_resource_metrics = [_]ResourceMetrics{
    .{
        .resource = .{ .attributes = &test_resource_attrs },
        .scope_metrics = &test_scope_metrics,
    },
};

test "serializeToJson produces valid JSON structure" {
    const allocator = std.testing.allocator;

    const request = ExportMetricsServiceRequest{
        .resource_metrics = &test_resource_metrics,
    };

    const json = try serializeToJson(allocator, request);
    defer allocator.free(json);

    // Verify JSON contains expected keys
    try std.testing.expect(std.mem.indexOf(u8, json, "\"resourceMetrics\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"scopeMetrics\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"metrics\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"gauge\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"dataPoints\"") != null);
}

test "serializeToJson includes metric name and description" {
    const allocator = std.testing.allocator;

    const request = ExportMetricsServiceRequest{
        .resource_metrics = &test_resource_metrics,
    };

    const json = try serializeToJson(allocator, request);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"test.gauge\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"Test gauge\"") != null);
}

// Test data for sum metric
const test_sum_points = [_]NumberDataPoint{
    NumberDataPoint.initIntWithTime(100, 0, 1000000000, &[_]KeyValue{}),
};

const test_sum_metrics = [_]Metric{
    Metric.initSum("counter", "Counter", "1", &test_sum_points, true, .cumulative),
};

const test_sum_scope_metrics = [_]ScopeMetrics{
    .{
        .scope = .{ .name = "scope", .version = "1.0.0" },
        .metrics = &test_sum_metrics,
    },
};

const test_sum_resource_metrics = [_]ResourceMetrics{
    .{
        .resource = .{ .attributes = &[_]KeyValue{} },
        .scope_metrics = &test_sum_scope_metrics,
    },
};

test "serializeToJson sum metric includes aggregation temporality" {
    const allocator = std.testing.allocator;

    const request = ExportMetricsServiceRequest{
        .resource_metrics = &test_sum_resource_metrics,
    };

    const json = try serializeToJson(allocator, request);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"sum\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"isMonotonic\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"aggregationTemporality\":2") != null);
}

// Test data for escape characters
const test_escape_attrs = [_]KeyValue{
    KeyValue.string("message", "line1\nline2\ttab"),
};

const test_escape_points = [_]NumberDataPoint{
    NumberDataPoint.initIntWithTime(1, 0, 1000, &test_escape_attrs),
};

const test_escape_metrics = [_]Metric{
    Metric.initGauge("test", "desc \"quoted\"", "1", &test_escape_points),
};

const test_escape_scope_metrics = [_]ScopeMetrics{
    .{
        .scope = .{ .name = "scope", .version = "1.0.0" },
        .metrics = &test_escape_metrics,
    },
};

const test_escape_resource_metrics = [_]ResourceMetrics{
    .{
        .resource = .{ .attributes = &[_]KeyValue{} },
        .scope_metrics = &test_escape_scope_metrics,
    },
};

test "serializeToJson escapes special characters in strings" {
    const allocator = std.testing.allocator;

    const request = ExportMetricsServiceRequest{
        .resource_metrics = &test_escape_resource_metrics,
    };

    const json = try serializeToJson(allocator, request);
    defer allocator.free(json);

    // Verify escaped characters
    try std.testing.expect(std.mem.indexOf(u8, json, "\\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\\t") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\\\"quoted\\\"") != null);
}

// Test data for empty attributes
const test_empty_points = [_]NumberDataPoint{
    NumberDataPoint.initIntWithTime(1, 0, 1000, &[_]KeyValue{}),
};

const test_empty_metrics = [_]Metric{
    Metric.initGauge("test", "", "", &test_empty_points),
};

const test_empty_scope_metrics = [_]ScopeMetrics{
    .{
        .scope = .{ .name = "scope", .version = "1.0.0" },
        .metrics = &test_empty_metrics,
    },
};

const test_empty_resource_metrics = [_]ResourceMetrics{
    .{
        .resource = .{ .attributes = &[_]KeyValue{} },
        .scope_metrics = &test_empty_scope_metrics,
    },
};

test "serializeToJson handles empty attributes" {
    const allocator = std.testing.allocator;

    const request = ExportMetricsServiceRequest{
        .resource_metrics = &test_empty_resource_metrics,
    };

    const json = try serializeToJson(allocator, request);
    defer allocator.free(json);

    // Should have empty attributes array
    try std.testing.expect(std.mem.indexOf(u8, json, "\"attributes\":[]") != null);
}

// Test data for multiple metrics
const test_multi_points = [_]NumberDataPoint{
    NumberDataPoint.initIntWithTime(1, 0, 1000, &[_]KeyValue{}),
};

const test_multi_metrics = [_]Metric{
    Metric.initGauge("metric1", "First", "1", &test_multi_points),
    Metric.initGauge("metric2", "Second", "1", &test_multi_points),
    Metric.initGauge("metric3", "Third", "1", &test_multi_points),
};

const test_multi_scope_metrics = [_]ScopeMetrics{
    .{
        .scope = .{ .name = "scope", .version = "1.0.0" },
        .metrics = &test_multi_metrics,
    },
};

const test_multi_resource_metrics = [_]ResourceMetrics{
    .{
        .resource = .{ .attributes = &[_]KeyValue{} },
        .scope_metrics = &test_multi_scope_metrics,
    },
};

test "serializeToJson handles multiple metrics" {
    const allocator = std.testing.allocator;

    const request = ExportMetricsServiceRequest{
        .resource_metrics = &test_multi_resource_metrics,
    };

    const json = try serializeToJson(allocator, request);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"metric1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"metric2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"metric3\"") != null);
}

// ----------------------------------------------------------------------------
// HistogramDataPoint Tests
// ----------------------------------------------------------------------------

test "HistogramDataPoint.init creates valid histogram point" {
    const attrs = &[_]KeyValue{
        KeyValue.string("method", "GET"),
    };
    const buckets = &[_]u64{ 10, 20, 15, 5, 2 };
    const bounds = &[_]f64{ 0.005, 0.01, 0.025, 0.05 };

    const dp = HistogramDataPoint.init(52, 1.234, buckets, bounds, attrs);

    try std.testing.expectEqual(@as(u64, 52), dp.count);
    try std.testing.expectEqual(@as(?f64, 1.234), dp.sum);
    try std.testing.expectEqual(@as(usize, 5), dp.bucket_counts.len);
    try std.testing.expectEqual(@as(usize, 4), dp.explicit_bounds.len);
    try std.testing.expect(dp.time_unix_nano > 0);
}

// Test data for histogram serialization
const test_hist_buckets = [_]u64{ 5, 10, 20 };
const test_hist_bounds = [_]f64{ 0.1, 0.5 };

const test_hist_points = [_]HistogramDataPoint{
    HistogramDataPoint.initWithTime(35, 2.5, &test_hist_buckets, &test_hist_bounds, 0, 1000000000, &[_]KeyValue{}),
};

const test_hist_metrics = [_]Metric{
    Metric.initHistogram("latency", "Latency", "s", &test_hist_points, .cumulative),
};

const test_hist_scope_metrics = [_]ScopeMetrics{
    .{
        .scope = .{ .name = "scope", .version = "1.0.0" },
        .metrics = &test_hist_metrics,
    },
};

const test_hist_resource_metrics = [_]ResourceMetrics{
    .{
        .resource = .{ .attributes = &[_]KeyValue{} },
        .scope_metrics = &test_hist_scope_metrics,
    },
};

test "serializeToJson histogram includes bucket data" {
    const allocator = std.testing.allocator;

    const request = ExportMetricsServiceRequest{
        .resource_metrics = &test_hist_resource_metrics,
    };

    const json = try serializeToJson(allocator, request);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"histogram\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"bucketCounts\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"explicitBounds\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"count\":\"35\"") != null);
}
