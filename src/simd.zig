const std = @import("std");

pub const ALIGNMENT = 64;

pub const AlignedBuffer = []align(ALIGNMENT) u8;

pub const SimdRegister = @Vector(ALIGNMENT, u8);

pub fn load(slice: []const u8) SimdRegister {
    std.debug.assert(slice.len == ALIGNMENT);
    var register: SimdRegister = undefined;
    inline for (0..ALIGNMENT) |i| {
        register[i] = slice[i];
    }
    return register;
}
