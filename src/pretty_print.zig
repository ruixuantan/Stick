const std = @import("std");
const RecordBatch = @import("record_batch.zig").RecordBatch;

const PrinterBuffer = struct {
    const PrinterBufferError = error{OutOfMemory};

    buffer: []u8,
    index: usize,
    size: usize,
    allocator: std.mem.Allocator,

    fn init(size: usize, allocator: std.mem.Allocator) !PrinterBuffer {
        const buffer = try allocator.alloc(u8, size);
        return .{ .buffer = buffer, .index = 0, .size = size, .allocator = allocator };
    }

    fn deinit(self: PrinterBuffer) void {
        self.allocator.free(self.buffer);
    }

    fn append(self: *PrinterBuffer, slice: []const u8) ![]const u8 {
        if (self.index + slice.len >= self.size) {
            return PrinterBufferError.OutOfMemory;
        }
        @memcpy(self.buffer[self.index .. self.index + slice.len], slice);
        const temp_index = self.index;
        self.index += slice.len;
        return self.buffer[temp_index .. temp_index + slice.len];
    }
};

pub const PrettyPrinter = struct {
    const PrettyPrinterError = error{MaxRowsOutOfRange};

    buffer: PrinterBuffer,
    max_col_size: usize,
    max_rows: usize,
    allocator: std.mem.Allocator,

    pub fn init(max_rows: usize, max_col_size: usize, allocator: std.mem.Allocator) !PrettyPrinter {
        if (max_rows < 5 and max_rows > 10000) {
            return PrettyPrinterError.MaxRowsOutOfRange;
        }
        const buffer = try PrinterBuffer.init((max_rows + 5) * (max_col_size + 10), allocator);
        return .{ .buffer = buffer, .max_rows = max_rows, .max_col_size = @max(80, max_col_size), .allocator = allocator };
    }

    pub fn deinit(self: PrettyPrinter) void {
        self.buffer.deinit();
    }

    pub fn print_record_batch(self: *PrettyPrinter, record_batch: RecordBatch) ![]const u8 {
        var output = std.ArrayList(std.ArrayList([]const u8)).init(self.allocator);
        defer {
            for (output.items) |col| {
                col.deinit();
            }
            output.deinit();
        }

        var buf: [80]u8 = undefined;
        for (record_batch.schema.fields.items) |field| {
            var outputCol = std.ArrayList([]const u8).init(self.allocator);
            const bufStr = try std.fmt.bufPrint(&buf, "{s} ({s})", .{ field.name, field.datatype.toString() });
            const str = try self.buffer.append(bufStr);
            try outputCol.append(str);
            try output.append(outputCol);
        }

        for (record_batch.arrays, 0..) |arr, i| {
            for (0..@intCast(record_batch.num_rows)) |j| {
                const s = try arr.take(j);
                const bufStr = try s.toString(&buf);
                const str = try self.buffer.append(bufStr);
                try output.items[i].append(str);
            }
        }

        for (output.items) |col| {
            for (col.items) |cell| {
                std.debug.print("{s}\n", .{cell});
            }
        }

        return "";
    }
};

const csv = @import("csv/csv.zig");
const test_allocator = std.testing.allocator;

test "PrettyPrinter print record batch" {
    const rb = try csv.toRecordBatch("data/sample.csv", ',', test_allocator);
    defer rb.deinit();
    var printer = try PrettyPrinter.init(10, 20, test_allocator);
    defer printer.deinit();
    _ = try printer.print_record_batch(rb);
}
