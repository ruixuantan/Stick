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
    };
}

const BoolScalar = BaseScalar(Datatype.Bool);
const Int8Scalar = BaseScalar(Datatype.Int8);
const Int32Scalar = BaseScalar(Datatype.Int32);
const Int64Scalar = BaseScalar(Datatype.Int64);
const StringScalar = BaseScalar(Datatype.String);

pub const Scalar = union(enum) {
    bool: BoolScalar,
    int8: Int8Scalar,
    int32: Int32Scalar,
    int64: Int64Scalar,
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

    pub fn fromString(value: String) Scalar {
        return Scalar{ .string = StringScalar.init(value) };
    }

    pub fn nullString() Scalar {
        return Scalar{ .string = StringScalar.initNull() };
    }

    pub fn fromNullableString(value: ?[]const u8) Scalar {
        if (value) |v| {
            return Scalar.fromString(String.init(v));
        } else {
            return Scalar.nullString();
        }
    }

    pub inline fn parse(datatype: Datatype, raw: anytype) Scalar {
        return switch (datatype) {
            .Bool => Scalar.fromNullableBool(raw),
            .Int8 => Scalar.fromNullableInt8(raw),
            .Int32 => Scalar.fromNullableInt32(raw),
            .Int64 => Scalar.fromNullableInt64(raw),
            .String => Scalar.fromNullableString(raw),
        };
    }

    pub fn isValid(self: Scalar) bool {
        switch (self) {
            inline else => |s| return s.is_valid,
        }
    }

    pub fn toBytes(self: Scalar) []const u8 {
        switch (self) {
            inline else => |s| return &s.toBytes(),
        }
    }
};

const test_allocator = std.testing.allocator;

test "Int32Scalar test" {
    var scalar = Scalar.fromInt32(1);
    const scalar_slice = [_]u8{ 1, 0, 0, 0 };
    const int32_slice = scalar.toBytes();
    try std.testing.expectEqualSlices(u8, &scalar_slice, int32_slice);

    var null_scalar = Scalar.nullInt32();
    const null_slice = null_scalar.toBytes();
    try std.testing.expectEqual(4, null_slice.len);
}

test "BoolScalar test" {
    var scalar = Scalar.fromBool(true);
    const scalar_slice = [_]u8{1};
    const bool_slice = scalar.toBytes();
    try std.testing.expectEqualSlices(u8, &scalar_slice, bool_slice);
}
