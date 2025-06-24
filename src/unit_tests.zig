comptime {
    _ = @import("string.zig");
    _ = @import("datatype.zig");
    _ = @import("scalar.zig");

    _ = @import("array/buffer.zig");
    _ = @import("array/array.zig");
    _ = @import("array/array_builder.zig");
    _ = @import("array/test_array.zig");

    _ = @import("record_batch.zig");

    _ = @import("csv/csv.zig");
    _ = @import("pretty_print.zig");

    _ = @import("compute/sum.zig");
}
