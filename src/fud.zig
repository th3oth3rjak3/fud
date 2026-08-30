//! `fud` is an Elm inspired Model, View, Update (MVU) application library
//! that aims to simplify creating applications.

const app = @import("app.zig");
const cmd = @import("cmd.zig");
const view = @import("view.zig");

pub const Cmd = cmd.Cmd;
pub const View = view.View;

/// Starts a `fud` application.
///
/// `App` is the application type that defines the application's model,
/// messages, and MVU lifecycle functions. `fud` uses `App` at compile time
/// to validate that it conforms to the required application contract.
///
/// The application type must provide:
///
/// 1. A `Model` type representing the application's state.
///
/// 2. A `Msg` type representing messages that can be sent to the application.
///    This is typically a `union(enum)`.
///
/// 3. An `init` function that creates the initial application model.
///
///    ```zig
///    pub fn init() Model {
///        return .{ .count = 0 };
///    }
///    ```
///
/// 4. An `update` function that handles messages and mutates the application
///    model.
///
///    ```zig
///    pub fn update(msg: Msg, model: *Model) fud.Cmd(Msg) {
///        switch (msg) {
///            .increment => model.count += 1,
///        }
///
///        return .none;
///    }
///    ```
///
/// 5. A `view` function that declaratively describes the user interface.
///    The model is provided as a const pointer so the view cannot mutate
///    application state.
///
///    ```zig
///    pub fn view(model: *const Model) fud.View(Msg) {
///        return fud.text(model.count);
///    }
///    ```
///
/// An optional `onError` function may be provided to handle errors originating
/// from the `fud` runtime.
///
/// Application errors are the responsibility of the application and should
/// be represented as application-defined messages when they need to
/// participate in the MVU message loop.
pub fn run(comptime App: type) !void {
    app.validate(App);

    // TODO: the rest of the app/mvu lifecycle logic
}

test {
    _ = cmd;
    _ = app;
    _ = view;
}
