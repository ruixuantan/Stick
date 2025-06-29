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
    buffer: Buffer,
    binary_buffers: []const Buffer,
    bitmap: Bitmap,
    allocator: std.mem.Allocator,

    pub fn deinit(self: BinaryViewArray) void {
        self.bitmap.deinit();
        self.buffer.deinit();
        for (self.binary_buffers) |b| {
            b.deinit();
        }
        self.allocator.free(self.binary_buffers);
    }

    pub fn cloneBinaryBuffers(self: *BinaryViewArray, from: BinaryViewArray) !void {
        for (self.binary_buffers) |b| {
            b.deinit();
        }
        self.allocator.free(self.binary_buffers);
        var binary_buffers = try self.allocator.alloc(Buffer, from.binary_buffers.len);
        for (from.binary_buffers, 0..) |b, i| {
            binary_buffers[i] = try b.clone();
        }
        self.binary_buffers = binary_buffers;
    }

    pub fn takeUnsafe(self: BinaryViewArray, i: usize) Scalar {
        const start = i * self.datatype.byte_width();
        var s = Scalar.fromBytes(
            self.datatype,
            self.buffer.data[start .. start + self.datatype.byte_width()],
        );
        if (s.string.base.value.isLong()) {
            const index = s.string.base.value.long.buf_index;
            const offset = s.string.base.value.long.buf_offset;
            const length = s.string.base.value.long.length;
            s.string.view = self.binary_buffers[index].data[offset .. offset + length];
        } else {
            const data = s.string.base.value.short.data;
            const length = s.string.base.value.short.length;
            s.string.view = std.mem.toBytes(data)[0..length];
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

    pub fn isBoolean(self: Array) bool {
        return switch (self) {
            .boolean => true,
            else => false,
        };
    }

    pub fn isNumeric(self: Array) bool {
        return switch (self) {
            .numeric => true,
            else => false,
        };
    }

    pub fn isBinaryView(self: Array) bool {
        return switch (self) {
            .binary_view => true,
            else => false,
        };
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

    pub fn bitmap(self: Array) Bitmap {
        return switch (self) {
            inline else => |arr| arr.bitmap,
        };
    }

    pub fn buffer(self: Array) Buffer {
        return switch (self) {
            inline else => |arr| arr.buffer,
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
