const std = @import("std");

pub const MAX_PREFIX_LEN = 12;

const ShortString = packed struct {
    length: u32,
    data: u96,

    pub fn init(bytes: []const u8) ShortString {
        std.debug.assert(bytes.len <= MAX_PREFIX_LEN);
        var data = [_]u8{0} ** MAX_PREFIX_LEN;
        for (0..bytes.len) |i| {
            data[i] = bytes[i];
        }
        return .{ .length = @intCast(bytes.len), .data = @bitCast(data) };
    }

    pub fn toString(self: ShortString, buf: []u8) ![]const u8 {
        return try std.fmt.bufPrint(buf, "{s}", .{std.mem.toBytes(self.data)[0..self.length]});
    }
};

const LongString = packed struct {
    length: u32,
    prefix: u32,
    buf_index: u32,
    buf_offset: u32,

    pub fn init(bytes: []const u8) LongString {
        std.debug.assert(bytes.len > MAX_PREFIX_LEN);
        var data = [_]u8{0} ** 4;
        inline for (0..4) |i| {
            data[i] = bytes[i];
        }
        return .{ .length = @intCast(bytes.len), .prefix = @bitCast(data), .buf_index = undefined, .buf_offset = undefined };
    }

    pub fn toString(self: LongString, buf: []u8) ![]const u8 {
        return try std.fmt.bufPrint(buf, "{s}", .{&std.mem.toBytes(self.prefix)});
    }
};

pub const String = union(enum) {
    short: ShortString,
    long: LongString,

    pub fn init(bytes: []const u8) String {
        if (bytes.len > MAX_PREFIX_LEN) {
            return .{ .long = LongString.init(bytes) };
        } else {
            return .{ .short = ShortString.init(bytes) };
        }
    }

    pub fn isLong(self: String) bool {
        return switch (self) {
            .long => true,
            else => false,
        };
    }

    pub fn toString(self: String, buf: []u8) ![]const u8 {
        return switch (self) {
            inline else => |s| try s.toString(buf),
        };
    }

    pub fn toBytes(self: String, buf: []u8) void {
        switch (self) {
            .long => |l| @memcpy(buf, &std.mem.toBytes(l)),
            .short => |s| @memcpy(buf, &std.mem.toBytes(s)),
        }
    }

    pub fn fromBytes(bytes: []const u8) String {
        const short = std.mem.bytesAsValue(ShortString, bytes).*;
        if (short.length <= MAX_PREFIX_LEN) {
            return String{ .short = short };
        } else {
            return String{ .long = std.mem.bytesAsValue(LongString, bytes).* };
        }
    }
};

pub const StringBitSize = @bitSizeOf(ShortString);
pub const StringSize = @sizeOf(ShortString);

test "Initialise short string" {
    const short = "short";
    const str = String.init(short);

    try std.testing.expect(!str.isLong());
    try std.testing.expectEqual(short.len, str.short.length);
    try std.testing.expectEqualSlices(u8, &.{ 's', 'h', 'o', 'r', 't', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, &std.mem.toBytes(str.short.data));
}

test "Initialise long string" {
    const long = "very long string";
    const str = String.init(long);

    try std.testing.expect(str.isLong());
    try std.testing.expectEqual(long.len, str.long.length);
    try std.testing.expectEqualSlices(u8, long[0..4], &std.mem.toBytes(str.long.prefix));
}
