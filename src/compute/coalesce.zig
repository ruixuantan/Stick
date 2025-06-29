const std = @import("std");
const simd = @import("../simd.zig");
const Datatype = @import("../datatype.zig").Datatype;
const Scalar = @import("../scalar.zig").Scalar;
const Array = @import("../array/array.zig").Array;
const ArrayBuilder = @import("../array/array_builder.zig").ArrayBuilder;
const ArraySliceBuilder = @import("../array/array_builder.zig").ArraySliceBuilder;
const Iterator = @import("../array/iterator.zig").Iterator;

pub const Coalesce = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Coalesce {
        return .{ .allocator = allocator };
    }

    fn dropBooleanNull(builder: *ArrayBuilder, itr: *Iterator) !Array {
        while (itr.next()) |chunk| {
            const validity_chunk = chunk.validity;
            var bit: u64 = 1;
            for (chunk.values) |val| {
                var bool_bit: u8 = 0b1000_0000;
                for (0..8) |_| {
                    const is_valid = (bit & validity_chunk) != 0;
                    bit <<= 1;
                    if (is_valid) {
                        try builder.appendScalar(Scalar.fromBool((bool_bit & val) != 0));
                    }
                    bool_bit >>= 1;
                }
            }
        }
        return try builder.finish();
    }

    fn dropNonBooleanNull(arr: Array, builder: *ArrayBuilder, itr: *Iterator, byte_width: usize) !Array {
        while (itr.next()) |chunk| {
            const validity_chunk = chunk.validity;
            var bit: u64 = 1;
            for (0..simd.ALIGNMENT) |i| {
                const is_valid = (bit & validity_chunk) != 0;
                bit <<= 1;
                if (is_valid) {
                    const start = i * byte_width;
                    const end = start + byte_width;
                    try builder.appendValidBytes(chunk.values[start..end]);
                }
            }
        }
        var final = try builder.finish();
        if (arr.isBinaryView()) {
            try final.binary_view.cloneBinaryBuffers(arr.binary_view);
        }
        return final;
    }

    pub fn dropNull(self: Coalesce, arr: Array) !Array {
        defer arr.deinit();
        var builder = try ArrayBuilder.init(arr.datatype(), self.allocator);
        defer builder.deinit();
        var itr = Iterator.init(arr);
        const byte_width = arr.datatype().byte_width();
        var output: Array = undefined;
        if (arr.isBoolean()) {
            output = try dropBooleanNull(&builder, &itr);
        } else {
            output = try dropNonBooleanNull(arr, &builder, &itr, byte_width);
        }
        return output;
    }
};

const test_allocator = std.testing.allocator;

test "dropNull on Boolean array" {
    const slice = [_]?bool{ true, true, null, null, false, null, true };
    const arr = try ArraySliceBuilder(Datatype.Bool).create(&slice, test_allocator);

    const coalescor = Coalesce.init(test_allocator);
    const new_arr = try coalescor.dropNull(arr);
    defer new_arr.deinit();

    try std.testing.expectEqual(true, (try new_arr.take(0)).bool.value);
    try std.testing.expectEqual(true, (try new_arr.take(1)).bool.value);
    try std.testing.expectEqual(false, (try new_arr.take(2)).bool.value);
    try std.testing.expectEqual(true, (try new_arr.take(3)).bool.value);
    try std.testing.expectEqual(4, new_arr.length());
    try std.testing.expectEqual(0, new_arr.null_count());
}

test "dropNull on Uint16 array" {
    const slice = [_]?u16{ 0, 1, null, null, 2, null, 3 };
    const arr = try ArraySliceBuilder(Datatype.Uint16).create(&slice, test_allocator);

    const coalescor = Coalesce.init(test_allocator);
    const new_arr = try coalescor.dropNull(arr);
    defer new_arr.deinit();

    try std.testing.expectEqual(0, (try new_arr.take(0)).uint16.value);
    try std.testing.expectEqual(1, (try new_arr.take(1)).uint16.value);
    try std.testing.expectEqual(2, (try new_arr.take(2)).uint16.value);
    try std.testing.expectEqual(3, (try new_arr.take(3)).uint16.value);
    try std.testing.expectEqual(4, new_arr.length());
    try std.testing.expectEqual(0, new_arr.null_count());
}

test "dropNull on BinaryView array" {
    const slice = [_]?[]const u8{ null, "one", null, "twotwotwotwotwo", "3", null };
    const arr = try ArraySliceBuilder(Datatype.String).create(&slice, test_allocator);

    const coalescor = Coalesce.init(test_allocator);
    const new_arr = try coalescor.dropNull(arr);
    defer new_arr.deinit();

    try std.testing.expectEqualSlices(u8, "one", (try new_arr.take(0)).string.view);
    try std.testing.expectEqualSlices(u8, "twotwotwotwotwo", (try new_arr.take(1)).string.view);
    try std.testing.expectEqualSlices(u8, "3", (try new_arr.take(2)).string.view);
    try std.testing.expectEqual(3, new_arr.length());
    try std.testing.expectEqual(0, new_arr.null_count());
}
