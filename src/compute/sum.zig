const std = @import("std");
const simd = @import("../simd.zig");
const array = @import("../array/array.zig");
const ArraySliceBuilder = @import("../array/array_builder.zig").ArraySliceBuilder;
const Datatype = @import("../datatype.zig").Datatype;
const NumericArray = array.NumericArray;

pub fn SimpleSum(datatype: Datatype) type {
    const T = switch (datatype) {
        .Double, .Float => f64,
        .Int8, .Int16, .Int32, .Int64 => i64,
        else => unreachable,
    };

    const byte_width = datatype.byte_width();
    const ztype = datatype.ztype();

    return struct {
        inline fn cast(bytes: []u8) T {
            return switch (datatype) {
                .Double, .Float => @floatCast(std.mem.bytesAsValue(ztype, bytes).*),
                .Int8, .Int16, .Int32, .Int64 => @intCast(std.mem.bytesAsValue(ztype, bytes).*),
                else => unreachable,
            };
        }

        pub fn sum(arr: NumericArray) T {
            var output: T = 0;
            for (0..@intCast(arr.length)) |i| {
                const index = i * byte_width;
                output += cast(arr.buffer.data[index .. index + byte_width]);
            }
            return output;
        }
    };
}

pub fn Sum(datatype: Datatype) type {
    const T = switch (datatype) {
        .Double, .Float => f64,
        .Int8, .Int16, .Int32, .Int64 => i64,
        else => unreachable,
    };

    const byte_width = datatype.byte_width();
    const ztype = datatype.ztype();
    const CastSimdRegister = @Vector(simd.ALIGNMENT / byte_width, ztype);

    return struct {
        pub fn sum(arr: NumericArray) T {
            var output: CastSimdRegister = @splat(0);
            var i: usize = 0;
            while (i < arr.buffer.size()) : (i += simd.ALIGNMENT) {
                const register: simd.SimdRegister = arr.buffer.data[i .. i + simd.ALIGNMENT][0..simd.ALIGNMENT].*;
                output += @bitCast(register);
            }
            return @reduce(.Add, output);
        }
    };
}

const test_allocator = std.testing.allocator;

test "Sum f32 array" {
    const slice = [_]?f32{ null, 1.0, -1.0, 10.01 };
    const arr = try ArraySliceBuilder(Datatype.Float).create(&slice, test_allocator);
    defer arr.deinit();

    const simple = SimpleSum(Datatype.Float);
    try std.testing.expectApproxEqAbs(10.01, simple.sum(arr.numeric), 0.001);

    const f = Sum(Datatype.Float);
    try std.testing.expectApproxEqAbs(10.01, f.sum(arr.numeric), 0.001);
}
