const std = @import("std");
const string = @import("string.zig");

pub const Datatype = enum {
    Bool,
    Int8,
    Int16,
    Int32,
    Int64,
    Uint8,
    Uint16,
    Uint32,
    Uint64,
    Float,
    Double,
    String,

    pub inline fn bitWidth(self: Datatype) usize {
        return switch (self) {
            .Bool => 1,
            .Int8 => @bitSizeOf(i8),
            .Int16 => @bitSizeOf(i16),
            .Int32 => @bitSizeOf(i32),
            .Int64 => @bitSizeOf(i64),
            .Uint8 => @bitSizeOf(u8),
            .Uint16 => @bitSizeOf(u16),
            .Uint32 => @bitSizeOf(u32),
            .Uint64 => @bitSizeOf(u64),
            .Float => @bitSizeOf(f32),
            .Double => @bitSizeOf(f64),
            .String => string.StringBitSize,
        };
    }

    pub inline fn toString(self: Datatype) []const u8 {
        return switch (self) {
            .Bool => "Bool",
            .Int8 => "Int8",
            .Int16 => "Int16",
            .Int32 => "Int32",
            .Int64 => "Int64",
            .Uint8 => "Uint8",
            .Uint16 => "Uint16",
            .Uint32 => "Uint32",
            .Uint64 => "Uint64",
            .Float => "Float",
            .Double => "Double",
            .String => "String",
        };
    }

    pub inline fn byteWidth(self: Datatype) usize {
        return @max(self.bitWidth() >> 3, 1);
    }

    pub inline fn ztype(self: Datatype) type {
        return switch (self) {
            .Bool => bool,
            .Int8 => i8,
            .Int16 => i16,
            .Int32 => i32,
            .Int64 => i64,
            .Uint8 => u8,
            .Uint16 => u16,
            .Uint32 => u32,
            .Uint64 => u64,
            .Float => f32,
            .Double => f64,
            .String => []const u8,
        };
    }

    pub inline fn scalartype(self: Datatype) type {
        return switch (self) {
            .String => string.String,
            else => self.ztype(),
        };
    }

    pub inline fn isNumeric(self: Datatype) bool {
        return switch (self) {
            .Int8, .Int16, .Int32, .Int64, .Uint8, .Uint16, .Uint32, .Uint64, .Float, .Double => true,
            else => false,
        };
    }

    pub fn inferDatatype(raw: []const u8) Datatype {
        if (raw.len == 4) {
            var output: [4]u8 = undefined;
            _ = std.ascii.lowerString(&output, raw[0..4]);
            if (std.mem.eql(u8, &output, "true")) {
                return Datatype.Bool;
            }
        } else if (raw.len == 5) {
            var output: [5]u8 = undefined;
            _ = std.ascii.lowerString(&output, raw[0..5]);
            if (std.mem.eql(u8, &output, "false")) {
                return Datatype.Bool;
            }
        }

        _ = std.fmt.parseInt(i32, raw, 10) catch {
            _ = std.fmt.parseFloat(f32, raw) catch {
                return Datatype.String;
            };
            return Datatype.Float;
        };
        return Datatype.Int32;
    }
};

test "infer Datatype" {
    try std.testing.expectEqual(Datatype.Bool, Datatype.inferDatatype("false"));
    try std.testing.expectEqual(Datatype.Bool, Datatype.inferDatatype("true"));
    try std.testing.expectEqual(Datatype.String, Datatype.inferDatatype("adlfj29ehqp234p7gh"));
    try std.testing.expectEqual(Datatype.Float, Datatype.inferDatatype("213842.1823"));
    try std.testing.expectEqual(Datatype.Float, Datatype.inferDatatype("-213842.1823"));
    try std.testing.expectEqual(Datatype.Int32, Datatype.inferDatatype("2138421823"));
    try std.testing.expectEqual(Datatype.Int32, Datatype.inferDatatype("-2138421823"));
}
