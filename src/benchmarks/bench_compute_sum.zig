const std = @import("std");
const utils = @import("utils.zig");
const Datatype = @import("../datatype.zig").Datatype;
const sum = @import("../compute/sum.zig");
const NumericArray = @import("../array/array.zig").NumericArray;

pub const BenchmarkComputeSum = struct {
    allocator: std.mem.Allocator,
    arr: NumericArray,

    fn init(n: usize, allocator: std.mem.Allocator) !BenchmarkComputeSum {
        const arr = try utils.generatei32Array(n, allocator);
        return .{ .arr = arr, .allocator = allocator };
    }

    fn deinit(self: BenchmarkComputeSum) void {
        self.arr.deinit();
    }

    fn simple(self: BenchmarkComputeSum) !i64 {
        const f = sum.SimpleSum(Datatype.Int32);
        const start = try std.time.Instant.now();
        const res = f.sum(self.arr);
        const end = try std.time.Instant.now();
        const elapsed: f64 = @floatFromInt(end.since(start));
        std.debug.print("Time elapsed is: {d:.8}ms\n", .{elapsed / std.time.ns_per_ms});
        return res;
    }

    fn standard(self: BenchmarkComputeSum) !i64 {
        const f = sum.Sum(Datatype.Int32);
        const start = try std.time.Instant.now();
        const res = f.sum(self.arr);
        const end = try std.time.Instant.now();
        const elapsed: f64 = @floatFromInt(end.since(start));
        std.debug.print("Time elapsed is: {d:.8}ms\n", .{elapsed / std.time.ns_per_ms});
        return res;
    }

    pub fn main(t: []const u8, n: usize, allocator: std.mem.Allocator) !i64 {
        const bench = try BenchmarkComputeSum.init(n, allocator);
        defer bench.deinit();

        if (std.mem.eql(u8, t, "simple")) {
            return try bench.simple();
        } else if (std.mem.eql(u8, t, "standard")) {
            return try bench.standard();
        } else {
            @panic("Unrecognized sum type");
        }
    }
};
