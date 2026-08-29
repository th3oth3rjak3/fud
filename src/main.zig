const std = @import("std");
const fud = @import("fud");

pub fn main() void {
    std.debug.print("{s}", .{fud.getHelloMessage()});
}
