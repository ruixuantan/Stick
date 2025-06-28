const std = @import("std");
const ArraySliceBuilder = @import("../array/array_builder.zig").ArraySliceBuilder;
const array = @import("../array/array.zig");
const NumericArray = array.NumericArray;
const Datatype = @import("../datatype.zig").Datatype;

const rand = std.crypto.random;

pub fn generatei32Slice(n: usize, allocator: std.mem.Allocator) ![]const ?i32 {
    var ls = try std.ArrayList(?i32).initCapacity(allocator, n);
    for (0..n) |_| {
        try ls.append(rand.intRangeAtMost(i32, -100, 100));
    }
    return try ls.toOwnedSlice();
}

pub fn generatei32Array(n: usize, allocator: std.mem.Allocator) !NumericArray {
    const slice = try generatei32Slice(n, allocator);
    defer allocator.free(slice);
    const arr = try ArraySliceBuilder(Datatype.Int32).create(slice, allocator);
    return arr.numeric;
}
