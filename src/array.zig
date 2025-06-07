const std = @import("std");
const Datatype = @import("datatype.zig").Datatype;
const buffer = @import("buffer.zig");
const Buffer = buffer.Buffer;
const Bitmap = buffer.Bitmap;
const BufferBuilder = buffer.BufferBuilder;
const BitmapBuilder = buffer.BitmapBuilder;
const scalar = @import("scalar.zig");
const Scalar = scalar.Scalar;

pub const Array = struct {
    const ArrayError = error{IndexOutOfBounds};

    datatype: Datatype,
    length: i64,
    null_count: i64,
    buffer: Buffer,
    bitmap: Bitmap,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Array) void {
        self.buffer.deinit();
        self.bitmap.deinit();
    }

    pub fn isValid(self: Array, i: usize) !bool {
        if (i > std.math.maxInt(i64)) {
            return ArrayError.IndexOutOfBounds;
        }
        return self.bitmap.isValid(i);
    }
};

pub const ArrayBuilder = struct {
    const ArrayBuilderError = error{MaxLengthExceeded};

    datatype: Datatype,
    length: i64,
    null_count: i64,
    buffer_builder: BufferBuilder,
    bitmap_builder: BitmapBuilder,
    allocator: std.mem.Allocator,

    pub fn init(datatype: Datatype, allocator: std.mem.Allocator) ArrayBuilder {
        const buffer_builder = BufferBuilder.init(datatype, allocator);
        const bitmap_builder = BitmapBuilder.init(allocator);
        return .{
            .datatype = datatype,
            .length = 0,
            .null_count = 0,
            .buffer_builder = buffer_builder,
            .bitmap_builder = bitmap_builder,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: ArrayBuilder) void {
        self.buffer_builder.deinit();
        self.bitmap_builder.deinit();
    }

    fn appendNull(self: *ArrayBuilder) !void {
        self.null_count += 1;
        self.length += 1;
        try self.buffer_builder.appendNull();
        try self.bitmap_builder.appendInvalid();
    }

    fn append(self: *ArrayBuilder, bytes: []const u8) !void {
        self.length += 1;
        try self.buffer_builder.append(bytes);
        try self.bitmap_builder.appendValid();
    }

    pub fn appendScalar(self: *ArrayBuilder, s: Scalar) !void {
        if (s.isValid()) {
            try self.append(s.toBytes());
        } else {
            try self.appendNull();
        }
    }

    pub fn finish(self: *ArrayBuilder) !Array {
        if (@as(usize, @intCast(self.length)) > std.math.maxInt(i64)) {
            return ArrayBuilderError.MaxLengthExceeded;
        }
        const finish_buffer = try self.buffer_builder.finish();
        const finish_bitmap = try self.bitmap_builder.finish();
        return Array{ .datatype = self.datatype, .length = self.length, .null_count = self.null_count, .buffer = finish_buffer, .bitmap = finish_bitmap, .allocator = self.allocator };
    }
};

pub fn ArraySliceBuilder(datatype: Datatype) type {
    const T = datatype.ztype();

    return struct {
        const Self = @This();

        pub fn create(slice: []const ?T, allocator: std.mem.Allocator) !Array {
            var builder = ArrayBuilder.init(datatype, allocator);
            defer builder.deinit();
            for (slice) |item| {
                const s = Scalar.parse(datatype, item);
                try builder.appendScalar(s);
            }
            return try builder.finish();
        }
    };
}

const test_allocator = std.testing.allocator;

test "Int32 Array Builder" {
    var builder = ArrayBuilder.init(Datatype.Int32, test_allocator);
    defer builder.deinit();

    try builder.appendScalar(Scalar.fromInt32(1));
    try builder.appendScalar(Scalar.fromInt32(2));
    try builder.appendScalar(Scalar.nullInt32());
    try builder.appendScalar(Scalar.fromInt32(3));

    const array = try builder.finish();
    defer array.deinit();

    try std.testing.expectEqual(4, array.length);
    try std.testing.expectEqual(1, array.null_count);
    try std.testing.expect(try array.isValid(0));
    try std.testing.expect(try array.isValid(1));
    try std.testing.expect(!try array.isValid(2));
    try std.testing.expect(try array.isValid(3));
}

test "Bool Array Builder" {
    var builder = ArrayBuilder.init(Datatype.Bool, test_allocator);
    defer builder.deinit();

    try builder.appendScalar(Scalar.fromBool(true));
    try builder.appendScalar(Scalar.fromBool(false));
    try builder.appendScalar(Scalar.nullBool());

    const array = try builder.finish();
    defer array.deinit();

    try std.testing.expectEqual(3, array.length);
    try std.testing.expectEqual(1, array.null_count);
    try std.testing.expect(try array.isValid(0));
    try std.testing.expect(try array.isValid(1));
    try std.testing.expect(!try array.isValid(2));
}

test "ArraySliceBuilder creation" {
    const slice = [_]?i8{ 3, 5, null, 7, null, 8 };
    const array = try ArraySliceBuilder(Datatype.Int8).create(&slice, test_allocator);
    defer array.deinit();

    try std.testing.expectEqual(6, array.length);
    try std.testing.expectEqual(2, array.null_count);
}
