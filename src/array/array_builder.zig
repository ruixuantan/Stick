const std = @import("std");
const Datatype = @import("../datatype.zig").Datatype;
const buffer = @import("buffer.zig");
const BufferBuilder = buffer.BufferBuilder;
const FixedBufferBuilder = buffer.FixedBufferBuilder;
const BitmapBuilder = buffer.BitmapBuilder;
const Scalar = @import("../scalar.zig").Scalar;
const string = @import("../string.zig");
const array = @import("array.zig");

const ArrayBuilderError = error{MaxLengthExceeded};

const BaseArrayBuilder = struct {
    datatype: Datatype,
    length: i64,
    null_count: i64,
    buffer_builder: BufferBuilder,
    bitmap_builder: BitmapBuilder,
    allocator: std.mem.Allocator,

    fn init(datatype: Datatype, allocator: std.mem.Allocator) BaseArrayBuilder {
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

    fn deinit(self: BaseArrayBuilder) void {
        self.buffer_builder.deinit();
        self.bitmap_builder.deinit();
    }

    fn appendNull(self: *BaseArrayBuilder) !void {
        self.null_count += 1;
        self.length += 1;
        try self.buffer_builder.appendNull();
        try self.bitmap_builder.appendInvalid();
    }

    fn append(self: *BaseArrayBuilder, bytes: []const u8) !void {
        self.length += 1;
        try self.buffer_builder.append(bytes);
        try self.bitmap_builder.appendValid();
    }

    fn appendScalar(self: *BaseArrayBuilder, s: Scalar) !void {
        if (s.isValid()) {
            try self.append(try s.toBytes(self.allocator));
        } else {
            try self.appendNull();
        }
    }
};

const PrimitiveArrayBuilder = struct {
    base: BaseArrayBuilder,

    pub fn init(datatype: Datatype, allocator: std.mem.Allocator) PrimitiveArrayBuilder {
        std.debug.assert(datatype.isPrimitive());
        const base = BaseArrayBuilder.init(datatype, allocator);
        return .{ .base = base };
    }

    pub fn deinit(self: PrimitiveArrayBuilder) void {
        self.base.deinit();
    }

    pub fn appendScalar(self: *PrimitiveArrayBuilder, s: Scalar) !void {
        try self.base.appendScalar(s);
    }

    pub fn finish(self: *PrimitiveArrayBuilder) !array.Array {
        const finish_buffer = try self.base.buffer_builder.finish();
        const finish_bitmap = try self.base.bitmap_builder.finish();
        return array.Array{ .primitive = array.PrimitiveArray{
            .datatype = self.base.datatype,
            .length = self.base.length,
            .null_count = self.base.null_count,
            .buffer = finish_buffer,
            .bitmap = finish_bitmap,
            .allocator = self.base.allocator,
        } };
    }
};

const BooleanArrayBuilder = struct {
    base: BaseArrayBuilder,

    pub fn init(allocator: std.mem.Allocator) BooleanArrayBuilder {
        const base = BaseArrayBuilder.init(Datatype.Bool, allocator);
        return .{ .base = base };
    }

    pub fn deinit(self: BooleanArrayBuilder) void {
        self.base.deinit();
    }

    pub fn appendScalar(self: *BooleanArrayBuilder, s: Scalar) !void {
        try self.base.appendScalar(s);
    }

    pub fn finish(self: *BooleanArrayBuilder) !array.Array {
        const finish_buffer = try self.base.buffer_builder.finishBool();
        const finish_bitmap = try self.base.bitmap_builder.finish();
        return array.Array{ .boolean = array.BooleanArray{
            .datatype = Datatype.Bool,
            .length = self.base.length,
            .null_count = self.base.null_count,
            .buffer = finish_buffer,
            .bitmap = finish_bitmap,
            .allocator = self.base.allocator,
        } };
    }
};

const BinaryViewArrayBuilder = struct {
    base: BaseArrayBuilder,
    curr_buffer_index: usize,
    buffer_builder: FixedBufferBuilder,
    finished_buffers: std.ArrayList(buffer.Buffer),

    pub fn init(allocator: std.mem.Allocator) !BinaryViewArrayBuilder {
        const base = BaseArrayBuilder.init(Datatype.String, allocator);
        const buffer_builder = try FixedBufferBuilder.init(allocator);
        const finished_buffers = std.ArrayList(buffer.Buffer).init(allocator);
        return .{
            .base = base,
            .curr_buffer_index = 0,
            .buffer_builder = buffer_builder,
            .finished_buffers = finished_buffers,
        };
    }

    pub fn deinit(self: BinaryViewArrayBuilder) void {
        self.base.deinit();
        self.finished_buffers.deinit();
    }

    fn updateLongScalar(self: *BinaryViewArrayBuilder, s: Scalar, str: []const u8) !Scalar {
        std.debug.assert(s.string.value.isLong());

        var updated = s;
        if (self.buffer_builder.cannotAccept(str)) {
            const b = try self.buffer_builder.finish();
            try self.finished_buffers.append(b);
            self.buffer_builder = try FixedBufferBuilder.init(self.base.allocator);
            self.curr_buffer_index += 1;
        }
        updated.string.value.long.buf_index = @intCast(self.curr_buffer_index);
        updated.string.value.long.buf_offset = @intCast(self.buffer_builder.size);
        self.buffer_builder.append(str);
        return updated;
    }

    pub fn appendScalar(self: *BinaryViewArrayBuilder, s: Scalar, raw: []const u8) !void {
        // Scalar shoud have buffer index and offset set
        if (s.isValid() and s.string.value.isLong()) {
            const updated = try self.updateLongScalar(s, raw);
            try self.base.appendScalar(updated);
        } else {
            try self.base.appendScalar(s);
        }
    }

    pub fn finish(self: *BinaryViewArrayBuilder) !array.Array {
        const finish_view_buffer = try self.base.buffer_builder.finish();
        const finish_bitmap = try self.base.bitmap_builder.finish();
        const finish_buffer = try self.buffer_builder.finish();
        try self.finished_buffers.append(finish_buffer);

        return array.Array{ .binary_view = array.BinaryViewArray{
            .datatype = Datatype.String,
            .length = self.base.length,
            .null_count = self.base.null_count,
            .views_buffer = finish_view_buffer,
            .buffers = try self.finished_buffers.toOwnedSlice(),
            .bitmap = finish_bitmap,
            .allocator = self.base.allocator,
        } };
    }
};

pub const ArrayBuilder = union(enum) {
    primitive: PrimitiveArrayBuilder,
    boolean: BooleanArrayBuilder,
    binary_view: BinaryViewArrayBuilder,

    pub fn init(dt: Datatype, allocator: std.mem.Allocator) !ArrayBuilder {
        return switch (dt) {
            .String => ArrayBuilder{ .binary_view = try BinaryViewArrayBuilder.init(allocator) },
            .Bool => ArrayBuilder{ .boolean = BooleanArrayBuilder.init(allocator) },
            else => ArrayBuilder{ .primitive = PrimitiveArrayBuilder.init(dt, allocator) },
        };
    }

    pub fn deinit(self: ArrayBuilder) void {
        switch (self) {
            inline else => |b| b.deinit(),
        }
    }

    pub fn appendScalar(self: *ArrayBuilder, s: Scalar, raw: ?[]const u8) !void {
        switch (self.*) {
            .primitive => |*b| try b.appendScalar(s),
            .boolean => |*b| try b.appendScalar(s),
            .binary_view => |*b| try b.appendScalar(s, raw.?),
        }
    }

    pub fn finish(self: *ArrayBuilder) !array.Array {
        return switch (self.*) {
            inline else => |*b| {
                if (@as(usize, @intCast(b.base.length)) > std.math.maxInt(i64)) {
                    return ArrayBuilderError.MaxLengthExceeded;
                }
                return try b.finish();
            },
        };
    }

    pub fn datatype(self: ArrayBuilder) Datatype {
        return switch (self) {
            .primitive => |p| p.base.datatype,
            .boolean => Datatype.Bool,
            .binary_view => Datatype.String,
        };
    }
};

pub fn ArraySliceBuilder(datatype: Datatype) type {
    const T = datatype.ztype();

    return struct {
        const Self = @This();

        pub fn create(slice: []const ?T, allocator: std.mem.Allocator) !array.Array {
            var builder = try ArrayBuilder.init(datatype, allocator);
            defer builder.deinit();

            for (slice) |item| {
                var s: Scalar = undefined;
                if (datatype == Datatype.String) {
                    const raw = if (item == null) null else string.String.init(item.?);
                    s = Scalar.parse(datatype, raw);
                    if (item != null) {
                        try builder.appendScalar(s, item.?);
                    } else {
                        try builder.appendScalar(s, "");
                    }
                } else {
                    s = Scalar.parse(datatype, item);
                    try builder.appendScalar(s, "");
                }
            }
            return try builder.finish();
        }
    };
}

const test_allocator = std.testing.allocator;

test "Int32 Array Builder" {
    var builder = try ArrayBuilder.init(Datatype.Int32, test_allocator);
    defer builder.deinit();

    try builder.appendScalar(Scalar.fromInt32(1), null);
    try builder.appendScalar(Scalar.fromInt32(2), null);
    try builder.appendScalar(Scalar.nullInt32(), null);
    try builder.appendScalar(Scalar.fromInt32(3), null);

    const arr = try builder.finish();
    defer arr.deinit();

    try std.testing.expectEqual(4, arr.length());
    try std.testing.expectEqual(1, arr.null_count());
    try std.testing.expect(try arr.isValid(0));
    try std.testing.expect(try arr.isValid(1));
    try std.testing.expect(!try arr.isValid(2));
    try std.testing.expect(try arr.isValid(3));
}

test "Bool Array Builder" {
    var builder = try ArrayBuilder.init(Datatype.Bool, test_allocator);
    defer builder.deinit();

    try builder.appendScalar(Scalar.nullBool(), null);
    try builder.appendScalar(Scalar.fromBool(true), null);
    try builder.appendScalar(Scalar.fromBool(false), null);

    const arr = try builder.finish();
    defer arr.deinit();

    try std.testing.expectEqual(3, arr.length());
    try std.testing.expectEqual(1, arr.null_count());
    try std.testing.expect(!try arr.isValid(0));
    try std.testing.expect(try arr.isValid(1));
    try std.testing.expect(try arr.isValid(2));
}

test "String Array Builder" {
    var builder = try ArrayBuilder.init(Datatype.String, test_allocator);
    defer builder.deinit();

    try builder.appendScalar(Scalar.nullString(), "");
    try builder.appendScalar(Scalar.fromString(string.String.init("small")), "");

    const long_str = "long__godzilla";
    var long_scalar = Scalar.fromString(string.String.init(long_str));
    long_scalar = try builder.binary_view.updateLongScalar(long_scalar, long_str);
    try builder.appendScalar(long_scalar, "");

    const long_str2 = "long__godzilla2";
    var long_scalar2 = Scalar.fromString(string.String.init(long_str2));
    long_scalar2 = try builder.binary_view.updateLongScalar(long_scalar2, long_str2);
    try builder.appendScalar(long_scalar2, "");

    const gigantic_str = [_]u8{32} ** 32767;
    var gigantic_scalar = Scalar.fromString(string.String.init(&gigantic_str));
    gigantic_scalar = try builder.binary_view.updateLongScalar(gigantic_scalar, &gigantic_str);

    const arr = try builder.finish();
    defer arr.deinit();

    try std.testing.expectEqual(1, builder.binary_view.curr_buffer_index);

    try std.testing.expectEqual(0, long_scalar.string.value.long.buf_offset);
    try std.testing.expectEqual(0, long_scalar.string.value.long.buf_index);

    try std.testing.expectEqual(long_str.len, long_scalar2.string.value.long.buf_offset);
    try std.testing.expectEqual(0, long_scalar2.string.value.long.buf_index);

    try std.testing.expectEqual(1, gigantic_scalar.string.value.long.buf_index);
    try std.testing.expectEqual(0, gigantic_scalar.string.value.long.buf_offset);

    try std.testing.expectEqual(4, arr.length());
    try std.testing.expectEqual(1, arr.null_count());
    try std.testing.expect(!try arr.isValid(0));
    try std.testing.expect(try arr.isValid(1));
    try std.testing.expect(try arr.isValid(2));
    try std.testing.expect(try arr.isValid(3));
}

test "ArraySliceBuilder creation" {
    const slice = [_]?i8{ 3, 5, null, 7, null, 8 };
    const arr = try ArraySliceBuilder(Datatype.Int8).create(&slice, test_allocator);
    defer arr.deinit();

    try std.testing.expectEqual(6, arr.length());
    try std.testing.expectEqual(2, arr.null_count());
}
