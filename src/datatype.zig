const std = @import("std");
const string = @import("string.zig");

pub const Datatype = enum {
    Bool,
    Int8,
    Int32,
    Int64,
    String,

    pub fn bit_width(self: Datatype) usize {
        return switch (self) {
            .Bool => 1,
            .Int8 => @bitSizeOf(i8),
            .Int32 => @bitSizeOf(i32),
            .Int64 => @bitSizeOf(i64),
            .String => @bitSizeOf(string.String),
        };
    }

    pub fn ztype(self: Datatype) type {
        return switch (self) {
            .Bool => bool,
            .Int8 => i8,
            .Int32 => i32,
            .Int64 => i64,
            .String => []const u8,
        };
    }

    pub fn scalartype(self: Datatype) type {
        return switch (self) {
            .Bool => bool,
            .Int8 => i8,
            .Int32 => i32,
            .Int64 => i64,
            .String => string.String,
        };
    }

    pub fn isPrimitive(self: Datatype) bool {
        return switch (self) {
            .Bool, .Int8, .Int32, .Int64 => true,
            else => false,
        };
    }
};
