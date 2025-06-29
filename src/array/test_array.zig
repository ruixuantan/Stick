const std = @import("std");
const array_builder = @import("array_builder.zig");
const Datatype = @import("../datatype.zig").Datatype;
const Scalar = @import("../scalar.zig").Scalar;
const String = @import("../string.zig").String;
const ArraySliceBuilder = array_builder.ArraySliceBuilder;

const test_allocator = std.testing.allocator;

test "Numeric Int32 array" {
    const slice = [_]?i32{ 3, 5, null, 7, null, 8 };
    const arr = try ArraySliceBuilder(Datatype.Int32).create(&slice, test_allocator);
    defer arr.deinit();

    try std.testing.expectEqual(6, arr.length());
    try std.testing.expectEqual(2, arr.nullCount());
    try std.testing.expectEqual(5, (try arr.get(1)).int32.value);
    try std.testing.expectEqual(Scalar.nullInt32(), try arr.get(4));
}

test "Bool array" {
    const slice = [_]?bool{ null, true, true, false };
    const arr = try ArraySliceBuilder(Datatype.Bool).create(&slice, test_allocator);
    defer arr.deinit();

    try std.testing.expectEqual(4, arr.length());
    try std.testing.expectEqual(1, arr.nullCount());
    try std.testing.expectEqual(true, (try arr.get(1)).bool.value);
    try std.testing.expectEqual(false, (try arr.get(3)).bool.value);
    try std.testing.expectEqual(Scalar.nullBool(), try arr.get(0));
}

test "BinaryView String array" {
    const slice = [_]?[]const u8{ "a", "bbbbbbbbbbbbbbbbbbbbbbb", null, "ccc" };
    const arr = try ArraySliceBuilder(Datatype.String).create(&slice, test_allocator);
    defer arr.deinit();

    try std.testing.expectEqual(4, arr.length());
    try std.testing.expectEqual(1, arr.nullCount());
    try std.testing.expectEqual(String.init("ccc"), (try arr.get(3)).string.base.value);
    try std.testing.expectEqual(Scalar.nullString(), try arr.get(2));
}
