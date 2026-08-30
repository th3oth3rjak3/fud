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

    pub fn init() Model {
        return Model{ .count = 0 };
    }

    pub fn update(model: *Model, message: Msg) fud.Cmd(Msg) {
        _ = model;
        _ = message;
        const cmd = fud.Cmd(Msg){};
        return cmd;
    }
};

pub fn main() !void {
    try fud.run(App);
}
