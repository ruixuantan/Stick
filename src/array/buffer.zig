const std = @import("std");
const simd = @import("../simd.zig");
const scalar = @import("../scalar.zig");
const Scalar = scalar.Scalar;
const Datatype = @import("../datatype.zig").Datatype;

pub const Buffer = struct {
    data: simd.AlignedBuffer,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Buffer) void {
        self.allocator.free(self.data);
    }

    pub fn size(self: Buffer) usize {
        return self.data.len;
    }

    pub fn clone(self: Buffer) !Buffer {
        const data = try self.allocator.alignedAlloc(u8, simd.ALIGNMENT, self.data.len);
        @memcpy(data, self.data);
        return .{ .data = data, .allocator = self.allocator };
    }
};

pub const Bitmap = struct {
    data: simd.AlignedBuffer,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Bitmap) void {
        self.allocator.free(self.data);
    }

    pub fn size(self: Bitmap) usize {
        return self.data.len;
    }

    pub fn isValid(self: Bitmap, i: usize) !bool {
        std.debug.assert(i <= self.data.len);
        return self.data[i >> 3] & (@as(u8, 1) << @intCast(i % 8)) != 0;
    }
};

pub const BufferBuilder = struct {
    datatype: Datatype,
    data: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(datatype: Datatype, allocator: std.mem.Allocator) BufferBuilder {
        const data = std.ArrayList(u8).init(allocator);
        return .{ .datatype = datatype, .data = data, .allocator = allocator };
    }

    pub fn deinit(self: BufferBuilder) void {
        self.data.deinit();
    }

    pub fn appendNull(self: *BufferBuilder) !void {
        for (0..self.datatype.byteWidth()) |_| {
            try self.data.append(0);
        }
    }

    pub fn append(self: *BufferBuilder, s: Scalar) !void {
        var buf: scalar.ScalarByteBuf = undefined;
        s.toBytes(&buf);
        try self.data.appendSlice(buf[0..self.datatype.byteWidth()]);
    }

    pub fn appendBytes(self: *BufferBuilder, bytes: []const u8) !void {
        std.debug.assert(bytes.len == self.datatype.byteWidth());
        try self.data.appendSlice(bytes);
    }

    pub fn finishBool(self: *BufferBuilder) !Buffer {
        std.debug.assert(self.datatype == Datatype.Bool);
        const builder_length = self.data.items.len;
        const buffer_length = builder_length + simd.ALIGNMENT - (builder_length % simd.ALIGNMENT);

        const buffer = try self.allocator.alignedAlloc(u8, simd.ALIGNMENT, buffer_length);
        @memset(buffer, 0);
        for (self.data.items, 0..) |item, i| {
            buffer[i >> 3] |= item << @intCast(7 - (i % 8));
        }
        return Buffer{ .data = buffer, .allocator = self.allocator };
    }

    pub fn finish(self: *BufferBuilder) !Buffer {
        const builder_length = self.data.items.len;
        const buffer_length = builder_length + simd.ALIGNMENT - (builder_length % simd.ALIGNMENT);

        const buffer = try self.allocator.alignedAlloc(u8, simd.ALIGNMENT, buffer_length);
        @memcpy(buffer[0..builder_length], self.data.items);
        return Buffer{ .data = buffer, .allocator = self.allocator };
    }
};

pub const FixedBufferBuilder = struct {
    const max_size = 32768;

    data: simd.AlignedBuffer,
    size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !FixedBufferBuilder {
        const data = try allocator.alignedAlloc(u8, simd.ALIGNMENT, max_size);
        return .{ .data = data, .size = 0, .allocator = allocator };
    }

    pub fn cannotAccept(self: *FixedBufferBuilder, slice: []const u8) bool {
        return self.size + slice.len >= max_size;
    }

    pub fn append(self: *FixedBufferBuilder, slice: []const u8) void {
        std.debug.assert(self.size + slice.len < max_size);
        @memcpy(self.data[self.size .. self.size + slice.len], slice);
        self.size += slice.len;
    }

    pub fn finish(self: FixedBufferBuilder) !Buffer {
        return Buffer{ .data = self.data, .allocator = self.allocator };
    }
};

pub const BitmapBuilder = struct {
    data: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BitmapBuilder {
        const data = std.ArrayList(u8).init(allocator);
        return .{ .data = data, .allocator = allocator };
    }

    pub fn deinit(self: BitmapBuilder) void {
        self.data.deinit();
    }

    pub fn appendValid(self: *BitmapBuilder) !void {
        try self.data.append(1);
    }

    pub fn appendInvalid(self: *BitmapBuilder) !void {
        try self.data.append(0);
    }

    pub fn finish(self: *BitmapBuilder) !Bitmap {
        while (self.data.items.len % simd.ALIGNMENT != 0) {
            try self.data.append(0);
        }

        const buffer = try self.allocator.alignedAlloc(u8, simd.ALIGNMENT, self.data.items.len);
        @memset(buffer, 0);
        for (self.data.items, 0..) |item, i| {
            buffer[i >> 3] |= item << @intCast((i % 8));
        }
        return Bitmap{ .data = buffer, .allocator = self.allocator };
    }
};

const test_allocator = std.testing.allocator;

test "Int32 Buffer Builder" {
    var builder = BufferBuilder.init(Datatype.Int32, test_allocator);
    defer builder.deinit();
    try builder.append(Scalar.fromInt32(1));
    try builder.append(Scalar.fromInt32(2));
    try builder.append(Scalar.fromInt32(1));

    const buffer = try builder.finish();
    defer buffer.deinit();
    try std.testing.expectEqual(simd.ALIGNMENT, buffer.size());
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 0 }, buffer.data[0..4]);
    try std.testing.expectEqualSlices(u8, &.{ 2, 0, 0, 0 }, buffer.data[4..8]);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 0 }, buffer.data[8..12]);
}

test "Bool Buffer Builder" {
    var builder = BufferBuilder.init(Datatype.Bool, test_allocator);
    defer builder.deinit();
    try builder.append(Scalar.fromBool(true));
    try builder.append(Scalar.fromBool(false));
    try builder.append(Scalar.fromBool(true));

    const buffer = try builder.finishBool();
    defer buffer.deinit();
    try std.testing.expectEqual(simd.ALIGNMENT, buffer.size());
    const data: u8 = @bitCast(buffer.data[0..1][0..1].*);
    try std.testing.expect(data & 0b1000_0000 == 0b1000_0000);
    try std.testing.expect(data & 0b0100_0000 == 0b0000_0000);
    try std.testing.expect(data & 0b0010_0000 == 0b0010_0000);
}

test "Bitmap builder" {
    var builder = BitmapBuilder.init(test_allocator);
    defer builder.deinit();
    try builder.appendValid();
    try builder.appendInvalid();
    try builder.appendValid();

    const bitmap = try builder.finish();
    defer bitmap.deinit();
    try std.testing.expectEqual(simd.ALIGNMENT, bitmap.size());
    try std.testing.expect(try bitmap.isValid(0));
    try std.testing.expect(!try bitmap.isValid(1));
    try std.testing.expect(try bitmap.isValid(2));
}
