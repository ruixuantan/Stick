const std = @import("std");

pub const ALIGNMENT = 64;

pub const AlignedBuffer = []align(ALIGNMENT) u8;

pub const SimdRegister = @Vector(ALIGNMENT, u8);
