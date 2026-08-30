//! `fud` is an Elm inspired Model, View, Update (MVU) application library
//! that aims to simplify creating applications.

const app = @import("app.zig");
const cmd = @import("cmd.zig");
const view = @import("view.zig");
const runtime = @import("runtime.zig");

pub const Cmd = cmd.Cmd;
pub const View = view.View;
pub const run = runtime.run;

test {
    _ = cmd;
    _ = app;
    _ = view;
}
