//! Compile-time validation for `fud` application types.
//!
//! This module defines the contract that an application must satisfy to be
//! used with `fud.run`. It validates the application's Model, Msg, and MVU
//! lifecycle functions at compile time and produces clear, actionable
//! diagnostics when the contract is violated.
//!
//! Application types are defined by the library user. `fud` does not impose
//! concrete Model or Msg types; instead, the application provides its own
//! types and functions according to the `fud` application contract.
//!
//! This module is an implementation detail of `fud` and should not need to be
//! imported directly by applications.

const std = @import("std");
const cmd = @import("cmd.zig");
const view_module = @import("view.zig");

/// Validates a user-defined application type at comptime.
///
/// `App` defines the types and functions that make up a `fud` application.
/// This function verifies that `App` satisfies the application contract
/// required by the `fud` runtime.
///
/// Validation is performed at compile time so that invalid application
/// definitions are detected before the application can run. When the
/// application violates the contract, validation should produce a clear,
/// actionable diagnostic describing what is missing or incorrect rather
/// than relying on an incidental Zig compiler error.
///
/// The application contract consists of:
///
/// - `Model`: The application's state type.
/// - `Msg`: The application's message type.
/// - `init`: Creates the initial `Model`.
/// - `update`: Processes a `Msg`, mutates the `Model`, and returns a
///   `fud.Cmd(Msg)`.
/// - `view`: Declaratively describes the UI from a read-only `Model`.
///
/// Validation should be performed in a predictable order, reporting the
/// first invalid requirement encountered.
pub fn validate(comptime App: type) void {
    validateModel(App);
    validateMsg(App);
    validateInit(App);
    validateUpdate(App);
    validateView(App);
}

/// `validateModel` verifies that the user-defined `App` type contains
/// the required `Model` declaration.
fn validateModel(comptime App: type) void {
    const has_model = @hasDecl(App, "Model");
    if (!has_model) {
        @compileError(
            \\Fud application contract violation:
            \\
            \\The application is missing the required `Model` declaration.
            \\
            \\`Model` represents the application's state. It is passed to `view`
            \\to describe the current UI and to `update` to be modified in response
            \\to messages.
            \\
            \\`Model` may be any Zig type.
            \\
            \\For example, a struct:
            \\
            \\    pub const Model = struct {
            \\        count: i32,
            \\    };
            \\
            \\Or a union(enum):
            \\
            \\    pub const Model = union(enum) {
            \\        loading,
            \\        ready,
            \\        failed,
            \\    };
            \\
            \\Define `Model` inside your application type and try again.
        );
    }
}

test "validateModel accepts an App with a Model declaration" {
    const AnyRandomAppName = struct {
        pub const Model = struct {
            count: i32,
        };
    };

    validateModel(AnyRandomAppName);
}

/// `validateMsg` verifies that the user-defined `App` type contains
/// the required `Msg` declaration. `Msg` must be a tagged union because
/// this provides a consistent way to represent messages with or without
/// associated data.
fn validateMsg(comptime App: type) void {
    const missing_msg_error =
        \\Fud application contract violation:
        \\
        \\The application is missing the required `Msg` declaration.
        \\
        \\`Msg` represents events that can cause application state to change.
        \\Each message is handled by your application's `update` function.
        \\
        \\Messages are defined as a tagged union so they can optionally carry data.
        \\
        \\Example:
        \\
        \\    pub const Msg = union(enum) {
        \\        increment,
        \\        decrement,
        \\        set_count: i32,
        \\    };
        \\
        \\Define `Msg` inside your application type and try again.
    ;

    const not_a_tagged_union_error =
        \\Fud application contract violation:
        \\
        \\`Msg` must be a tagged union.
        \\
        \\Messages represent events that can cause application state to change.
        \\Each message is handled by your application's `update` function.
        \\
        \\A tagged union allows messages to optionally carry data.
        \\
        \\Example:
        \\
        \\    pub const Msg = union(enum) {
        \\        increment,
        \\        decrement,
        \\        set_count: i32,
        \\    };
    ;

    const has_msg = @hasDecl(App, "Msg");
    if (!has_msg) {
        @compileError(missing_msg_error);
    }

    const type_info = @typeInfo(App.Msg);
    switch (type_info) {
        .@"union" => |union_info| {
            if (union_info.tag_type == null) {
                @compileError(not_a_tagged_union_error);
            }
        },
        else => {
            @compileError(not_a_tagged_union_error);
        },
    }
}

test "validateMsg accepts an App with a Msg declaration" {
    const AnyRandomAppName = struct {
        pub const Msg = union(enum) {
            increment,
            decrement,
            set: i32,
        };
    };

    validateMsg(AnyRandomAppName);
}

/// `validateInit` ensures that the user-provided `App` type contains
/// a proper `init` function definition that accepts no arguments and returns
/// an `App.Model`.
fn validateInit(comptime App: type) void {
    const missing_init_error =
        \\Fud application contract violation:
        \\
        \\The application is missing the required `init` function.
        \\
        \\`init` creates the application's initial `Model` before the
        \\application begins processing messages.
        \\
        \\Example:
        \\
        \\    pub fn init() Model {
        \\        return .{
        \\            .count = 0,
        \\        };
        \\    }
        \\
        \\Define `init` inside your application type and try again.
    ;

    const incorrect_init_signature_error =
        \\Fud application contract violation:
        \\
        \\The application's `init` function has an incorrect signature.
        \\
        \\`init` must take no arguments and return an instance of `Model`.
        \\
        \\Expected:
        \\
        \\    pub fn init() Model {
        \\        return .{
        \\            .count = 0,
        \\        };
        \\    }
        \\
        \\The return type must be the application's `Model` type.
    ;

    const init_not_function_error =
        \\Fud application contract violation:
        \\
        \\The application's `init` declaration must be a function.
        \\
        \\`init` creates the application's initial `Model` before the
        \\application begins processing messages.
        \\
        \\Example:
        \\
        \\    pub fn init() Model {
        \\        return .{
        \\            .count = 0,
        \\        };
        \\    }
        \\
        \\Define `init` as a function that takes no arguments and returns
        \\an instance of the application's `Model` type.
    ;

    const init_exists = @hasDecl(App, "init");
    if (!init_exists) {
        @compileError(missing_init_error);
    }

    const type_info = @typeInfo(@TypeOf(App.init));
    switch (type_info) {
        .@"fn" => |fn_info| {
            if (fn_info.params.len > 0) {
                @compileError(incorrect_init_signature_error);
            }

            const return_type = fn_info.return_type orelse {
                @compileError(incorrect_init_signature_error);
            };

            if (return_type != App.Model) {
                @compileError(incorrect_init_signature_error);
            }
        },
        else => {
            @compileError(init_not_function_error);
        },
    }
}

test "validateInit accepts an App with a proper init declaration" {
    const App = struct {
        const Model = struct {};
        pub fn init() Model {
            return Model{};
        }
    };

    validateInit(App);
}

/// `validateUpdate` verifies that the user-defined `App` type contains
/// a valid `update` function definition.
///
/// `update` is the core transition function of the MVU architecture. It
/// receives the current application `Model` and a `Msg`, applies the
/// appropriate state transition, and returns a `Cmd(Msg)` describing any
/// asynchronous work that should be performed by the `fud` runtime.
///
/// The required signature is:
///
///     pub fn update(model: *Model, msg: Msg) fud.Cmd(Msg)
///
/// The first parameter must be a mutable pointer to `App.Model`, allowing
/// `update` to modify application state. The second parameter must be the
/// application's `App.Msg` type. The return type must be `fud.Cmd(App.Msg)`.
///
/// Validation is performed at comptime so that an invalid `update`
/// definition produces a clear diagnostic before the application can run.
fn validateUpdate(comptime App: type) void {
    const missing_update_error =
        \\Fud application contract violation:
        \\
        \\The application is missing the required `update` function.
        \\
        \\`update` processes messages and mutates the application's `Model`.
        \\It is called by the `fud` runtime whenever a message is received.
        \\
        \\Example:
        \\
        \\    pub fn update(model: *Model, msg: Msg) fud.Cmd(Msg) {
        \\        switch (msg) {
        \\            .increment => model.count += 1,
        \\            .decrement => model.count -= 1,
        \\        }
        \\
        \\        return .none;
        \\    }
        \\
        \\Define `update` inside your application type and try again.
    ;

    const update_not_function_error =
        \\Fud application contract violation:
        \\
        \\The application's `update` declaration must be a function.
        \\
        \\`update` processes messages and mutates the application's `Model`.
        \\It must accept a mutable pointer to `Model` and a `Msg`, then return
        \\a `fud.Cmd(Msg)`.
        \\
        \\Example:
        \\
        \\    pub fn update(model: *Model, msg: Msg) fud.Cmd(Msg) {
        \\        switch (msg) {
        \\            .increment => model.count += 1,
        \\            .decrement => model.count -= 1,
        \\        }
        \\
        \\        return .none;
        \\    }
        \\
        \\Define `update` as a function with the required signature.
    ;

    const update_incorrect_parameter_count_error =
        \\Fud application contract violation:
        \\
        \\The application's `update` function has an incorrect number of parameters.
        \\
        \\`update` must accept exactly two parameters:
        \\
        \\    1. `*Model` — a mutable pointer to the application's state.
        \\    2. `Msg` — the message being processed.
        \\
        \\Expected:
        \\
        \\    pub fn update(model: *Model, msg: Msg) fud.Cmd(Msg) {
        \\        // ...
        \\    }
        \\
        \\Define `update` with exactly two parameters and try again.
    ;

    const update_incorrect_model_parameter_error =
        \\Fud application contract violation:
        \\
        \\The first parameter of `update` has an incorrect type.
        \\
        \\The first parameter must be a mutable pointer to the application's
        \\`Model` type.
        \\
        \\Expected:
        \\
        \\    pub fn update(model: *Model, msg: Msg) fud.Cmd(Msg) {
        \\        // ...
        \\    }
        \\
        \\The `*Model` parameter allows `update` to modify application state
        \\in response to a message.
    ;

    const update_incorrect_msg_parameter_error =
        \\Fud application contract violation:
        \\
        \\The second parameter of `update` has an incorrect type.
        \\
        \\The second parameter must be the application's `Msg` type.
        \\
        \\Expected:
        \\
        \\    pub fn update(model: *Model, msg: Msg) fud.Cmd(Msg) {
        \\        // ...
        \\    }
        \\
        \\The `Msg` parameter represents the message currently being processed
        \\by the application.
    ;

    const update_incorrect_return_type_error =
        \\Fud application contract violation:
        \\
        \\The application's `update` function has an incorrect return type.
        \\
        \\`update` must return `fud.Cmd(Msg)`.
        \\
        \\`Cmd(Msg)` represents work that `fud` may perform after the current
        \\message has been processed and may eventually produce another `Msg`.
        \\
        \\Expected:
        \\
        \\    pub fn update(model: *Model, msg: Msg) fud.Cmd(Msg) {
        \\        // ...
        \\    }
        \\
        \\Return a `fud.Cmd(Msg)` from `update` and try again.
    ;

    const has_update = @hasDecl(App, "update");
    if (!has_update) {
        @compileError(missing_update_error);
    }

    const type_info = @typeInfo(@TypeOf(App.update));
    switch (type_info) {
        .@"fn" => |fn_info| {
            if (fn_info.params.len != 2) {
                @compileError(update_incorrect_parameter_count_error);
            }

            const model_type = fn_info.params[0].type orelse {
                @compileError(update_incorrect_parameter_count_error);
            };

            const msg_type = fn_info.params[1].type orelse {
                @compileError(update_incorrect_parameter_count_error);
            };

            switch (@typeInfo(model_type)) {
                .pointer => |ptr_info| {
                    if (ptr_info.is_const) {
                        @compileError(update_incorrect_model_parameter_error);
                    }

                    if (ptr_info.child != App.Model) {
                        @compileError(update_incorrect_model_parameter_error);
                    }
                },
                else => {
                    @compileError(update_incorrect_model_parameter_error);
                },
            }

            if (msg_type != App.Msg) {
                @compileError(update_incorrect_msg_parameter_error);
            }

            const return_type = fn_info.return_type orelse {
                @compileError(update_incorrect_return_type_error);
            };

            if (return_type != cmd.Cmd(App.Msg)) {
                @compileError(update_incorrect_return_type_error);
            }
        },
        else => {
            @compileError(update_not_function_error);
        },
    }
}

test "validateUpdate accepts an App with a valid update declaration" {
    const App = struct {
        const Model = struct {};
        const Msg = union(enum) {};

        pub fn update(model: *Model, message: Msg) cmd.Cmd(Msg) {
            _ = model;
            _ = message;
            return .none;
        }
    };

    validateUpdate(App);
}

/// `validateView` verifies that the user-defined `App` type contains
/// a valid `view` function definition.
///
/// `view` describes the application's user interface based on its current
/// `Model`. It receives a read-only pointer to the application's state and
/// returns a `View(Msg)` describing the UI.
///
/// The required signature is:
///
///     pub fn view(model: *const Model) fud.View(Msg)
///
/// The parameter must be a `*const App.Model` so that `view` can observe
/// application state without modifying it. The return type must be
/// `fud.View(App.Msg)`.
///
/// Validation is performed at comptime so that an invalid `view` definition
/// produces a clear diagnostic before the application can run.
fn validateView(comptime App: type) void {
    const missing_view_error =
        \\Fud application contract violation:
        \\
        \\The application is missing the required `view` function.
        \\
        \\`view` describes the application's user interface based on its current
        \\`Model`. The `fud` runtime uses the resulting view to construct and
        \\update the application's UI.
        \\
        \\Example:
        \\
        \\    pub fn view(model: *const Model) fud.View(Msg) {
        \\        _ = model;
        \\
        \\        // Describe the application's UI here.
        \\        return .{};
        \\    }
        \\
        \\Define `view` inside your application type and try again.
    ;

    const view_not_function_error =
        \\Fud application contract violation:
        \\
        \\The application's `view` declaration must be a function.
        \\
        \\`view` describes the application's user interface from its current
        \\`Model` and must return a `fud.View(Msg)`.
        \\
        \\Example:
        \\
        \\    pub fn view(model: *const Model) fud.View(Msg) {
        \\        _ = model;
        \\
        \\        // Describe the application's UI here.
        \\        return .{};
        \\    }
        \\
        \\Define `view` as a function with the required signature.
    ;

    const view_incorrect_parameter_count_error =
        \\Fud application contract violation:
        \\
        \\The application's `view` function has an incorrect number of parameters.
        \\
        \\`view` must accept exactly one parameter:
        \\
        \\    1. `*const Model` — a read-only pointer to the application's state.
        \\
        \\Expected:
        \\
        \\    pub fn view(model: *const Model) fud.View(Msg) {
        \\        // ...
        \\    }
        \\
        \\Define `view` with exactly one parameter and try again.
    ;

    const view_incorrect_model_parameter_error =
        \\Fud application contract violation:
        \\
        \\The parameter of `view` has an incorrect type.
        \\
        \\The parameter must be a read-only pointer to the application's `Model`
        \\type.
        \\
        \\Expected:
        \\
        \\    pub fn view(model: *const Model) fud.View(Msg) {
        \\        // ...
        \\    }
        \\
        \\`view` receives a read-only `*const Model` because it describes the UI
        \\from application state without modifying that state.
    ;

    const view_incorrect_return_type_error =
        \\Fud application contract violation:
        \\
        \\The application's `view` function has an incorrect return type.
        \\
        \\`view` must return `fud.View(Msg)`.
        \\
        \\`View(Msg)` represents the declarative description of the application's
        \\user interface and allows user interactions to produce application
        \\messages.
        \\
        \\Expected:
        \\
        \\    pub fn view(model: *const Model) fud.View(Msg) {
        \\        // ...
        \\    }
        \\
        \\Return a `fud.View(Msg)` from `view` and try again.
    ;

    const has_view = @hasDecl(App, "view");
    if (!has_view) {
        @compileError(missing_view_error);
    }

    const type_info = @typeInfo(@TypeOf(App.view));
    switch (type_info) {
        .@"fn" => |fn_info| {
            if (fn_info.params.len != 1) {
                @compileError(view_incorrect_parameter_count_error);
            }

            const model_type = fn_info.params[0].type orelse {
                @compileError(view_incorrect_model_parameter_error);
            };

            switch (@typeInfo(model_type)) {
                .pointer => |ptr_info| {
                    // Must be const so that the model is read-only.
                    if (!ptr_info.is_const) {
                        @compileError(view_incorrect_model_parameter_error);
                    }

                    if (ptr_info.child != App.Model) {
                        @compileError(view_incorrect_model_parameter_error);
                    }
                },
                else => {
                    @compileError(view_incorrect_model_parameter_error);
                },
            }

            const return_type = fn_info.return_type orelse {
                @compileError(view_incorrect_return_type_error);
            };

            if (return_type != view_module.View(App.Msg)) {
                @compileError(view_incorrect_return_type_error);
            }
        },
        else => {
            @compileError(view_not_function_error);
        },
    }
}

test "validateView accepts an App with a valid view declaration" {
    const App = struct {
        pub const Model = struct {};
        pub const Msg = union(enum) {};
        pub fn view(model: *const Model) view_module.View(Msg) {
            _ = model;
            return .{ .text = "Hello, world!" };
        }
    };

    validateView(App);
}
