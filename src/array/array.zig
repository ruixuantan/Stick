const std = @import("std");
const Datatype = @import("../datatype.zig").Datatype;
const buffer = @import("buffer.zig");
const Buffer = buffer.Buffer;
const Bitmap = buffer.Bitmap;
const Scalar = @import("../scalar.zig").Scalar;

pub const NumericArray = struct {
    datatype: Datatype,
    length: i64,
    null_count: i64,
    buffer: Buffer,
    bitmap: Bitmap,
    allocator: std.mem.Allocator,

    pub fn deinit(self: NumericArray) void {
        self.buffer.deinit();
        self.bitmap.deinit();
    }

    pub fn takeUnsafe(self: NumericArray, i: usize) Scalar {
        const start = i * self.datatype.byte_width();
        return Scalar.fromBytes(self.datatype, self.buffer.data[start .. start + self.datatype.byte_width()]);
    }
};

pub const BooleanArray = struct {
    datatype: Datatype,
    length: i64,
    null_count: i64,
    buffer: Buffer,
    bitmap: Bitmap,
    allocator: std.mem.Allocator,

    pub fn deinit(self: BooleanArray) void {
        self.buffer.deinit();
        self.bitmap.deinit();
    }

    pub fn takeUnsafe(self: BooleanArray, i: usize) Scalar {
        return Scalar.fromBytes(
            self.datatype,
            &.{@popCount(self.buffer.data[i >> 3] & (@as(u8, 0b1000_0000) >> @intCast(i % 8)))},
        );
    }
};

// String Array
pub const BinaryViewArray = struct {
    datatype: Datatype,
    length: i64,
    null_count: i64,
    views_buffer: Buffer,
    buffers: []const Buffer,
    bitmap: Bitmap,
    allocator: std.mem.Allocator,

    pub fn deinit(self: BinaryViewArray) void {
        self.bitmap.deinit();
        self.views_buffer.deinit();
        for (self.buffers) |b| {
            b.deinit();
        }
        self.allocator.free(self.buffers);
    }

    pub fn takeUnsafe(self: BinaryViewArray, i: usize) Scalar {
        const start = i * self.datatype.byte_width();
        var s = Scalar.fromBytes(
            self.datatype,
            self.views_buffer.data[start .. start + self.datatype.byte_width()],
        );
        if (s.string.base.value.isLong()) {
            const index = s.string.base.value.long.buf_index;
            const offset = s.string.base.value.long.buf_offset;
            const length = s.string.base.value.long.length;
            s.string.view = self.buffers[index].data[offset .. offset + length];
        }
        return s;
    }
};

pub const Array = union(enum) {
    const ArrayError = error{IndexOutOfBounds};

    numeric: NumericArray,
    boolean: BooleanArray,
    binary_view: BinaryViewArray,

    pub fn deinit(self: Array) void {
        switch (self) {
            inline else => |arr| arr.deinit(),
        }
    }

    pub fn isValid(self: Array, i: usize) !bool {
        return switch (self) {
            inline else => |arr| {
                if (i > std.math.maxInt(i64)) {
                    return ArrayError.IndexOutOfBounds;
                }
                return arr.bitmap.isValid(i);
            },
        };
    }

    pub fn null_count(self: Array) i64 {
        return switch (self) {
            inline else => |arr| arr.null_count,
        };
    }

    pub fn length(self: Array) i64 {
        return switch (self) {
            inline else => |arr| arr.length,
        };
    }

    pub fn datatype(self: Array) Datatype {
        return switch (self) {
            inline else => |arr| arr.datatype,
        };
    }

    pub fn take(self: Array, i: usize) !Scalar {
        if (!try self.isValid(i)) {
            return Scalar.parse(self.datatype(), null);
        }
        return switch (self) {
            inline else => |arr| arr.takeUnsafe(i),
        };
    }
};
