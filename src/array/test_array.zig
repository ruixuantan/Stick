const std = @import("std");
const array_builder = @import("array_builder.zig");
const Datatype = @import("../datatype.zig").Datatype;
const Scalar = @import("../scalar.zig").Scalar;
const String = @import("../string.zig").String;
const ArraySliceBuilder = array_builder.ArraySliceBuilder;

const test_allocator = std.testing.allocator;

test "Primitive Int32 array" {
    const slice = [_]?i32{ 3, 5, null, 7, null, 8 };
    const arr = try ArraySliceBuilder(Datatype.Int32).create(&slice, test_allocator);
    defer arr.deinit();

    try std.testing.expectEqual(6, arr.length());
    try std.testing.expectEqual(2, arr.null_count());
    try std.testing.expectEqual(5, (try arr.take(1)).int32.value);
    try std.testing.expectEqual(Scalar.nullInt32(), try arr.take(4));
}

test "Primitive Bool array" {
    const slice = [_]?bool{ null, true, true, false };
    const arr = try ArraySliceBuilder(Datatype.Bool).create(&slice, test_allocator);
    defer arr.deinit();

    try std.testing.expectEqual(4, arr.length());
    try std.testing.expectEqual(1, arr.null_count());
    try std.testing.expectEqual(true, (try arr.take(1)).bool.value);
    try std.testing.expectEqual(false, (try arr.take(3)).bool.value);
    try std.testing.expectEqual(Scalar.nullBool(), try arr.take(0));
}

test "BinaryView String array" {
    const slice = [_]?[]const u8{ "a", "bbbbbbbbbbbbbbbbbbbbbbb", null, "ccc" };
    const arr = try ArraySliceBuilder(Datatype.String).create(&slice, test_allocator);
    defer arr.deinit();

    try std.testing.expectEqual(4, arr.length());
    try std.testing.expectEqual(1, arr.null_count());
    try std.testing.expectEqual(String.init("ccc"), (try arr.take(3)).string.value);
    try std.testing.expectEqual(Scalar.nullString(), try arr.take(2));
}
