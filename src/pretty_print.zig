const std = @import("std");
const RecordBatch = @import("record_batch.zig").RecordBatch;
const Datatype = @import("datatype.zig").Datatype;
const Array = @import("array/array.zig").Array;
const ArraySliceBuilder = @import("array/array_builder.zig").ArraySliceBuilder;

const PrinterBuffer = struct {
    const PrinterBufferError = error{OutOfMemory};

    buffer: []u8,
    index: usize,
    size: usize,
    max_col_size: usize,
    allocator: std.mem.Allocator,

    fn init(size: usize, max_col_size: usize, allocator: std.mem.Allocator) !PrinterBuffer {
        const buffer = try allocator.alloc(u8, size);
        return .{
            .buffer = buffer,
            .index = 0,
            .size = size,
            .max_col_size = max_col_size,
            .allocator = allocator,
        };
    }

    fn deinit(self: PrinterBuffer) void {
        self.allocator.free(self.buffer);
    }

    fn repeatedNCharString(self: *PrinterBuffer, char: u8, n: usize) []const u8 {
        @memset(self.buffer[self.index .. self.index + n], char);
        self.index += n;
        return self.buffer[self.index - n .. self.index];
    }

    fn append(self: *PrinterBuffer, slice: []const u8) ![]const u8 {
        const length = @min(self.max_col_size, slice.len);
        if (self.index + length >= self.size) {
            return PrinterBufferError.OutOfMemory;
        }
        @memcpy(self.buffer[self.index .. self.index + length], slice);
        const temp_index = self.index;
        self.index += length;
        return self.buffer[temp_index .. temp_index + length];
    }
};

pub const PrettyPrinter = struct {
    const PrettyPrinterError = error{MaxRowsOutOfRange};

    max_col_size: usize,
    max_rows: usize,
    builder: std.ArrayList(u8),
    buffer: PrinterBuffer,
    allocator: std.mem.Allocator,

    pub fn init(max_rows: usize, max_col_size: usize, allocator: std.mem.Allocator) !PrettyPrinter {
        if (max_rows < 5 and max_rows > 10000) {
            return PrettyPrinterError.MaxRowsOutOfRange;
        }
        const builder = std.ArrayList(u8).init(allocator);
        return .{
            .max_rows = max_rows,
            .max_col_size = @max(80, max_col_size),
            .builder = builder,
            .buffer = undefined,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: PrettyPrinter) void {
        self.builder.deinit();
    }

    pub fn initBuffer(self: *PrettyPrinter, num_cols: usize) !void {
        const capacity = (self.max_rows + 4) * (self.max_col_size + 5) * num_cols;
        try self.builder.ensureTotalCapacity(capacity);
        self.buffer = try PrinterBuffer.init(
            capacity,
            self.max_col_size,
            self.allocator,
        );
    }

    fn divider(self: *PrettyPrinter, n: usize) !void {
        try self.builder.appendSlice(self.buffer.repeatedNCharString('*', n + 1));
        try self.builder.append('\n');
    }

    fn leftPadding(self: *PrettyPrinter) !void {
        try self.builder.appendSlice("| ");
    }

    fn rightPadding(self: *PrettyPrinter, slice_len: usize, col_len: usize) !void {
        std.debug.assert(col_len > slice_len);
        try self.builder.appendSlice(self.buffer.repeatedNCharString(' ', col_len - 2 - slice_len));
    }

    fn indentNewline(self: *PrettyPrinter) !void {
        try self.builder.appendSlice("|\n");
    }

    pub fn printArray(self: *PrettyPrinter, arr: Array) ![]const u8 {
        try self.initBuffer(@intCast(arr.length()));
        defer {
            self.buffer.deinit();
            self.buffer = undefined;
        }

        var buf: [80]u8 = undefined;
        const head = try std.fmt.bufPrint(&buf, "{s} n={d}\n", .{ arr.datatype().toString(), arr.length() });
        try self.builder.appendSlice(head);

        try self.builder.appendSlice("[\n");
        for (0..@intCast(arr.length())) |i| {
            try self.builder.appendSlice("  ");
            const s = try arr.take(i);
            const str = try s.toString(&buf);
            try self.builder.appendSlice(str);
            try self.builder.append(',');
            try self.builder.append('\n');
        }
        try self.builder.appendSlice("]\n");

        const output = try self.builder.toOwnedSlice();
        self.builder = try std.ArrayList(u8).initCapacity(self.allocator, self.buffer.size);
        return output;
    }

    pub fn printRecordBatch(self: *PrettyPrinter, record_batch: RecordBatch) ![]const u8 {
        var str_rb = std.ArrayList(std.ArrayList([]const u8)).init(self.allocator);
        defer {
            for (str_rb.items) |col| {
                col.deinit();
            }
            str_rb.deinit();
        }
        try self.initBuffer(@intCast(record_batch.num_cols));
        defer {
            self.buffer.deinit();
            self.buffer = undefined;
        }

        var buf: [80]u8 = undefined;
        for (record_batch.schema.fields.items) |field| {
            var str_rb_col = std.ArrayList([]const u8).init(self.allocator);
            const bufStr = try std.fmt.bufPrint(&buf, "{s} ({s})", .{ field.name, field.datatype.toString() });
            const str = try self.buffer.append(bufStr);
            try str_rb_col.append(str);
            try str_rb.append(str_rb_col);
        }

        for (record_batch.arrays, 0..) |arr, i| {
            for (0..@intCast(record_batch.num_rows)) |j| {
                const s = try arr.take(j);
                const bufStr = try s.toString(&buf);
                const str = try self.buffer.append(bufStr);
                try str_rb.items[i].append(str);
            }
        }

        var col_lens: []usize = try self.allocator.alloc(usize, @intCast(record_batch.num_cols));
        defer self.allocator.free(col_lens);
        @memset(col_lens, 0);
        for (str_rb.items, 0..) |col, i| {
            for (col.items) |str| {
                col_lens[i] = @max(col_lens[i], str.len);
            }
        }
        var total_col_len: usize = 0;
        for (col_lens) |*len| {
            len.* += 3;
            total_col_len += len.*;
        }

        // headers
        try self.divider(total_col_len);
        for (0..@intCast(record_batch.num_cols)) |i| {
            try self.leftPadding();
            try self.builder.appendSlice(str_rb.items[i].items[0]);
            try self.rightPadding(str_rb.items[i].items[0].len, col_lens[i]);
        }
        try self.indentNewline();
        try self.divider(total_col_len);
        // values
        for (1..@intCast(record_batch.num_rows)) |j| {
            for (0..@intCast(record_batch.num_cols)) |i| {
                try self.leftPadding();
                try self.builder.appendSlice(str_rb.items[i].items[j]);
                try self.rightPadding(str_rb.items[i].items[j].len, col_lens[i]);
            }
            try self.indentNewline();
        }
        try self.divider(total_col_len);

        const output = try self.builder.toOwnedSlice();
        self.builder = try std.ArrayList(u8).initCapacity(self.allocator, self.buffer.size);
        return output;
    }
};

const csv = @import("csv/csv.zig");
const test_allocator = std.testing.allocator;

test "PrettyPrinter print array" {
    const raw = [_]?i16{ 1, null, 100, null, 10000 };
    const arr = try ArraySliceBuilder(Datatype.Int16).create(&raw, test_allocator);
    defer arr.deinit();

    var printer = try PrettyPrinter.init(10, 5, test_allocator);
    const arr_str = try printer.printArray(arr);
    defer test_allocator.free(arr_str);
    const expected =
        \\Int16 n=5
        \\[
        \\  1,
        \\  null,
        \\  100,
        \\  null,
        \\  10000,
        \\]
        \\
    ;
    printer.deinit();
    try std.testing.expectEqualSlices(u8, expected, arr_str);
}

test "PrettyPrinter print record batch" {
    const rb = try csv.toRecordBatch("data/sample.csv", ',', test_allocator);
    defer rb.deinit();
    var printer = try PrettyPrinter.init(10, 20, test_allocator);
    const rb_str = try printer.printRecordBatch(rb);
    defer test_allocator.free(rb_str);
    const expected =
        \\******************************************************************
        \\| id (Int32) | name (String)  | is_active (Bool) | score (Float) |
        \\******************************************************************
        \\| 1          | Alice          | true             | 85.5          |
        \\| 2          | Bob, "the" 3rd | false            | 92.3          |
        \\| 3          | Charlie        | true             | 78            |
        \\| 4          | Diana          | false            | 88.8          |
        \\******************************************************************
        \\
    ;
    printer.deinit();
    try std.testing.expectEqualSlices(u8, expected, rb_str);
}
