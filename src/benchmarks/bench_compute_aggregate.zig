const std = @import("std");
const utils = @import("utils.zig");
const Datatype = @import("../datatype.zig").Datatype;
const Aggregate = @import("../compute/aggregate.zig").Aggregate;
const Array = @import("../array/array.zig").Array;

pub const BenchmarkComputeAggregate = struct {
    allocator: std.mem.Allocator,
    arr: Array,

    const aggregator = Aggregate(Datatype.Int32);

    fn init(n: usize, allocator: std.mem.Allocator) !BenchmarkComputeAggregate {
        const arr = try utils.generatei32Array(n, allocator);
        return .{ .arr = arr, .allocator = allocator };
    }

    fn deinit(self: BenchmarkComputeAggregate) void {
        self.arr.deinit();
    }

    fn sum(self: BenchmarkComputeAggregate) !i64 {
        const start = try std.time.Instant.now();
        const res = try aggregator.sum(self.arr);
        const end = try std.time.Instant.now();
        const elapsed: f64 = @floatFromInt(end.since(start));
        std.debug.print("Time elapsed is: {d:.8}ms\n", .{elapsed / std.time.ns_per_ms});
        return res.int64.value;
    }

    fn naive_sum(self: BenchmarkComputeAggregate) !i64 {
        const start = try std.time.Instant.now();
        var res: i64 = 0;
        for (0..@intCast(self.arr.length())) |i| {
            if (try self.arr.bitmap().isValid(i)) {
                const index = i * 4; // byte width of i32 is 4
                const elem: i64 = @intCast(std.mem.bytesAsValue(i32, self.arr.buffer().data[index .. index + 4]).*);
                res += elem;
            }
        }
        const end = try std.time.Instant.now();
        const elapsed: f64 = @floatFromInt(end.since(start));
        std.debug.print("Time elapsed is: {d:.8}ms\n", .{elapsed / std.time.ns_per_ms});
        return res;
    }

    fn min(self: BenchmarkComputeAggregate) !i64 {
        const start = try std.time.Instant.now();
        const res = try aggregator.min(self.arr);
        const end = try std.time.Instant.now();
        const elapsed: f64 = @floatFromInt(end.since(start));
        std.debug.print("Time elapsed is: {d:.8}ms\n", .{elapsed / std.time.ns_per_ms});
        return res.int64.value;
    }

    fn naive_min(self: BenchmarkComputeAggregate) !i64 {
        const start = try std.time.Instant.now();
        var res: i64 = std.math.maxInt(i64);
        for (0..@intCast(self.arr.length())) |i| {
            if (try self.arr.bitmap().isValid(i)) {
                const index = i * 4; // byte width of i32 is 4
                const elem: i64 = @intCast(std.mem.bytesAsValue(i32, self.arr.buffer().data[index .. index + 4]).*);
                res = @min(res, elem);
            }
        }
        const end = try std.time.Instant.now();
        const elapsed: f64 = @floatFromInt(end.since(start));
        std.debug.print("Time elapsed is: {d:.8}ms\n", .{elapsed / std.time.ns_per_ms});
        return res;
    }

    pub fn main(t: []const u8, n: usize, allocator: std.mem.Allocator) !i64 {
        const bench = try BenchmarkComputeAggregate.init(n, allocator);
        defer bench.deinit();
        if (std.mem.eql(u8, t, "sum")) {
            return try bench.sum();
        } else if (std.mem.eql(u8, t, "nsum")) {
            return try bench.naive_sum();
        } else if (std.mem.eql(u8, t, "min")) {
            return try bench.min();
        } else if (std.mem.eql(u8, t, "nmin")) {
            return try bench.naive_min();
        } else {
            @panic("Unrecognized aggregate type");
        }
    }
};
