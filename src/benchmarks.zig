const std = @import("std");
const BenchmarkComputeSum = @import("benchmarks/bench_compute_sum.zig").BenchmarkComputeSum;

// Sample command for benchmarking:
// hyperfine --warmup 3 --runs 5 'zig build bench -- simple 10000000' 'zig build bench -- standard 10000000'
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const res = try BenchmarkComputeSum.main(
        args[1],
        try std.fmt.parseInt(usize, args[2], 10),
        allocator,
    );
    std.debug.print("Result: {}\n", .{res});
}
