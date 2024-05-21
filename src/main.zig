const std = @import("std");
const Argparser = @import("Argparser.zig");
const Tokenizer = @import("Tokenizer.zig");

pub fn main() !void {
    const arg_file = "file";
    const ap = Argparser.Parser("Convert a delphi file to a list of json tokens.", &[_]Argparser.Arg{
        .{
            .longName = arg_file,
            .shortName = 'f',
            .description = "Input delphi file.",
        },
    });

    // var buff: [8096000]u8 = undefined;
    // var fba = std.heap.FixedBufferAllocator.init(&buff);

    var aa = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer aa.deinit();

    const allocator = aa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var parsedArgs = ap.parse(allocator, args) catch |err| {
        const stderr = std.io.getStdErr();
        stderr.writer().print("{s}\n", .{@errorName(err)}) catch {};
        ap.printHelp(stderr) catch {};
        std.process.exit(1);
    };
    defer parsedArgs.deinit();

    const input_file_path = try getAbsPath(allocator, parsedArgs.getArgVal(arg_file).string);
    defer allocator.free(input_file_path);

    const file_handle = try std.fs.openFileAbsolute(input_file_path, .{ .mode = .read_only });
    const fh_stat = try file_handle.stat();
    const file_cont = try file_handle.readToEndAllocOptions(allocator, std.math.maxInt(u32), fh_stat.size, @sizeOf(u8), 0);
    defer allocator.free(file_cont);

    const stdout = std.io.getStdOut();
    var bufferedWriter = std.io.bufferedWriter(stdout.writer());
    const bufferedWriterWriter = bufferedWriter.writer();

    var first = true;
    try bufferedWriterWriter.print("[\n", .{});
    var tokenizer = Tokenizer.tokenize(file_cont);
    while (true) {
        const token = tokenizer.next();
        if (token.tag == .eof) {
            break;
        }

        if (token.tag == .invalid) {
            std.debug.print("unknown token at index {d}\n", .{token.loc.start});
            std.process.exit(2);
            break;
        }

        if (first) {
            try bufferedWriterWriter.print("\t ", .{});
        } else {
            try bufferedWriterWriter.print("\t,", .{});
        }
        first = false;

        const escaped = try escapeString(allocator, file_cont[token.loc.start..token.loc.end]);
        defer allocator.free(escaped);
        try bufferedWriterWriter.print("{{ \"tag\": \"{s}\", \"loc\": [{d}, {d}], \"value\": \"{s}\" }}\n", .{
            @tagName(token.tag),
            token.loc.start,
            token.loc.end,
            escaped,
        });
    }
    try bufferedWriterWriter.print("]", .{});
    try bufferedWriter.flush();
}

const EscapeError = error{
    TooLong,
};
fn escapeString(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len > 256) return EscapeError.TooLong;

    var buff = std.ArrayList(u8).init(allocator);
    for (input[0..]) |b| {
        if (std.ascii.isPrint(b)) {
            if (b == '"') {
                try buff.append('\\');
            }
            try buff.append(b);
        } else {
            var ucb: [6]u8 = undefined;
            const uc = try std.fmt.bufPrint(&ucb, "\\u{x:0>4}", .{b});
            try buff.appendSlice(uc);
        }
    }
    return try buff.toOwnedSlice();
}

fn getAbsPath(allocator: std.mem.Allocator, pathArg: []const u8) ![]const u8 {
    if (std.fs.path.isAbsolute(pathArg)) {
        return try allocator.dupe(u8, pathArg);
    } else {
        const cwd = try std.fs.cwd().realpathAlloc(allocator, "");
        defer allocator.free(cwd);

        const resolvedPath = try std.fs.path.resolve(allocator, &[_][]const u8{pathArg});
        defer allocator.free(resolvedPath);

        return try std.fs.path.join(allocator, &[_][]const u8{ cwd, resolvedPath });
    }
}
