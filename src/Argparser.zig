//! Argparser is a small module for handling command line arguments af typed arguments in zig code.
const std = @import("std");

/// Contains the definition of an argument. Long name and short name, if set, is used as the key for retreiving the argument values after parsing.
/// If an Arg is optional a default value must be provided.
pub const Arg = struct {
    longName: []const u8,
    shortName: ?u8 = null,

    description: []const u8,
    argType: ArgType = ArgType.string,
    default: ?[]const u8 = null,

    isOptional: bool = false,
};

/// Type the argument should be parsed as.
/// .bool arguments are switches
pub const ArgType = enum {
    string,
    int,
    uint,
    float,
    bool,
};

/// Union which is set with the ParsedArgs raw value parsed as that type.
pub const ArgVal = union(ArgType) {
    string: []const u8,
    int: i32,
    uint: u32,
    float: f32,
    bool: bool,
};

/// ParsedArg is the retuned argument type after parsing `Arg`s. This contians the long/short name as well as the parsed value.
/// Access the parsed value through the `value()` function or directly using the `getArgVal()` on the returned ArgumentMap from the `parse()` call.
pub const ParsedArg = struct {
    longName: []const u8,
    shortName: ?u8 = null,
    argType: ArgType,
    rawVal: []const u8,

    const Self = @This();

    pub fn value(self: Self) ArgVal {
        switch (self.argType) {
            .string => return .{ .string = self.rawVal },
            .int => return .{ .int = std.fmt.parseInt(i32, self.rawVal, 10) catch {
                @panic("unable to parse value as integer");
            } },
            .uint => return .{ .uint = std.fmt.parseInt(u32, self.rawVal, 10) catch {
                @panic("unable to parse value as unsigned integer");
            } },
            .float => return .{ .float = std.fmt.parseFloat(f32, self.rawVal) catch {
                @panic("unable to parse value as float");
            } },
            .bool => return .{ .bool = std.mem.eql(u8, "true", self.rawVal) or std.mem.eql(u8, "1", self.rawVal) },
        }
    }
};

pub const ParseError = error{ InvalidArgumentValue, MissingArgument, MissingArgumentValue, UnknownArgument };

/// Returns an argument parser that can parse the defined arguments and print a help text with each argument description.
pub fn Parser(comptime prog_desc: []const u8, comptime arg_defs: []const Arg) type {
    inline for (arg_defs) |ad| {
        if (ad.isOptional and ad.default == null) {
            @compileError("argument '" ++ ad.longName ++ "' is optional but doesn't have a default value. Either make it non-optional or set a default value.");
        }
    }

    return struct {
        fn getArgDef(param: []u8) ?Arg {
            //std.debug.print("is {s} an arugment?\n", .{param});
            for (arg_defs) |ad| {
                if (ad.shortName) |sn| {
                    if (param.len == 2 and sn == param[1]) return ad;
                }

                if (param.len > 2 and std.mem.eql(u8, ad.longName, param[2..])) return ad;
            }
            //std.debug.print("NO! {s} is NOT.\n", .{param});
            return null;
        }

        pub fn printHelp(output: std.fs.File) !void {
            const outwriter = output.writer();
            try outwriter.print(("-" ** prog_desc.len) ++ "\n", .{});
            try outwriter.print("{s}\n", .{prog_desc});
            try outwriter.print(("-" ** prog_desc.len) ++ "\n", .{});
            inline for (arg_defs) |ad| {
                if (ad.argType == .bool) {
                    try outwriter.print("\t--{s}", .{ad.longName});
                    if (ad.shortName) |sn| {
                        try outwriter.print(", -{c}", .{sn});
                    }
                } else {
                    try outwriter.print("\t--{s}", .{ad.longName});
                    if (ad.shortName) |sn| {
                        try outwriter.print(", -{c}", .{sn});
                    }
                    try outwriter.print(" <{s} value>", .{@tagName(ad.argType)});
                }
                try outwriter.print("\t {s}\n", .{ad.description});
                if (ad.default) |def| {
                    try outwriter.print("\t\t(default: {s})\n", .{def});
                }
            }
        }

        fn assertCanParseValue(ad: Arg, val: []const u8) !void {
            switch (ad.argType) {
                .string => {
                    return;
                },
                .int => {
                    _ = std.fmt.parseInt(i32, val, 10) catch {
                        return ParseError.InvalidArgumentValue;
                    };
                    return;
                },
                .uint => {
                    _ = std.fmt.parseInt(u32, val, 10) catch {
                        return ParseError.InvalidArgumentValue;
                    };
                    return;
                },
                .float => {
                    _ = std.fmt.parseFloat(f32, val) catch {
                        return ParseError.InvalidArgumentValue;
                    };
                    return;
                },
                .bool => {
                    return;
                },
            }

            return ParseError.InvalidArgumentValue;
        }

        pub fn parse(alloc: std.mem.Allocator, arguments: [][]u8) !ArgumentMap {
            var parsedArgs = ArgumentMap.init(alloc);
            errdefer parsedArgs.deinit();

            try parsedArgs.bm.ensureTotalCapacity(@as(u32, @truncate(arguments.len)) * 2);

            var i: u32 = 0;
            while (i < arguments.len) : (i += 1) {
                const ad = getArgDef(arguments[i]);
                if (ad) |arg| {
                    if (arg.argType == .bool) {
                        try parsedArgs.put(arg.longName, .{ .longName = arg.longName, .argType = arg.argType, .rawVal = "true" });
                        if (arg.shortName) |snb| {
                            const sn = &[_]u8{snb};
                            try parsedArgs.put(sn, .{ .longName = arg.longName, .shortName = arg.shortName, .argType = arg.argType, .rawVal = "true" });
                        }
                    } else {
                        const argVal = if (i + 1 < arguments.len) arguments[i + 1] else return ParseError.MissingArgumentValue;
                        try assertCanParseValue(arg, argVal);

                        try parsedArgs.put(arg.longName, .{ .longName = arg.longName, .argType = arg.argType, .rawVal = argVal });
                        if (arg.shortName) |snb| {
                            const sn = &[_]u8{snb};
                            try parsedArgs.put(sn, .{ .longName = arg.longName, .shortName = arg.shortName, .argType = arg.argType, .rawVal = argVal });
                        }
                        i += 1;
                    }
                } else if (0 < i) {
                    std.debug.print("{s} is an unknown argument\n", .{arguments[i]});
                    return ParseError.UnknownArgument;
                }
            }

            // fill default values
            inline for (arg_defs) |ad| {
                //std.debug.print("validating {s}. opt?: {any}, parsed?: {any}, hasDefault?: {?s}\n", .{ ad.longName, ad.isOptional, parsedArgs.contains(ad.longName), ad.default });
                //std.debug.print("{any}\n", .{!ad.isOptional and !parsedArgs.contains(ad.longName) and ad.default != null});
                if (!parsedArgs.contains(ad.longName)) {
                    if (ad.default) |dv| {
                        try parsedArgs.put(ad.longName, .{ .longName = ad.longName, .argType = ad.argType, .rawVal = dv });
                    } else if (!ad.isOptional) {
                        //std.debug.print("{any}\n", .{ad});
                        return ParseError.MissingArgument;
                    }
                }
            }

            return parsedArgs;
        }
    };
}

/// Basically just a `StringHashMap(ParsedArg)` but with the added `getArgVal()` function that calls the `value()` function on the ParsedArg.
/// If the key does not exist when calling `getArgVal()` it's undefined behavior. Use `get()` if you can't verify the key exists.
pub const ArgumentMap = struct {
    bm: std.StringHashMap(ParsedArg) = undefined,
    // init
    // deinit
    // put
    // getArgVal
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .bm = std.StringHashMap(ParsedArg).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.bm.deinit();
    }

    pub fn put(self: *Self, key: []const u8, value: ParsedArg) !void {
        // std.debug.print("putting key '{s}'\n", .{key});
        try self.bm.put(key, value);
    }

    pub fn getArgVal(self: Self, key: []const u8) ArgVal {
        if (self.bm.get(key)) |val| {
            return val.value();
        } else {
            unreachable;
        }
    }

    pub fn get(self: Self, key: []const u8) ?ParsedArg {
        return self.bm.get(key);
    }

    pub fn contains(self: Self, key: []const u8) bool {
        return self.bm.contains(key);
    }
};
