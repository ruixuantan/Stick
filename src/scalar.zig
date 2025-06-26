const std = @import("std");
const Datatype = @import("datatype.zig").Datatype;
const string = @import("string.zig");
const String = string.String;

pub const ScalarByteBuf = [string.StringSize]u8;

fn BaseScalar(datatype: Datatype) type {
    const T = datatype.scalartype();

    return struct {
        const Self = @This();

        is_valid: bool,
        value: T,

        pub fn init(value: T) Self {
            return .{ .is_valid = true, .value = value };
        }

        pub fn initNull() Self {
            return .{ .is_valid = false, .value = undefined };
        }

        pub fn toBytes(self: Self, buf: []u8) void {
            @memcpy(buf[0..datatype.byte_width()], &std.mem.toBytes(self.value));
        }

        pub fn fromBytes(bytes: []const u8) Self {
            return init(std.mem.bytesAsValue(T, bytes).*);
        }
    };
}

const StringScalar = struct {
    const BaseStringScalar = BaseScalar(Datatype.String);

    base: BaseStringScalar,
    view: []const u8,

    pub fn init(value: []const u8) StringScalar {
        const base = BaseStringScalar.init(String.init(value));
        return .{ .base = base, .view = value };
    }

    pub fn initNull() StringScalar {
        return .{ .base = BaseStringScalar.initNull(), .view = undefined };
    }

    pub fn toBytes(self: StringScalar, buf: []u8) void {
        self.base.value.toBytes(buf);
    }

    pub fn fromBytes(bytes: []const u8) StringScalar {
        std.debug.assert(bytes.len == string.StringSize);
        return .{ .base = BaseStringScalar.init(String.fromBytes(bytes)), .view = undefined };
    }

    pub fn toString(self: StringScalar, buf: []u8) ![]const u8 {
        if (self.base.value.isLong()) {
            return self.view;
        } else {
            return try self.base.value.toString(buf);
        }
    }
};

const BoolScalar = BaseScalar(Datatype.Bool);
const Int8Scalar = BaseScalar(Datatype.Int8);
const Int16Scalar = BaseScalar(Datatype.Int16);
const Int32Scalar = BaseScalar(Datatype.Int32);
const Int64Scalar = BaseScalar(Datatype.Int64);
const Uint8Scalar = BaseScalar(Datatype.Uint8);
const Uint16Scalar = BaseScalar(Datatype.Uint16);
const Uint32Scalar = BaseScalar(Datatype.Uint32);
const Uint64Scalar = BaseScalar(Datatype.Uint64);
const FloatScalar = BaseScalar(Datatype.Float);
const DoubleScalar = BaseScalar(Datatype.Double);

pub const Scalar = union(enum) {
    bool: BoolScalar,
    int8: Int8Scalar,
    int16: Int16Scalar,
    int32: Int32Scalar,
    int64: Int64Scalar,
    uint8: Uint8Scalar,
    uint16: Uint16Scalar,
    uint32: Uint32Scalar,
    uint64: Uint64Scalar,
    float: FloatScalar,
    double: DoubleScalar,
    string: StringScalar,

    pub fn fromBool(value: bool) Scalar {
        return Scalar{ .bool = BoolScalar.init(value) };
    }

    pub fn nullBool() Scalar {
        return Scalar{ .bool = BoolScalar.initNull() };
    }

    pub fn fromNullableBool(value: ?bool) Scalar {
        if (value) |v| {
            return Scalar.fromBool(v);
        } else {
            return Scalar.nullBool();
        }
    }

    pub fn fromInt8(value: i8) Scalar {
        return Scalar{ .int8 = Int8Scalar.init(value) };
    }

    pub fn nullInt8() Scalar {
        return Scalar{ .int8 = Int8Scalar.initNull() };
    }

    pub fn fromNullableInt8(value: ?i8) Scalar {
        if (value) |v| {
            return Scalar.fromInt8(v);
        } else {
            return Scalar.nullInt8();
        }
    }

    pub fn fromInt16(value: i16) Scalar {
        return Scalar{ .int16 = Int16Scalar.init(value) };
    }

    pub fn nullInt16() Scalar {
        return Scalar{ .int16 = Int16Scalar.initNull() };
    }

    pub fn fromNullableInt16(value: ?i16) Scalar {
        if (value) |v| {
            return Scalar.fromInt16(v);
        } else {
            return Scalar.nullInt16();
        }
    }

    pub fn fromInt32(value: i32) Scalar {
        return Scalar{ .int32 = Int32Scalar.init(value) };
    }

    pub fn nullInt32() Scalar {
        return Scalar{ .int32 = Int32Scalar.initNull() };
    }

    pub fn fromNullableInt32(value: ?i32) Scalar {
        if (value) |v| {
            return Scalar.fromInt32(v);
        } else {
            return Scalar.nullInt32();
        }
    }

    pub fn fromInt64(value: i64) Scalar {
        return Scalar{ .int64 = Int64Scalar.init(value) };
    }

    pub fn nullInt64() Scalar {
        return Scalar{ .int64 = Int64Scalar.initNull() };
    }

    pub fn fromNullableInt64(value: ?i64) Scalar {
        if (value) |v| {
            return Scalar.fromInt64(v);
        } else {
            return Scalar.nullInt64();
        }
    }

    pub fn fromUint8(value: u8) Scalar {
        return Scalar{ .uint8 = Uint8Scalar.init(value) };
    }

    pub fn nullUint8() Scalar {
        return Scalar{ .uint8 = Uint8Scalar.initNull() };
    }

    pub fn fromNullableUint8(value: ?u8) Scalar {
        if (value) |v| {
            return Scalar.fromUint8(v);
        } else {
            return Scalar.nullUint8();
        }
    }

    pub fn fromUint16(value: u16) Scalar {
        return Scalar{ .uint16 = Uint16Scalar.init(value) };
    }

    pub fn nullUint16() Scalar {
        return Scalar{ .uint16 = Uint16Scalar.initNull() };
    }

    pub fn fromNullableUint16(value: ?u16) Scalar {
        if (value) |v| {
            return Scalar.fromUint16(v);
        } else {
            return Scalar.nullUint16();
        }
    }

    pub fn fromUint32(value: u32) Scalar {
        return Scalar{ .uint32 = Uint32Scalar.init(value) };
    }

    pub fn nullUint32() Scalar {
        return Scalar{ .uint32 = Uint32Scalar.initNull() };
    }

    pub fn fromNullableUint32(value: ?u32) Scalar {
        if (value) |v| {
            return Scalar.fromUint32(v);
        } else {
            return Scalar.nullUint32();
        }
    }

    pub fn fromUint64(value: u64) Scalar {
        return Scalar{ .uint64 = Uint64Scalar.init(value) };
    }

    pub fn nullUint64() Scalar {
        return Scalar{ .uint64 = Uint64Scalar.initNull() };
    }

    pub fn fromNullableUint64(value: ?u64) Scalar {
        if (value) |v| {
            return Scalar.fromUint64(v);
        } else {
            return Scalar.nullUint64();
        }
    }

    pub fn fromFloat(value: f32) Scalar {
        return Scalar{ .float = FloatScalar.init(value) };
    }

    pub fn nullFloat() Scalar {
        return Scalar{ .float = FloatScalar.initNull() };
    }

    pub fn fromNullableFloat(value: ?f32) Scalar {
        if (value) |v| {
            return Scalar.fromFloat(v);
        } else {
            return Scalar.nullFloat();
        }
    }

    pub fn fromDouble(value: f64) Scalar {
        return Scalar{ .double = DoubleScalar.init(value) };
    }

    pub fn nullDouble() Scalar {
        return Scalar{ .double = DoubleScalar.initNull() };
    }

    pub fn fromNullableDouble(value: ?f64) Scalar {
        if (value) |v| {
            return Scalar.fromDouble(v);
        } else {
            return Scalar.nullDouble();
        }
    }

    pub fn fromString(value: []const u8) Scalar {
        return Scalar{ .string = StringScalar.init(value) };
    }

    pub fn nullString() Scalar {
        return Scalar{ .string = StringScalar.initNull() };
    }

    pub fn fromNullableString(value: ?[]const u8) Scalar {
        if (value) |v| {
            return Scalar.fromString(v);
        } else {
            return Scalar.nullString();
        }
    }

    pub inline fn parse(datatype: Datatype, raw: anytype) Scalar {
        return switch (datatype) {
            .Bool => Scalar.fromNullableBool(raw),
            .Int8 => Scalar.fromNullableInt8(raw),
            .Int16 => Scalar.fromNullableInt16(raw),
            .Int32 => Scalar.fromNullableInt32(raw),
            .Int64 => Scalar.fromNullableInt64(raw),
            .Uint8 => Scalar.fromNullableUint8(raw),
            .Uint16 => Scalar.fromNullableUint16(raw),
            .Uint32 => Scalar.fromNullableUint32(raw),
            .Uint64 => Scalar.fromNullableUint64(raw),
            .Float => Scalar.fromNullableFloat(raw),
            .Double => Scalar.fromNullableDouble(raw),
            .String => Scalar.fromNullableString(raw),
        };
    }

    pub fn isValid(self: Scalar) bool {
        switch (self) {
            .string => |s| return s.base.is_valid,
            inline else => |s| return s.is_valid,
        }
    }

    pub fn toBytes(self: Scalar, buf: []u8) void {
        switch (self) {
            inline else => |s| s.toBytes(buf),
        }
    }

    pub fn fromBytes(datatype: Datatype, bytes: []const u8) Scalar {
        return switch (datatype) {
            .Bool => Scalar{ .bool = BoolScalar.fromBytes(bytes) },
            .Int8 => Scalar{ .int8 = Int8Scalar.fromBytes(bytes) },
            .Int16 => Scalar{ .int16 = Int16Scalar.fromBytes(bytes) },
            .Int32 => Scalar{ .int32 = Int32Scalar.fromBytes(bytes) },
            .Int64 => Scalar{ .int64 = Int64Scalar.fromBytes(bytes) },
            .Uint8 => Scalar{ .uint8 = Uint8Scalar.fromBytes(bytes) },
            .Uint16 => Scalar{ .uint16 = Uint16Scalar.fromBytes(bytes) },
            .Uint32 => Scalar{ .uint32 = Uint32Scalar.fromBytes(bytes) },
            .Uint64 => Scalar{ .uint64 = Uint64Scalar.fromBytes(bytes) },
            .Float => Scalar{ .float = FloatScalar.fromBytes(bytes) },
            .Double => Scalar{ .double = DoubleScalar.fromBytes(bytes) },
            .String => Scalar{ .string = StringScalar.fromBytes(bytes) },
        };
    }

    pub fn toString(self: Scalar, buf: []u8) ![]const u8 {
        if (!self.isValid()) {
            return "null";
        }
        return switch (self) {
            .bool => try std.fmt.bufPrint(buf, "{any}", .{self.bool.value}),
            .int8 => try std.fmt.bufPrint(buf, "{d}", .{self.int8.value}),
            .int16 => try std.fmt.bufPrint(buf, "{d}", .{self.int16.value}),
            .int32 => try std.fmt.bufPrint(buf, "{d}", .{self.int32.value}),
            .int64 => try std.fmt.bufPrint(buf, "{d}", .{self.int64.value}),
            .uint8 => try std.fmt.bufPrint(buf, "{d}", .{self.uint8.value}),
            .uint16 => try std.fmt.bufPrint(buf, "{d}", .{self.uint16.value}),
            .uint32 => try std.fmt.bufPrint(buf, "{d}", .{self.uint32.value}),
            .uint64 => try std.fmt.bufPrint(buf, "{d}", .{self.uint64.value}),
            .float => try std.fmt.bufPrint(buf, "{d}", .{self.float.value}),
            .double => try std.fmt.bufPrint(buf, "{d}", .{self.double.value}),
            .string => try self.string.toString(buf),
        };
    }
};

const test_allocator = std.testing.allocator;

test "Int32Scalar test" {
    var buf: [string.StringSize]u8 = undefined;
    var scalar = Scalar.fromInt32(1);
    const scalar_slice = [_]u8{ 1, 0, 0, 0 };
    scalar.toBytes(&buf);
    try std.testing.expectEqualSlices(u8, &scalar_slice, buf[0..4]);
}

test "BoolScalar test" {
    var buf: [string.StringSize]u8 = undefined;
    var scalar = Scalar.fromBool(true);
    const scalar_slice = [_]u8{1};
    scalar.toBytes(&buf);
    try std.testing.expectEqualSlices(u8, &scalar_slice, buf[0..1]);
}

test "fromBytes toBytes test" {
    var buf: [string.StringSize]u8 = undefined;
    var int32Scalar = Scalar.fromInt32(32);
    int32Scalar.toBytes(&buf);
    const int32ScalarFrom = Scalar.fromBytes(Datatype.Int32, buf[0..4]);
    try std.testing.expectEqual(int32Scalar, int32ScalarFrom);

    var doubleScalar = Scalar.fromDouble(2.222);
    doubleScalar.toBytes(&buf);
    const doubleScalarFrom = Scalar.fromBytes(Datatype.Double, buf[0..8]);
    try std.testing.expectEqual(doubleScalar, doubleScalarFrom);

    var stringScalar = Scalar.fromString("string scalar");
    stringScalar.toBytes(&buf);
    const stringScalarFrom = Scalar.fromBytes(Datatype.String, buf[0..16]);
    try std.testing.expectEqual(stringScalar.string.base, stringScalarFrom.string.base);

    var boolScalar = Scalar.fromBool(false);
    boolScalar.toBytes(&buf);
    const boolScalarFrom = Scalar.fromBytes(Datatype.Bool, buf[0..1]);
    try std.testing.expectEqual(boolScalar, boolScalarFrom);
}
