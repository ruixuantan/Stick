const std = @import("std");
const simd = @import("../simd.zig");
const Datatype = @import("../datatype.zig").Datatype;
const Scalar = @import("../scalar.zig").Scalar;
const String = @import("../string.zig").String;
const ArrayBuilder = @import("../array/array_builder.zig").ArrayBuilder;
const RecordBatch = @import("../record_batch.zig").RecordBatch;
const RecordBatchBuilder = @import("../record_batch.zig").RecordBatchBuilder;

const SimdMaskRegister = @Vector(simd.ALIGNMENT, u1);

fn prefix_xor(mask: u64) u64 {
    var m = mask;
    var x = m;
    while (x != 0) {
        m ^= (~x + 1) ^ x;
        x &= x - 1;
    }
    return m;
}

const CsvParser = struct {
    buffer: simd.AlignedBuffer,
    mask: std.ArrayList(usize),
    num_cols: usize,
    delimiter: u8,
    allocator: std.mem.Allocator,

    fn init(path: []const u8, delimiter: u8, allocator: std.mem.Allocator) !CsvParser {
        const buffer = try load_file(path, allocator);
        const mask = std.ArrayList(usize).init(allocator);
        return .{
            .buffer = buffer,
            .mask = mask,
            .num_cols = 0,
            .delimiter = delimiter,
            .allocator = allocator,
        };
    }

    fn deinit(self: CsvParser) void {
        self.allocator.free(self.buffer);
        self.mask.deinit();
    }

    fn load_file(path: []const u8, allocator: std.mem.Allocator) !simd.AlignedBuffer {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        const file_size = (try file.stat()).size;
        const buffer = try allocator.alignedAlloc(u8, simd.ALIGNMENT, file_size + simd.ALIGNMENT);
        _ = try file.reader().readAll(buffer);
        return buffer;
    }

    fn maskToIndex(self: *CsvParser, base_idx: usize, mask: SimdMaskRegister) !void {
        var bits: u64 = @bitCast(mask);
        const count = @popCount(bits);
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const index = base_idx + @ctz(bits);
            bits &= (bits - 1);
            try self.mask.append(index);
        }
    }

    fn encode(self: *CsvParser) !void {
        const quotes: simd.SimdRegister = @splat('"');
        const lfs: simd.SimdRegister = @splat('\n');
        const delims: simd.SimdRegister = @splat(self.delimiter);

        var i: usize = 0;
        const max_i = if (self.buffer.len < simd.ALIGNMENT) 0 else self.buffer.len - simd.ALIGNMENT;

        var mode: u64 = 0;
        while (i < max_i) : (i += simd.ALIGNMENT) {
            const b: simd.SimdRegister = self.buffer[i .. i + simd.ALIGNMENT][0..simd.ALIGNMENT].*;
            var q_mask: SimdMaskRegister = @bitCast(b == quotes);
            var d_mask: SimdMaskRegister = @bitCast(b == delims);
            var lf_mask: SimdMaskRegister = @bitCast(b == lfs);

            var mask: u64 = prefix_xor(@bitCast(q_mask));
            mask ^= mode;
            mode = @bitCast(-%@as(i64, @bitCast(mask >> (simd.ALIGNMENT - 1))));
            q_mask = @bitCast(mask);

            lf_mask &= ~q_mask;
            d_mask &= ~q_mask;
            try self.maskToIndex(i, lf_mask | d_mask);
        }
    }

    fn initNumCols(self: *CsvParser) void {
        for (self.mask.items) |i| {
            self.num_cols += 1;
            if (self.buffer[i] == '\n') {
                break;
            }
        }
    }

    fn parse(path: []const u8, delimiter: u8, allocator: std.mem.Allocator) !CsvParser {
        var parser = try CsvParser.init(path, delimiter, allocator);
        try parser.encode();
        parser.initNumCols();
        return parser;
    }

    fn getNthRow(self: CsvParser, n: usize, allocator: std.mem.Allocator) ![]const []const u8 {
        var row = std.ArrayList([]const u8).init(allocator);
        defer row.deinit();

        const start = n * self.num_cols;
        var prev: usize = if (n == 0) 0 else self.mask.items[start - 1] + 1;
        for (start..start + self.num_cols) |i| {
            try row.append(self.buffer[prev..self.mask.items[i]]);
            prev = self.mask.items[i] + 1;
        }
        std.debug.assert(row.items.len == self.num_cols);
        return try row.toOwnedSlice();
    }
};

fn initArrayBuilders(row: []const []const u8, allocator: std.mem.Allocator) !std.ArrayList(ArrayBuilder) {
    var builders = std.ArrayList(ArrayBuilder).init(allocator);
    for (row) |val| {
        var datatype: Datatype = undefined;
        if (val[0] == '"' and val.len > 1 and val[val.len - 1] == '"') {
            datatype = Datatype.inferDatatype(val[1 .. val.len - 2]);
        } else {
            datatype = Datatype.inferDatatype(val);
        }
        std.debug.assert(datatype == Datatype.Float or
            datatype == Datatype.Int32 or
            datatype == Datatype.Bool or
            datatype == Datatype.String);
        try builders.append(try ArrayBuilder.init(datatype, allocator));
    }
    return builders;
}

fn appendBytesAsScalar(
    bytes: []const u8,
    datatype: Datatype,
    builder: *ArrayBuilder,
    allocator: std.mem.Allocator,
) !void {
    if (bytes.len == 0) {
        try builder.appendScalar(Scalar.parse(datatype, null));
    }
    return switch (datatype) {
        .Int32 => {
            const s = Scalar.fromInt32(try std.fmt.parseInt(Datatype.Int32.scalartype(), bytes, 10));
            try builder.appendScalar(s);
        },
        .Float => {
            const s = Scalar.fromFloat(try std.fmt.parseFloat(Datatype.Float.scalartype(), bytes));
            try builder.appendScalar(s);
        },
        .Bool => {
            const s = switch (bytes[0]) {
                't', 'T' => Scalar.fromBool(true),
                'f', 'F' => Scalar.fromBool(false),
                else => @panic("Only values of 'true' or 'false' are recognized"),
            };
            try builder.appendScalar(s);
        },
        .String => {
            var stringBuilder = std.ArrayList(u8).init(allocator);
            defer stringBuilder.deinit();
            for (bytes[0 .. bytes.len - 1], 0..) |c, i| {
                if (c == '"' and bytes[i + 1] == '"') {
                    continue;
                }
                try stringBuilder.append(c);
            }
            try stringBuilder.append(bytes[bytes.len - 1]);
            var s = Scalar.fromString(stringBuilder.items);
            s.string.view = stringBuilder.items;
            try builder.appendScalar(s);
        },
        else => @panic("Only datatypes of Int32, Float, Bool, String are recognized for CSV input"),
    };
}

pub fn toRecordBatch(path: []const u8, delimiter: u8, allocator: std.mem.Allocator) !RecordBatch {
    const parser = try CsvParser.parse(path, delimiter, allocator);
    defer parser.deinit();

    const col_names = try parser.getNthRow(0, allocator);
    defer allocator.free(col_names);

    const firstRow = try parser.getNthRow(1, allocator);
    defer allocator.free(firstRow);

    var builders = try initArrayBuilders(firstRow, allocator);
    defer {
        for (builders.items) |b| {
            b.deinit();
        }
        builders.deinit();
    }

    var prev = parser.mask.items[parser.num_cols - 1] + 1;
    for (parser.mask.items[parser.num_cols..], parser.num_cols..) |m, i| {
        const builder_index = i % parser.num_cols;
        const dt = builders.items[builder_index].datatype();

        var bytes = parser.buffer[prev..m];
        if (bytes[0] == '"' and bytes.len > 1 and bytes[bytes.len - 1] == '"') {
            bytes = bytes[1 .. bytes.len - 1];
        }
        try appendBytesAsScalar(bytes, dt, &builders.items[builder_index], allocator);
        prev = m + 1;
    }

    var rbBuilder = RecordBatchBuilder.init(allocator);
    defer rbBuilder.deinit();
    for (builders.items, 0..) |*b, i| {
        const array = try b.finish();
        try rbBuilder.addColumn(col_names[i], array);
    }
    return try rbBuilder.finish();
}

const test_allocator = std.testing.allocator;

test "prefix_xor" {
    const mask = 0b100100110;
    const expected = 0b011100010;
    try std.testing.expectEqual(expected, prefix_xor(mask));
}

test "CsvParser parse" {
    const parser = try CsvParser.parse("data/sample.csv", ',', test_allocator);
    defer parser.deinit();
    try std.testing.expectEqual(4, parser.num_cols);
}

test "toRecordBatch on sample data" {
    const rb = try toRecordBatch("data/sample.csv", ',', test_allocator);
    defer rb.deinit();
    try std.testing.expectEqual(5, rb.num_rows);
}
