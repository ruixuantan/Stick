const std = @import("std");
const array = @import("array/array.zig");
const Array = array.Array;
const ArraySliceBuilder = @import("array/array_builder.zig").ArraySliceBuilder;
const Datatype = @import("datatype.zig").Datatype;
const Schema = @import("schema.zig").Schema;

pub const RecordBatch = struct {
    schema: Schema,
    arrays: []const Array,
    num_rows: i64,
    num_cols: i64,
    allocator: std.mem.Allocator,

    pub fn deinit(self: RecordBatch) void {
        for (self.arrays) |arr| {
            arr.deinit();
        }
        self.allocator.free(self.arrays);
        self.schema.deinit();
    }
};

pub const RecordBatchBuilder = struct {
    const RecordBatchBuilderError = error{ DifferingNamesAndColumnLengths, DifferingColumnLengths };

    schema: Schema,
    arrays: std.ArrayList(Array),
    num_rows: i64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RecordBatchBuilder {
        const arrays = std.ArrayList(Array).init(allocator);
        const schema = Schema.init(allocator);
        return .{ .schema = schema, .arrays = arrays, .num_rows = 0, .allocator = allocator };
    }

    pub fn deinit(self: RecordBatchBuilder) void {
        self.arrays.deinit();
    }

    pub fn addColumn(self: *RecordBatchBuilder, col_name: []const u8, arr: Array) !void {
        if (self.arrays.items.len > 0) {
            if (self.num_rows != arr.length()) {
                return RecordBatchBuilderError.DifferingColumnLengths;
            }
        } else {
            std.debug.assert(arr.length() <= std.math.maxInt(i64));
            self.num_rows = @intCast(arr.length());
        }
        try self.schema.add(col_name, arr.datatype());
        try self.arrays.append(arr);
    }

    pub fn addColumns(self: *RecordBatchBuilder, col_names: []const []const u8, arrays: []const Array) !void {
        if (col_names.len != arrays.len) {
            return RecordBatchBuilderError.DifferingNamesAndColumnLengths;
        }
        for (0..col_names.len) |i| {
            try self.addColumn(col_names[i], arrays[i]);
        }
    }

    pub fn finish(self: *RecordBatchBuilder) !RecordBatch {
        const finish_arrays = try self.arrays.toOwnedSlice();
        const num_cols = if (finish_arrays.len > 0) @as(i64, @intCast(finish_arrays.len)) else 0;
        return RecordBatch{
            .arrays = finish_arrays,
            .schema = self.schema,
            .num_rows = self.num_rows,
            .num_cols = num_cols,
            .allocator = self.allocator,
        };
    }
};

const test_allocator = std.testing.allocator;

test "Simple RecordBatch Builder" {
    const int_slice = [_]?i32{ 1, 2, null, 3, 4 };
    const bool_slice = [_]?bool{ true, null, false, false, null };
    const str_slice = [_]?[]const u8{ "short", "long__godzilla", null, null, null };
    const int_array = try ArraySliceBuilder(Datatype.Int32).create(&int_slice, test_allocator);
    const bool_array = try ArraySliceBuilder(Datatype.Bool).create(&bool_slice, test_allocator);
    const str_array = try ArraySliceBuilder(Datatype.String).create(&str_slice, test_allocator);

    var builder = RecordBatchBuilder.init(test_allocator);
    defer builder.deinit();
    try builder.addColumns(&.{ "int32", "bool", "string" }, &.{ int_array, bool_array, str_array });

    const rb = try builder.finish();
    defer rb.deinit();
    try std.testing.expectEqual(5, rb.num_rows);
    try std.testing.expectEqual(3, rb.num_cols);
}
