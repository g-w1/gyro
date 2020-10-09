const std = @import("std");
const clap = @import("clap");
usingnamespace @import("commands.zig");

const Command = enum {
    fetch,
    search,
    tags,
    add,
    remove,
    init,
};

const stderr = std.io.getStdErr().writer();

fn print_usage() noreturn {
    _ = stderr.write(
        \\zkg <cmd> [cmd specific options]
        \\
        \\cmds:
        \\  init    Initialize an imports file
        \\  search  List packages matching your query
        \\  tags    List tags found in your remote
        \\  add     Add a package to your imports file
        \\  remove  Remove a package from your imports file
        \\  fetch   Download packages specified in your imports file into your
        \\          cache dir
        \\
        \\for more information: zkg <cmd> --help
        \\
        \\
    ) catch {};

    std.os.exit(1);
}

fn check_help(comptime summary: []const u8, comptime params: anytype, args: anytype) void {
    if (args.flag("--help")) {
        _ = stderr.write(summary ++ "\n\n") catch {};
        clap.help(stderr, params) catch {};
        _ = stderr.write("\n") catch {};
        std.os.exit(0);
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    var iter = try clap.args.OsIterator.init(allocator);
    defer iter.deinit();

    const cmd_str = (try iter.next()) orelse {
        try stderr.print("no command given\n", .{});
        print_usage();
    };

    const cmd = inline for (std.meta.fields(Command)) |field| {
        if (std.mem.eql(u8, cmd_str, field.name)) {
            break @field(Command, field.name);
        }
    } else {
        try stderr.print("{} is not a valid command\n", .{cmd_str});
        print_usage();
    };

    @setEvalBranchQuota(5000);
    switch (cmd) {
        .fetch => {
            const summary = "Download packages specified in your imports file into your cache dir";
            const params = comptime [_]clap.Param(clap.Help){
                clap.parseParam("-h, --help             Display help") catch unreachable,
                clap.parseParam("-c, --cache-dir <DIR>  cache directory, default is zig-cache") catch unreachable,
            };

            var args = try clap.ComptimeClap(clap.Help, &params).parse(allocator, clap.args.OsIterator, &iter);
            check_help(summary, &params, args);

            try fetch(args.option("--cache-dir"));
        },
        .init => {
            const summary = "Initialize an imports file";
            const params = comptime [_]clap.Param(clap.Help){
                clap.parseParam("-h, --help             Display help") catch unreachable,
            };

            var args = try clap.ComptimeClap(clap.Help, &params).parse(allocator, clap.args.OsIterator, &iter);
            defer args.deinit();

            check_help(summary, &params, args);
            try init();
        },
        .search => {
            const summary = "Lists packages matching your query";
            const params = comptime [_]clap.Param(clap.Help){
                clap.parseParam("-h, --help             Display help") catch unreachable,
                clap.parseParam("-r, --remote <REMOTE>  Select which endpoint to query") catch unreachable,
                clap.parseParam("-t, --tag <TAG>        Filter results for specific tag") catch unreachable,
                clap.parseParam("-n, --name <NAME>      Query specific package") catch unreachable,
                clap.parseParam("-j, --json             Print raw JSON") catch unreachable,
            };

            var args = try clap.ComptimeClap(clap.Help, &params).parse(allocator, clap.args.OsIterator, &iter);
            defer args.deinit();

            check_help(summary, &params, args);

            try search(
                allocator,
                args.option("--name"),
                args.option("--tag"),
                args.flag("--json"),
                args.option("--remote"),
            );
        },
        .tags => {
            const summary = "List tags found in your remote";
            const params = comptime [_]clap.Param(clap.Help){
                clap.parseParam("-h, --help             Display help") catch unreachable,
                clap.parseParam("-r, --remote <REMOTE>  Select which endpoint to query") catch unreachable,
            };

            var args = try clap.ComptimeClap(clap.Help, &params).parse(allocator, clap.args.OsIterator, &iter);
            defer args.deinit();

            check_help(summary, &params, args);

            try tags(allocator, args.option("--remote"));
        },
        .add => {
            const summary = "Add a package to your imports file";
            const params = comptime [_]clap.Param(clap.Help){
                clap.parseParam("-h, --help             Display help") catch unreachable,
                clap.parseParam("-r, --remote <REMOTE>  Select which endpoint to query") catch unreachable,
                clap.parseParam("-a, --alias <ALIAS>    Set the @import name of the package") catch unreachable,
                clap.Param(clap.Help){
                    .takes_value = .One,
                },
            };

            var args = try clap.ComptimeClap(clap.Help, &params).parse(allocator, clap.args.OsIterator, &iter);
            defer args.deinit();

            check_help(summary, &params, args);

            // there can only be one positional argument
            if (args.positionals().len > 1) {
                return error.TooManyPositionalArgs;
            } else if (args.positionals().len != 1) {
                return error.MissingName;
            }

            try add(allocator, args.positionals()[0], args.option("--alias"), args.option("--remote"));
        },
        .remove => {
            const summary = "Remove a package from your imports file";
            const params = comptime [_]clap.Param(clap.Help){
                clap.parseParam("-h, --help             Display help") catch unreachable,
                clap.Param(clap.Help){
                    .takes_value = .One,
                },
            };

            var args = try clap.ComptimeClap(clap.Help, &params).parse(allocator, clap.args.OsIterator, &iter);
            defer args.deinit();

            check_help(summary, &params, args);

            // there can only be one positional argument
            if (args.positionals().len > 1) {
                return error.TooManyPositionalArgs;
            } else if (args.positionals().len != 1) {
                return error.MissingName;
            }

            try remove(args.positionals()[0]);
        },
    }
}
