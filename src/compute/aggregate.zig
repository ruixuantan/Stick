const std = @import("std");
const simd = @import("../simd.zig");
const array = @import("../array/array.zig");
const ArraySliceBuilder = @import("../array/array_builder.zig").ArraySliceBuilder;
const Datatype = @import("../datatype.zig").Datatype;
const NumericArray = array.NumericArray;

const AggregateOptions = enum { Mul, Min, Max };

pub fn Aggregate(datatype: Datatype) type {
    const T = switch (datatype) {
        .Double, .Float => f64,
        .Int8, .Int16, .Int32, .Int64 => i64,
        .Uint8, .Uint16, .Uint32, .Uint64 => u64,
        else => unreachable,
    };

    const byte_width = datatype.byte_width();
    const ztype = datatype.ztype();
    const register_length = simd.SIMD_LENGTH / byte_width;
    const Register = @Vector(register_length, ztype);
    const BitRegister = @Vector(register_length, bool);
    const chunk_size = simd.ALIGNMENT / 8;

    return struct {
        const Self = @This();

        pub fn cnt(arr: NumericArray) i64 {
            return arr.length - arr.null_count;
        }

        pub fn sum(arr: NumericArray) ?T {
            if (arr.length == arr.null_count) {
                return null;
            }
            var output: Register = @splat(0);
            var i: usize = 0;
            while (i < arr.buffer.size()) : (i += simd.SIMD_LENGTH) {
                const register: simd.SimdRegister = arr.buffer.data[i .. i + simd.SIMD_LENGTH][0..simd.SIMD_LENGTH].*;
                output += @bitCast(register);
            }
            return @reduce(.Add, output);
        }

        inline fn aggregate(arr: NumericArray, id: Register, op: std.builtin.ReduceOp) ?T {
            if (arr.length == arr.null_count) {
                return null;
            }
            var output = id;
            var i: usize = 0;

            while (i < arr.length) : (i += simd.ALIGNMENT) {
                const validity_chunk: u64 = @bitCast(arr.bitmap.data[i .. i + chunk_size][0..chunk_size].*);
                const value_chunk = arr.buffer.data[i .. i + simd.ALIGNMENT];

                var j: usize = 0;
                var bit: u64 = 1;
                while (j < simd.ALIGNMENT) : (j += simd.SIMD_LENGTH) {
                    var validity: BitRegister = undefined;
                    inline for (0..register_length) |k| {
                        validity[k] = (bit & validity_chunk) != 0;
                        bit <<= 1;
                    }
                    const data: Register = @bitCast(value_chunk[j .. j + simd.SIMD_LENGTH][0..simd.SIMD_LENGTH].*);
                    const intermediate = @select(ztype, validity, data, id);
                    output = switch (op) {
                        .Max => @max(output, intermediate),
                        .Min => @min(output, intermediate),
                        .Mul => output * intermediate,
                        else => unreachable,
                    };
                }
            }
            return @reduce(op, output);
        }

        pub fn mul(arr: NumericArray) ?T {
            const id: Register = @splat(1);
            return Self.aggregate(arr, id, .Mul);
        }

        pub fn max(arr: NumericArray) ?T {
            const id: Register = switch (datatype) {
                .Double, .Float => @splat(std.math.floatMin(ztype)),
                .Int8, .Int16, .Int32, .Int64, .Uint8, .Uint16, .Uint32, .Uint64 => @splat(std.math.minInt(ztype)),
                else => unreachable,
            };
            return Self.aggregate(arr, id, .Max);
        }

        pub fn min(arr: NumericArray) ?T {
            const id: Register = switch (datatype) {
                .Double, .Float => @splat(std.math.floatMax(ztype)),
                .Int8, .Int16, .Int32, .Int64, .Uint8, .Uint16, .Uint32, .Uint64 => @splat(std.math.maxInt(ztype)),
                else => unreachable,
            };
            return Self.aggregate(arr, id, .Min);
        }

        pub fn avg(arr: NumericArray) ?f64 {
            const s = sum(arr);
            if (s == null) {
                return null;
            }
            const total: f64 = @floatFromInt(Self.cnt(arr));
            switch (datatype) {
                .Double, .Float => return s.? / total,
                .Int8, .Int16, .Int32, .Int64, .Uint8, .Uint16, .Uint32, .Uint64 => return @as(f64, @floatFromInt(s.?)) / total,
                else => unreachable,
            }
        }
    };
}

const test_allocator = std.testing.allocator;

test "u8 aggregation" {
    const slice = [_]?u8{ 1, 2, null, 3, null, 4 };
    const arr = try ArraySliceBuilder(Datatype.Uint8).create(&slice, test_allocator);
    defer arr.deinit();
    const Aggregator = Aggregate(Datatype.Uint8);

    try std.testing.expectEqual(4, Aggregator.cnt(arr.numeric));
    try std.testing.expectEqual(10, Aggregator.sum(arr.numeric).?);
    try std.testing.expectApproxEqAbs(2.5, Aggregator.avg(arr.numeric).?, 0.001);
    try std.testing.expectEqual(24, Aggregator.mul(arr.numeric).?);
    try std.testing.expectEqual(1, Aggregator.min(arr.numeric).?);
    try std.testing.expectEqual(4, Aggregator.max(arr.numeric).?);
}

test "f32 aggregation" {
    const slice = [_]?f32{ null, 1.0, -1.0, 10.01 };
    const arr = try ArraySliceBuilder(Datatype.Float).create(&slice, test_allocator);
    defer arr.deinit();
    const Aggregator = Aggregate(Datatype.Float);

    try std.testing.expectEqual(3, Aggregator.cnt(arr.numeric));
    try std.testing.expectApproxEqAbs(10.01, Aggregator.sum(arr.numeric).?, 0.001);
    try std.testing.expectApproxEqAbs(3.33667, Aggregator.avg(arr.numeric).?, 0.001);
    try std.testing.expectApproxEqAbs(-10.01, Aggregator.mul(arr.numeric).?, 0.001);
    try std.testing.expectApproxEqAbs(-1.0, Aggregator.min(arr.numeric).?, 0.001);
    try std.testing.expectApproxEqAbs(10.01, Aggregator.max(arr.numeric).?, 0.001);
}
