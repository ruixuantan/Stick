const std = @import("std");
const Datatype = @import("../datatype.zig").Datatype;
const buffer = @import("buffer.zig");
const Buffer = buffer.Buffer;
const Bitmap = buffer.Bitmap;
const BufferBuilder = buffer.BufferBuilder;
const BitmapBuilder = buffer.BitmapBuilder;
const scalar = @import("../scalar.zig");
const Scalar = scalar.Scalar;

pub const PrimitiveArray = struct {
    datatype: Datatype,
    length: i64,
    null_count: i64,
    buffer: Buffer,
    bitmap: Bitmap,
    allocator: std.mem.Allocator,

    pub fn deinit(self: PrimitiveArray) void {
        self.buffer.deinit();
        self.bitmap.deinit();
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
};

pub const Array = union(enum) {
    const ArrayError = error{IndexOutOfBounds};

    primitive: PrimitiveArray,
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
            inline else => |s| s.null_count,
        };
    }

    pub fn length(self: Array) i64 {
        return switch (self) {
            inline else => |s| s.length,
        };
    }

    pub fn datatype(self: Array) Datatype {
        return switch (self) {
            inline else => |s| s.datatype,
        };
    }
};
