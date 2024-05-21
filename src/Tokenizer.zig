const std = @import("std");

const Token = struct {
    tag: Tag,
    loc: Loc,
};

const Loc = struct {
    start: usize,
    end: usize,
};

const Tokenizer = @This();
buffer: [:0]const u8,
index: usize,

pub fn tokenize(buff: [:0]const u8) Tokenizer {
    const src_start: usize = if (std.mem.startsWith(u8, buff, "\xEF\xBB\xBF")) 3 else 0;
    return .{
        .buffer = buff,
        .index = src_start,
    };
}

pub fn next(self: *Tokenizer) Token {
    var state: State = .start;
    var result: Token = .{
        .tag = .eof,
        .loc = .{
            .start = self.index,
            .end = undefined,
        },
    };

    // std.debug.print("\nscanning token: ", .{});
    while (true) : (self.index += 1) {
        const c = self.buffer[self.index];
        // std.debug.print("{c}", .{c});
        switch (state) {
            .start => switch (c) {
                0, 0x1a => {
                    if (self.index < self.buffer.len - 1) {
                        result.tag = .invalid;
                        result.loc.start = self.index;
                        self.index += 1;
                        result.loc.end = self.index;
                        return result;
                    }

                    break;
                },
                ' ', '\n', '\t', '\r' => {
                    result.loc.start = self.index + 1;
                },
                '\'' => {
                    state = .string_literal;
                    result.tag = .string;
                },
                'a'...'z',
                'A'...'Z',
                '_',
                0xc0...0xff,
                => {
                    state = .identifier;
                    result.tag = .identifier;
                },
                '0'...'9' => {
                    state = .decimal_literal;
                    result.tag = .number;
                },
                ';' => {
                    result.tag = .sym_semicolon;
                    self.index += 1;
                    break;
                },
                ',' => {
                    result.tag = .sym_comma;
                    self.index += 1;
                    break;
                },
                '^' => {
                    result.tag = .sym_ptr;
                    self.index += 1;
                    break;
                },
                '+' => {
                    result.tag = .sym_plus;
                    self.index += 1;
                    break;
                },
                '-' => {
                    result.tag = .sym_minus;
                    self.index += 1;
                    break;
                },
                '=' => {
                    result.tag = .sym_equal;
                    self.index += 1;
                    break;
                },
                ')' => {
                    result.tag = .sym_rparan;
                    self.index += 1;
                    break;
                },
                '[' => {
                    result.tag = .sym_lsqbracket;
                    self.index += 1;
                    break;
                },
                ']' => {
                    result.tag = .sym_rsqbracket;
                    self.index += 1;
                    break;
                },
                '*' => {
                    result.tag = .sym_asteriks;
                    self.index += 1;
                    break;
                },
                '@' => {
                    result.tag = .sym_at;
                    self.index += 1;
                    break;
                },
                '.' => {
                    state = .dot_seen;
                },
                ':' => {
                    state = .colon_seen;
                },
                '{' => {
                    state = .lcurly_seen;
                },
                '(' => {
                    state = .lparan_seen;
                },
                '&' => {
                    state = .amp_seen;
                },
                '/' => {
                    state = .fslash_seen;
                },
                '<' => {
                    state = .lessthan_seen;
                },
                '>' => {
                    state = .greaterthan_seen;
                },
                '#' => {
                    state = .pound_seen;
                },
                '$' => {
                    state = .hex_literal;
                    result.tag = .hex_number;
                },
                '%' => {
                    state = .binary_literal;
                    result.tag = .binary_number;
                },

                else => {
                    result.tag = .invalid;
                    break;
                },
            },
            .colon_seen => switch (c) {
                '=' => {
                    result.tag = .sym_assign;
                    self.index += 1;
                    break;
                },
                else => {
                    result.tag = .sym_colon;
                    break;
                },
            },
            .dot_seen => switch (c) {
                '.' => {
                    result.tag = .sym_range;
                    self.index += 1;
                    break;
                },
                ')' => {
                    result.tag = .sym_rsqbracket_alias;
                    self.index += 1;
                    break;
                },
                else => {
                    result.tag = .sym_dot;
                    break;
                },
            },
            .amp_seen => switch (c) {
                'a'...'z',
                'A'...'Z',
                '_',
                0xc0...0xff,
                => {
                    state = .identifier;
                    result.tag = .identifier;
                },
                '0'...'7' => {
                    state = .octal_literal;
                    result.tag = .octal_number;
                },
                '&' => {
                    result.loc.start = self.index;
                },
                else => {
                    result.tag = .invalid;
                    self.index += 1;
                    break;
                },
            },
            .fslash_seen => switch (c) {
                '/' => {
                    state = .line_comment;
                    result.tag = .line_comment;
                },
                else => {
                    result.tag = .sym_fslash;
                    self.index += 1;
                    break;
                },
            },
            .lcurly_seen => switch (c) {
                '$' => {
                    state = .compiler_directive;
                    result.tag = .compiler_directive;
                },
                '}' => {
                    result.tag = .block_comment;
                    self.index += 1;
                    break;
                },
                else => {
                    state = .curly_block_comment;
                    result.tag = .block_comment;
                },
            },
            .lparan_seen => switch (c) {
                '*' => {
                    state = .paran_block_comment;
                    result.tag = .block_comment;
                },
                '.' => {
                    result.tag = .sym_lsqbracket_alias;
                    self.index += 1;
                    break;
                },
                else => {
                    result.tag = .sym_lparan;
                    break;
                },
            },
            .lessthan_seen => switch (c) {
                '=' => {
                    result.tag = .sym_lessthanoreql;
                    self.index += 1;
                    break;
                },
                '>' => {
                    result.tag = .sym_not_eql;
                    self.index += 1;
                    break;
                },
                else => {
                    result.tag = .sym_lessthan;
                    break;
                },
            },
            .greaterthan_seen => switch (c) {
                '=' => {
                    result.tag = .sym_greaterthanoreql;
                    self.index += 1;
                    break;
                },
                else => {
                    result.tag = .sym_greaterthan;
                    break;
                },
            },
            .compiler_directive => switch (c) {
                '}' => {
                    self.index += 1;
                    break;
                },
                else => {},
            },
            .string_literal => switch (c) {
                '\'' => {
                    state = .string_tick_seen;
                },
                0, '\r', '\n' => {
                    result.tag = .invalid;
                    break;
                },
                else => {},
            },
            .binary_literal => switch (c) {
                '0', '1' => {},
                else => {
                    break;
                },
            },
            .pound_seen => switch (c) {
                '$' => {
                    state = .hex_literal;
                    result.tag = .hex_char;
                },
                '0'...'9', 'a'...'f', 'A'...'F' => {
                    state = .hex_literal;
                    result.tag = .hex_char;
                },
                else => {
                    result.tag = .invalid;
                    break;
                },
            },
            .hex_literal => switch (c) {
                '0'...'9', 'a'...'f', 'A'...'F' => {},
                else => {
                    break;
                },
            },
            .octal_literal => switch (c) {
                '0'...'7' => {},
                else => {
                    break;
                },
            },
            .decimal_literal => switch (c) {
                '0'...'9' => {},
                else => {
                    break;
                },
            },
            .string_tick_seen => switch (c) {
                '\'' => {
                    state = .string_literal;
                },
                else => {
                    break;
                },
            },
            .line_comment => switch (c) {
                '\n' => {
                    self.index += 1;
                    break;
                },
                else => {},
            },
            .curly_block_comment => switch (c) {
                '}' => {
                    self.index += 1;
                    break;
                },
                else => {},
            },
            .paran_block_comment => switch (c) {
                '*' => {
                    state = .paran_block_comment_asteriks;
                },
                else => {},
            },
            .paran_block_comment_asteriks => switch (c) {
                ')' => {
                    self.index += 1;
                    break;
                },
                '*' => {
                    state = .paran_block_comment_asteriks;
                },
                else => {
                    state = .paran_block_comment;
                },
            },
            .identifier => switch (c) {
                '0'...'9',
                'a'...'z',
                'A'...'Z',
                '_',
                0xc0...0xff,
                => {},
                0 => {
                    result.tag = .invalid;
                    self.index += 1;
                    break;
                },
                else => {
                    if (getKeyword(self.buffer[result.loc.start..self.index])) |tag| {
                        result.tag = tag;
                    }
                    if (result.tag == .keyword_asm) {
                        result.tag = .asm_code;

                        var token = self.next();
                        var end_index: usize = 0;
                        asm_block: while (true) : (token = self.next()) {
                            if (token.tag == .invalid) {
                                self.index += 1; // if the token is invalid, skip to the next char for next pass.
                            }

                            if (token.tag == .keyword_end) { // must be followed by sym_semicolon before any identifiers
                                end_index = token.loc.end;
                                var i: usize = 0;
                                end_check: while (i < 3) : (i += 1) { // just check the next 3 tokens.
                                    token = self.next();
                                    switch (token.tag) {
                                        .sym_semicolon => {
                                            break :asm_block;
                                        },
                                        .identifier => {
                                            break :end_check;
                                        },
                                        .keyword_end => {
                                            end_index = token.loc.end;
                                            i = 0; // reset loop
                                        },
                                        else => {},
                                    }
                                }
                            }
                        }
                        self.index = end_index;
                    }
                    break;
                },
            },
        }
    }

    if (result.tag == .invalid) {
        if (self.index > 16) {
            //std.debug.print("invalid token '{c}' (0x{x}) at pos{d} that followed '{s}'\n", .{ self.buffer[self.index], self.buffer[self.index], self.index, self.buffer[self.index - 16 .. self.index] });
        } else {
            // std.debug.print("invalid token '{c}' (0x{x}) at pos {d}\n", .{ self.buffer[self.index], self.buffer[self.index], self.index });
        }
    }

    result.loc.end = self.index;

    return result;
}

const keywords = kv: {
    @setEvalBranchQuota(15000);
    break :kv std.StaticStringMap(Tag).initComptime(.{
        .{ "and", .keyword_and },
        .{ "end", .keyword_end },
        .{ "interface", .keyword_interface },
        .{ "record", .keyword_record },
        .{ "var", .keyword_var },
        .{ "array", .keyword_array },
        .{ "except", .keyword_except },
        .{ "is", .keyword_is },
        .{ "repeat", .keyword_repeat },
        .{ "while", .keyword_while },
        .{ "as", .keyword_as },
        .{ "exports", .keyword_exports },
        .{ "label", .keyword_label },
        .{ "resourcestring", .keyword_resourcestring },
        .{ "with", .keyword_with },
        .{ "asm", .keyword_asm },
        .{ "file", .keyword_file },
        .{ "library", .keyword_library },
        .{ "set", .keyword_set },
        .{ "xor", .keyword_xor },
        .{ "begin", .keyword_begin },
        .{ "finalization", .keyword_finalization },
        .{ "mod", .keyword_mod },
        .{ "shl", .keyword_shl },
        .{ "case", .keyword_case },
        .{ "finally", .keyword_finally },
        .{ "nil", .keyword_nil },
        .{ "shr", .keyword_shr },
        .{ "class", .keyword_class },
        .{ "for", .keyword_for },
        .{ "not", .keyword_not },
        .{ "string", .keyword_string },
        .{ "const", .keyword_const },
        .{ "function", .keyword_function },
        .{ "object", .keyword_object },
        .{ "then", .keyword_then },
        .{ "constructor", .keyword_constructor },
        .{ "goto", .keyword_goto },
        .{ "of", .keyword_of },
        .{ "threadvar", .keyword_threadvar },
        .{ "destructor", .keyword_destructor },
        .{ "if", .keyword_if },
        .{ "or", .keyword_or },
        .{ "to", .keyword_to },
        .{ "dispinterface", .keyword_dispinterface },
        .{ "implementation", .keyword_implementation },
        .{ "packed", .keyword_packed },
        .{ "try", .keyword_try },
        .{ "div", .keyword_div },
        .{ "in", .keyword_in },
        .{ "procedure", .keyword_procedure },
        .{ "type", .keyword_type },
        .{ "do", .keyword_do },
        .{ "inherited", .keyword_inherited },
        .{ "program", .keyword_program },
        .{ "unit", .keyword_unit },
        .{ "downto", .keyword_downto },
        .{ "initialization", .keyword_initialization },
        .{ "property", .keyword_property },
        .{ "until", .keyword_until },
        .{ "else", .keyword_else },
        .{ "inline", .keyword_inline },
        .{ "raise", .keyword_raise },
        .{ "uses", .keyword_uses },

        // directives
        .{ "absolute", .directive_absolute },
        .{ "export", .directive_export },
        .{ "name", .directive_name },
        .{ "public", .directive_public },
        .{ "stdcall", .directive_stdcall },
        .{ "abstract", .directive_abstract },
        .{ "external", .directive_external },
        .{ "near", .directive_near },
        .{ "published", .directive_published },
        .{ "strict", .directive_strict },
        .{ "assembler", .directive_assembler },
        .{ "far", .directive_far },
        .{ "nodefault", .directive_nodefault },
        .{ "read", .directive_read },
        .{ "stored", .directive_stored },
        .{ "automated", .directive_automated },
        .{ "final", .directive_final },
        .{ "operator", .directive_operator },
        .{ "readonly", .directive_readonly },
        .{ "unsafe", .directive_unsafe },
        .{ "cdecl", .directive_cdecl },
        .{ "forward", .directive_forward },
        .{ "out", .directive_out },
        .{ "reference", .directive_reference },
        .{ "varargs", .directive_varargs },
        .{ "contains", .directive_contains },
        .{ "helper", .directive_helper },
        .{ "overload", .directive_overload },
        .{ "register", .directive_register },
        .{ "virtual", .directive_virtual },
        .{ "default", .directive_default },
        .{ "implements", .directive_implements },
        .{ "override", .directive_override },
        .{ "reintroduce", .directive_reintroduce },
        // .{ "winapi", .directive_winapi },
        .{ "delayed", .directive_delayed },
        .{ "index", .directive_index },
        .{ "package", .directive_package },
        .{ "requires", .directive_requires },
        .{ "write", .directive_write },
        .{ "deprecated", .directive_deprecated },
        .{ "pascal", .directive_pascal },
        .{ "resident", .directive_resident },
        .{ "writeonly", .directive_writeonly },
        .{ "dispid", .directive_dispid },
        .{ "platform", .directive_platform },
        .{ "safecall", .directive_safecall },
        .{ "dynamic", .directive_dynamic },
        .{ "local", .directive_local },
        .{ "private", .directive_private },
        .{ "sealed", .directive_sealed },
        .{ "experimental", .directive_experimental },
        .{ "message", .directive_message },
        .{ "protected", .directive_protected },
        .{ "static", .directive_static },
        //.{ "of object", .directive_of_object},
    });
};

fn getKeyword(idnt: []const u8) ?Tag {
    return keywords.get(idnt);
}

const State = enum(u16) {
    start,
    line_comment,
    curly_block_comment,
    paran_block_comment,
    paran_block_comment_asteriks,
    string_literal,
    hex_literal,
    octal_literal,
    binary_literal,
    decimal_literal,
    identifier,
    compiler_directive,

    lcurly_seen,
    lparan_seen,
    string_tick_seen,
    fslash_seen,
    colon_seen,
    amp_seen,
    dot_seen,
    lessthan_seen,
    greaterthan_seen,
    pound_seen,
};

const Tag = enum {

    // Specials
    invalid, // Special case - might ignore a lot
    eof, // Special case - when our of bytes in the buffer

    // keywords
    keyword_and,
    keyword_end,
    keyword_interface,
    keyword_record,
    keyword_var,
    keyword_array,
    keyword_except,
    keyword_is,
    keyword_repeat,
    keyword_while,
    keyword_as,
    keyword_exports,
    keyword_label,
    keyword_resourcestring,
    keyword_with,
    keyword_asm,
    keyword_file,
    keyword_library,
    keyword_set,
    keyword_xor,
    keyword_begin,
    keyword_finalization,
    keyword_mod,
    keyword_shl,
    keyword_case,
    keyword_finally,
    keyword_nil,
    keyword_shr,
    keyword_class,
    keyword_for,
    keyword_not,
    keyword_string,
    keyword_const,
    keyword_function,
    keyword_object,
    keyword_then,
    keyword_constructor,
    keyword_goto,
    keyword_of,
    keyword_threadvar,
    keyword_destructor,
    keyword_if,
    keyword_or,
    keyword_to,
    keyword_dispinterface,
    keyword_implementation,
    keyword_packed,
    keyword_try,
    keyword_div,
    keyword_in,
    keyword_procedure,
    keyword_type,
    keyword_do,
    keyword_inherited,
    keyword_program,
    keyword_unit,
    keyword_downto,
    keyword_initialization,
    keyword_property,
    keyword_until,
    keyword_else,
    keyword_inline,
    keyword_raise,
    keyword_uses,

    // directives
    directive_absolute,
    directive_export,
    directive_name,
    directive_public,
    directive_stdcall,
    directive_abstract,
    directive_external,
    directive_near,
    directive_published,
    directive_strict,
    directive_assembler,
    directive_far,
    directive_nodefault,
    directive_read,
    directive_stored,
    directive_automated,
    directive_final,
    directive_operator,
    directive_readonly,
    directive_unsafe,
    directive_cdecl,
    directive_forward,
    directive_out,
    directive_reference,
    directive_varargs,
    directive_contains,
    directive_helper,
    directive_overload,
    directive_register,
    directive_virtual,
    directive_default,
    directive_implements,
    directive_override,
    directive_reintroduce,
    // directive_winapi,
    directive_delayed,
    directive_index,
    directive_package,
    directive_requires,
    directive_write,
    directive_deprecated,
    directive_pascal,
    directive_resident,
    directive_writeonly,
    directive_dispid,
    directive_library,
    directive_platform,
    directive_safecall,
    directive_dynamic,
    directive_local,
    directive_private,
    directive_sealed,
    directive_experimental,
    directive_message,
    directive_protected,
    directive_static,
    directive_of_object,

    // Compiler directive
    comp_directive_start, // {$
    comp_directive_end, // }

    // symbols
    // Note: %, ?, \, !, " (double quotation marks), _ (underscore), | (pipe), and ~ (tilde) are not special symbols.
    sym_pound, // #
    sym_dollar, // $
    sym_and, // &
    sym_tick, // '
    sym_lparan, // (
    sym_rparan, // )
    sym_asteriks, // *
    sym_plus, // +
    sym_comma, // ,
    sym_minus, // -
    sym_dot, // .
    sym_fslash, // /
    sym_colon, // :
    sym_semicolon, // ;
    sym_lessthan, // <
    sym_equal, // =
    sym_greaterthan, // >
    sym_at, // @
    sym_lsqbracket, // [
    sym_rsqbracket, // ]
    sym_ptr, // ^
    sym_lcurlybracket, // {
    sym_rcurlybracket, // }

    sym_block_cmnt_start, // (*
    sym_lsqbracket_alias, // (.
    sym_block_cmnt_end, // *)
    sym_rsqbracket_alias, // .)
    sym_range, // ..
    sym_comment, // //
    sym_assign, // :=
    sym_lessthanoreql, // <=
    sym_greaterthanoreql, // >=
    sym_not_eql, // <>

    // constructs
    string,
    number,
    hex_char,
    binary_number,
    hex_number,
    octal_number,
    identifier,
    block_comment,
    line_comment,
    compiler_directive,
    asm_code,
};

const assert = std.testing;
test "tokenize general" {
    const src =
        \\const 
        \\  &&as: String[5] = #$09 + '1234';
        \\
        \\asm
        \\ adf smdf ( sdf[]) // end hahaha no(* .)sfd
        \\end;
        \\
        \\ {} // empty block and line comment
        \\ 
        ++
        "\x1a";

    var tokenizer = Tokenizer.tokenize(src);

    const @"const" = tokenizer.next();
    try assert.expectEqual(Tag.keyword_const, @"const".tag);
    try assert.expectEqual(0, @"const".loc.start);
    try assert.expectEqual(5, @"const".loc.end);

    const @"&as" = tokenizer.next();
    try assert.expectEqual(Tag.identifier, @"&as".tag);
    try assert.expectEqual(10, @"&as".loc.start);
    try assert.expectEqual(13, @"&as".loc.end);

    const colon = tokenizer.next();
    try assert.expectEqual(Tag.sym_colon, colon.tag);
    try assert.expectEqual(13, colon.loc.start);
    try assert.expectEqual(14, colon.loc.end);

    var i: usize = 0;
    while (i < 9) : (i += 1) {
        _ = tokenizer.next();
        //std.debug.print("'{s}' is tag .{s} found at {d: >4} to {d: >4}\n", .{ src[t.loc.start..t.loc.end], @tagName(t.tag), t.loc.start, t.loc.end });
    }

    const @"asm" = tokenizer.next();
    try assert.expectEqual(Tag.asm_code, @"asm".tag);
    try assert.expectEqual(43, @"asm".loc.start);
    try assert.expectEqual(94, @"asm".loc.end);

    const semicolon = tokenizer.next();
    try assert.expectEqual(Tag.sym_semicolon, semicolon.tag);
    try assert.expectEqual(94, semicolon.loc.start);
    try assert.expectEqual(95, semicolon.loc.end);

    const blk_cmnt = tokenizer.next();
    try assert.expectEqual(Tag.block_comment, blk_cmnt.tag);
    try assert.expectEqual(98, blk_cmnt.loc.start);
    try assert.expectEqual(100, blk_cmnt.loc.end);

    const line_cmnt = tokenizer.next();
    try assert.expectEqual(Tag.line_comment, line_cmnt.tag);
    try assert.expectEqual(101, line_cmnt.loc.start);
    try assert.expectEqual(133, line_cmnt.loc.end);

    const sub = tokenizer.next();
    try assert.expectEqual(Tag.eof, sub.tag);
    try assert.expectEqual(134, sub.loc.start);
    try assert.expectEqual(134, sub.loc.end);
}
