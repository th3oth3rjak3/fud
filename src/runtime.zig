//! Application runtime for `fud`.
//!
//! This module contains the runtime responsible for executing a validated
//! `fud` application. It owns the application lifecycle, including
//! initialization, the main event loop, and rendering.
//!
//! The runtime is intentionally kept separate from the application contract.
//! `app.zig` defines and validates what an application must provide, while
//! this module is responsible for executing those definitions.

const rl = @import("raylib");
const app = @import("app.zig");
const view_module = @import("view.zig");

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
///    pub fn update(model: *Model, msg: Msg) fud.Cmd(Msg) {
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
///        _ = model;
///        return .{ .text = "hello, world!" };
///    }
///    ```
///
/// WARNING: This `onError` behavior is not yet implemented.
///
/// An optional `onError` function may be provided to handle errors originating
/// from the `fud` runtime.
///
/// Application errors are the responsibility of the application and should
/// be represented as application-defined messages when they need to
/// participate in the MVU message loop.
pub fn run(comptime App: type) !void {
    app.validate(App);

    var model: App.Model = App.init();

    rl.initWindow(800, 600, "Hello Fud!");
    defer rl.closeWindow();

    while (!rl.windowShouldClose()) {
        const view: view_module.View(App.Msg) = App.view(&model);

        rl.beginDrawing();
        defer rl.endDrawing();

        renderView(App, view);
    }
}

fn renderView(comptime App: type, view: view_module.View(App.Msg)) void {
    switch (view) {
        .text => |text| {
            rl.drawText(text, 20, 20, 24, rl.Color.white);
        },
    }
}
