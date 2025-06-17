const std = @import("std");
const Datatype = @import("datatype.zig").Datatype;
const String = @import("string.zig").String;

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

        pub fn toBytes(self: Self) [@sizeOf(T)]u8 {
            return std.mem.toBytes(self.value);
        }

        pub fn fromBytes(bytes: []const u8) Self {
            return init(std.mem.bytesAsValue(T, bytes).*);
        }
    };
}

const BoolScalar = BaseScalar(Datatype.Bool);
const Int8Scalar = BaseScalar(Datatype.Int8);
const Int16Scalar = BaseScalar(Datatype.Int16);
const Int32Scalar = BaseScalar(Datatype.Int32);
const Int64Scalar = BaseScalar(Datatype.Int64);
const FloatScalar = BaseScalar(Datatype.Float);
const DoubleScalar = BaseScalar(Datatype.Double);
const StringScalar = BaseScalar(Datatype.String);

pub const Scalar = union(enum) {
    bool: BoolScalar,
    int8: Int8Scalar,
    int16: Int16Scalar,
    int32: Int32Scalar,
    int64: Int64Scalar,
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

    pub fn fromString(value: String) Scalar {
        return Scalar{ .string = StringScalar.init(value) };
    }

    pub fn nullString() Scalar {
        return Scalar{ .string = StringScalar.initNull() };
    }

    pub fn fromNullableString(value: ?String) Scalar {
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
            .Float => Scalar.fromNullableFloat(raw),
            .Double => Scalar.fromNullableDouble(raw),
            .String => Scalar.fromNullableString(raw),
        };
    }

    pub fn isValid(self: Scalar) bool {
        switch (self) {
            inline else => |s| return s.is_valid,
        }
    }

    pub fn toBytes(self: Scalar, allocator: std.mem.Allocator) ![]const u8 {
        switch (self) {
            inline else => |s| return try allocator.dupe(u8, &s.toBytes()),
        }
    }

    pub fn fromBytes(datatype: Datatype, bytes: []const u8) Scalar {
        return switch (datatype) {
            .Bool => Scalar{ .bool = BoolScalar.fromBytes(bytes) },
            .Int8 => Scalar{ .int8 = Int8Scalar.fromBytes(bytes) },
            .Int16 => Scalar{ .int16 = Int16Scalar.fromBytes(bytes) },
            .Int32 => Scalar{ .int32 = Int32Scalar.fromBytes(bytes) },
            .Int64 => Scalar{ .int64 = Int64Scalar.fromBytes(bytes) },
            .Float => Scalar{ .float = FloatScalar.fromBytes(bytes) },
            .Double => Scalar{ .double = DoubleScalar.fromBytes(bytes) },
            .String => Scalar{ .string = StringScalar.fromBytes(bytes) },
        };
    }
};

const test_allocator = std.testing.allocator;

test "Int32Scalar test" {
    var scalar = Scalar.fromInt32(1);
    const scalar_slice = [_]u8{ 1, 0, 0, 0 };
    const int32_slice = try scalar.toBytes(test_allocator);
    defer test_allocator.free(int32_slice);
    try std.testing.expectEqualSlices(u8, &scalar_slice, int32_slice);

    var null_scalar = Scalar.nullInt32();
    const null_slice = try null_scalar.toBytes(test_allocator);
    defer test_allocator.free(null_slice);
    try std.testing.expectEqual(4, null_slice.len);
}

test "BoolScalar test" {
    var scalar = Scalar.fromBool(true);
    const scalar_slice = [_]u8{1};
    const bool_slice = try scalar.toBytes(test_allocator);
    defer test_allocator.free(bool_slice);
    try std.testing.expectEqualSlices(u8, &scalar_slice, bool_slice);
}

test "fromBytes toBytes test" {
    var int32Scalar = Scalar.fromInt32(32);
    const int32Slice = try int32Scalar.toBytes(test_allocator);
    defer test_allocator.free(int32Slice);
    const int32ScalarFrom = Scalar.fromBytes(Datatype.Int32, int32Slice);
    try std.testing.expectEqual(int32Scalar, int32ScalarFrom);

    var doubleScalar = Scalar.fromDouble(2.222);
    const doubleSlice = try doubleScalar.toBytes(test_allocator);
    defer test_allocator.free(doubleSlice);
    const doubleScalarFrom = Scalar.fromBytes(Datatype.Double, doubleSlice);
    try std.testing.expectEqual(doubleScalar, doubleScalarFrom);

    var stringScalar = Scalar.fromString(String.init("string scalar"));
    const stringSlice = try stringScalar.toBytes(test_allocator);
    defer test_allocator.free(stringSlice);
    const stringScalarFrom = Scalar.fromBytes(Datatype.String, stringSlice);
    try std.testing.expectEqual(stringScalar, stringScalarFrom);

    var boolScalar = Scalar.fromBool(false);
    const boolSlice = try boolScalar.toBytes(test_allocator);
    defer test_allocator.free(boolSlice);
    const boolScalarFrom = Scalar.fromBytes(Datatype.Bool, boolSlice);
    try std.testing.expectEqual(boolScalar, boolScalarFrom);
}
