//! `fud` is an Elm inspired Model, View, Update (MVU) application library
//! that aims to simplify creating applications.

const app = @import("app.zig");
const cmd = @import("cmd.zig");
const config = @import("config.zig");
const runtime = @import("runtime.zig");
const view = @import("view.zig");

pub const Cmd = cmd.Cmd;
pub const View = view.View;
pub const run = runtime.run;
pub const Config = config.Config;

test {
    _ = app;
    _ = cmd;
    _ = config;
    _ = runtime;
    _ = view;
}
