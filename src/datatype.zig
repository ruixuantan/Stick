const std = @import("std");
const string = @import("string.zig");

pub const Datatype = enum {
    Bool,
    Int8,
    Int16,
    Int32,
    Int64,
    Float,
    Double,
    String,

    pub fn bit_width(self: Datatype) usize {
        return switch (self) {
            .Bool => 1,
            .Int8 => @bitSizeOf(i8),
            .Int16 => @bitSizeOf(i16),
            .Int32 => @bitSizeOf(i32),
            .Int64 => @bitSizeOf(i64),
            .Float => @bitSizeOf(f32),
            .Double => @bitSizeOf(f64),
            .String => @bitSizeOf(string.String),
        };
    }

    pub fn byte_width(self: Datatype) usize {
        return @max(self.bit_width() >> 3, 1);
    }

    pub fn ztype(self: Datatype) type {
        return switch (self) {
            .Bool => bool,
            .Int8 => i8,
            .Int16 => i16,
            .Int32 => i32,
            .Int64 => i64,
            .Float => f32,
            .Double => f64,
            .String => []const u8,
        };
    }

    pub fn scalartype(self: Datatype) type {
        return switch (self) {
            .Bool => bool,
            .Int8 => i8,
            .Int16 => i16,
            .Int32 => i32,
            .Int64 => i64,
            .Float => f32,
            .Double => f64,
            .String => string.String,
        };
    }

    pub fn isPrimitive(self: Datatype) bool {
        return switch (self) {
            .Bool, .Int8, .Int16, .Int32, .Int64, .Float, .Double => true,
            else => false,
        };
    }
};
