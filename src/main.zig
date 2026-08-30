const std = @import("std");
const fud = @import("fud");

const App = struct {
    pub const Model = struct {
        count: i32,
    };

    pub const Msg = union(enum) {
        increment,
        decrement,
        set_count: i32,
    };

    pub fn init(allocator: std.mem.Allocator) Model {
        _ = allocator;
        return Model{ .count = 42 };
    }

    pub fn deinit(model: *Model, allocator: std.mem.Allocator) void {
        _ = model;
        _ = allocator;
    }

    pub fn update(model: *Model, message: Msg, allocator: std.mem.Allocator) fud.Cmd(Msg) {
        _ = model;
        _ = message;
        _ = allocator;
        const cmd = fud.Cmd(Msg){};
        return cmd;
    }

    pub fn view(model: *const Model, allocator: std.mem.Allocator) fud.View(Msg) {
        const text = std.fmt.allocPrintSentinel(
            allocator,
            "Count: {d}",
            .{model.count},
            0,
        ) catch unreachable;

        return .{ .text = text };
    }

    pub const config = fud.Config{
        .title = "Hello, Config!",
        .width = 1200,
        .height = 600,
    };
};

pub fn main() !void {
    try fud.run(App);
}
