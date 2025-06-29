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
    const v_chunk_size = simd.ALIGNMENT >> 3;

    arr: Array,
    byte_width: usize,
    buffer_len: usize,
    i: usize,

    pub fn init(arr: Array) Iterator {
        return .{
            .arr = arr,
            .byte_width = arr.datatype().byte_width(),
            .buffer_len = arr.buffer().data.len,
            .i = 0,
        };
    }

    pub fn next(self: *Iterator) ?Chunk {
        if (self.i >= self.arr.length()) {
            return null;
        }
        const v_i = self.i >> 3;
        const validity: u64 = @bitCast(self.arr.bitmap().data[v_i .. v_i + v_chunk_size][0..v_chunk_size].*);
        const start = self.i * self.byte_width;
        const end = @min(self.buffer_len, (self.i + simd.ALIGNMENT) * self.byte_width);
        const values = self.arr.buffer().data[start..end];
        self.i += simd.ALIGNMENT;
        return .{ .validity = validity, .values = values };
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

    const byte_width = Datatype.Uint16.byte_width();
    const arr = try ArraySliceBuilder(Datatype.Uint16).create(slice, test_allocator);
    defer arr.deinit();
    var itr = Iterator.init(arr);
    const chunk_1 = itr.next().?;
    const chunk_2 = itr.next().?;
    const chunk_3 = itr.next();

    try std.testing.expectEqual(12297829382473034410, chunk_1.validity); // equivalent to 0b101010...
    try std.testing.expectEqual(0b010010, chunk_2.validity);
    try std.testing.expectEqual(null, chunk_3);

    try std.testing.expectEqual(simd.ALIGNMENT * byte_width, chunk_1.values.len);

    const chunk_1_value_61: u16 = @bitCast(chunk_1.values[61 * byte_width .. 62 * byte_width][0..byte_width].*);
    try std.testing.expectEqual(61, chunk_1_value_61);
    const chunk_2_value_68: u16 = @bitCast(chunk_2.values[4 * byte_width .. 5 * byte_width][0..byte_width].*);
    try std.testing.expectEqual(68, chunk_2_value_68);
}
