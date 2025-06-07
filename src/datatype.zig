const std = @import("std");

pub const Datatype = enum {
    Bool,
    Int8,
    Int32,
    Int64,

    pub fn bit_width(self: Datatype) usize {
        return switch (self) {
            .Bool => 1,
            .Int8 => 8,
            .Int32 => 32,
            .Int64 => 64,
        };
    }

    pub fn ztype(self: Datatype) type {
        return switch (self) {
            .Bool => bool,
            .Int8 => i8,
            .Int32 => i32,
            .Int64 => i64,
        };
    }
};
