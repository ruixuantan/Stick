const std = @import("std");
const Array = @import("array.zig").Array;
const ArraySliceBuilder = @import("array_builder.zig").ArraySliceBuilder;
const Datatype = @import("../datatype.zig").Datatype;
const simd = @import("../simd.zig");

pub const Iterator = struct {
    const Chunk = struct {
        validity: u64,
        values: []u8,
    };
    const validity_chunk_size = simd.ALIGNMENT >> 3;

    arr: Array,
    i: usize,

    pub fn init(arr: Array) Iterator {
        return .{ .arr = arr, .i = 0 };
    }

    pub fn next(self: *Iterator) ?Chunk {
        if (self.i >= self.arr.length()) {
            return null;
        } else {
            const v_i = self.i >> 3;
            const validity: u64 = @bitCast(self.arr.bitmap().data[v_i .. v_i + validity_chunk_size][0..validity_chunk_size].*);
            const values = self.arr.buffer().data[self.i .. self.i + simd.ALIGNMENT];
            self.i += simd.ALIGNMENT;
            return .{ .validity = validity, .values = values };
        }
    }

    pub fn reset(self: *Iterator) void {
        self.i = 0;
    }
};

const test_allocator = std.testing.allocator;

test "Iterator over Uint16 array of length 70" {
    const slice = try test_allocator.alloc(?u16, 70);
    defer test_allocator.free(slice);
    for (0..64) |i| {
        if (i % 2 == 0) {
            slice[i] = null;
        } else {
            slice[i] = @intCast(i);
        }
    }
    slice[64] = null;
    slice[65] = 65;
    slice[66] = null;
    slice[67] = null;
    slice[68] = 68;
    slice[69] = null;

    const arr = try ArraySliceBuilder(Datatype.Uint16).create(slice, test_allocator);
    defer arr.deinit();
    var itr = Iterator.init(arr);
    const chunk_1 = itr.next().?;
    const chunk_2 = itr.next().?;
    const chunk_3 = itr.next();

    try std.testing.expectEqual(12297829382473034410, chunk_1.validity); // equivalent to 0b101010...
    try std.testing.expectEqual(0b010010, chunk_2.validity);
    try std.testing.expectEqual(null, chunk_3);
}
