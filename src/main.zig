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
};

pub fn main() !void {
    try fud.run(App);
}
