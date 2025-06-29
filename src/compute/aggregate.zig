const std = @import("std");
const simd = @import("../simd.zig");
const array = @import("../array/array.zig");
const Array = array.Array;
const ArraySliceBuilder = @import("../array/array_builder.zig").ArraySliceBuilder;
const Datatype = @import("../datatype.zig").Datatype;
const Iterator = @import("../array/iterator.zig").Iterator;
const Scalar = @import("../scalar.zig").Scalar;

pub fn Aggregate(datatype: Datatype) type {
    const T = switch (datatype) {
        .Double, .Float => .Double,
        .Int8, .Int16, .Int32, .Int64 => .Int64,
        .Uint8, .Uint16, .Uint32, .Uint64 => .Uint64,
        else => unreachable,
    };

    const byte_width = datatype.byte_width();
    const ztype = datatype.ztype();
    const register_length = simd.SIMD_LENGTH / byte_width;
    const Register = @Vector(register_length, ztype);
    const BitRegister = @Vector(register_length, bool);
    const AggregateError = error{ArrayIsNotNumeric};

    return struct {
        const Self = @This();

        pub fn cnt(arr: Array) Scalar {
            return Scalar.fromInt64(arr.length() - arr.null_count());
        }

        inline fn aggregate(arr: Array, id: Register, op: std.builtin.ReduceOp) !Scalar {
            if (!arr.isNumeric()) {
                return AggregateError.ArrayIsNotNumeric;
            }
            if (arr.length() == arr.null_count()) {
                return Scalar.parse(T, null);
            }

            var output = id;
            var itr = Iterator.init(arr);

            while (itr.next()) |chunk| {
                const validity_chunk = chunk.validity;
                const value_chunk = chunk.values;
                var i: usize = 0;
                var bit: u64 = 1;
                while (i < simd.ALIGNMENT) : (i += simd.SIMD_LENGTH) {
                    var validity: BitRegister = undefined;
                    inline for (0..register_length) |k| {
                        validity[k] = (bit & validity_chunk) != 0;
                        bit <<= 1;
                    }
                    const data: Register = @bitCast(value_chunk[i .. i + simd.SIMD_LENGTH][0..simd.SIMD_LENGTH].*);
                    const intermediate = @select(ztype, validity, data, id);
                    output = switch (op) {
                        .Max => @max(output, intermediate),
                        .Min => @min(output, intermediate),
                        .Mul => output * intermediate,
                        .Add => output + intermediate,
                        else => unreachable,
                    };
                }
            }
            return Scalar.parse(T, @reduce(op, output));
        }

        pub fn sum(arr: Array) !Scalar {
            const id: Register = @splat(0);
            return try Self.aggregate(arr, id, .Add);
        }

        pub fn mul(arr: Array) !Scalar {
            const id: Register = @splat(1);
            return try Self.aggregate(arr, id, .Mul);
        }

        pub fn max(arr: Array) !Scalar {
            const id: Register = switch (datatype) {
                .Double, .Float => @splat(std.math.floatMin(ztype)),
                .Int8, .Int16, .Int32, .Int64, .Uint8, .Uint16, .Uint32, .Uint64 => @splat(std.math.minInt(ztype)),
                else => unreachable,
            };
            return try Self.aggregate(arr, id, .Max);
        }

        pub fn min(arr: Array) !Scalar {
            const id: Register = switch (datatype) {
                .Double, .Float => @splat(std.math.floatMax(ztype)),
                .Int8, .Int16, .Int32, .Int64, .Uint8, .Uint16, .Uint32, .Uint64 => @splat(std.math.maxInt(ztype)),
                else => unreachable,
            };
            return try Self.aggregate(arr, id, .Min);
        }

        pub fn avg(arr: Array) !Scalar {
            const s = try sum(arr);
            if (!s.isValid()) {
                return Scalar.nullDouble();
            }
            const total: f64 = @floatFromInt(cnt(arr).int64.value);
            const output = switch (datatype) {
                .Double, .Float => s.double.value / total,
                .Int8, .Int16, .Int32, .Int64 => @as(f64, @floatFromInt(s.int64.value)) / total,
                .Uint8, .Uint16, .Uint32, .Uint64 => @as(f64, @floatFromInt(s.uint64.value)) / total,
                else => unreachable,
            };
            return Scalar.fromDouble(output);
        }
    };
}

const test_allocator = std.testing.allocator;

test "u8 aggregation" {
    const slice = [_]?u8{ 1, 2, null, 3, null, 4 };
    const arr = try ArraySliceBuilder(Datatype.Uint8).create(&slice, test_allocator);
    defer arr.deinit();
    const Aggregator = Aggregate(Datatype.Uint8);

    try std.testing.expectEqual(4, Aggregator.cnt(arr).int64.value);
    try std.testing.expectEqual(10, (try Aggregator.sum(arr)).uint64.value);
    try std.testing.expectApproxEqAbs(2.5, (try Aggregator.avg(arr)).double.value, 0.001);
    try std.testing.expectEqual(24, (try Aggregator.mul(arr)).uint64.value);
    try std.testing.expectEqual(1, (try Aggregator.min(arr)).uint64.value);
    try std.testing.expectEqual(4, (try Aggregator.max(arr)).uint64.value);
}

test "f32 aggregation" {
    const slice = [_]?f32{ null, 1.0, -1.0, 10.01 };
    const arr = try ArraySliceBuilder(Datatype.Float).create(&slice, test_allocator);
    defer arr.deinit();
    const Aggregator = Aggregate(Datatype.Float);

    try std.testing.expectEqual(3, Aggregator.cnt(arr).int64.value);
    try std.testing.expectApproxEqAbs(10.01, (try Aggregator.sum(arr)).double.value, 0.001);
    try std.testing.expectApproxEqAbs(3.33667, (try Aggregator.avg(arr)).double.value, 0.001);
    try std.testing.expectApproxEqAbs(-10.01, (try Aggregator.mul(arr)).double.value, 0.001);
    try std.testing.expectApproxEqAbs(-1.0, (try Aggregator.min(arr)).double.value, 0.001);
    try std.testing.expectApproxEqAbs(10.01, (try Aggregator.max(arr)).double.value, 0.001);
}
