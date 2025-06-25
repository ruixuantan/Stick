const std = @import("std");

pub const ALIGNMENT = 64;
pub const AlignedBuffer = []align(ALIGNMENT) u8;

pub const SIMD_LENGTH = std.simd.suggestVectorLength(u8) orelse ALIGNMENT;
pub const SimdRegister = @Vector(SIMD_LENGTH, u8);
