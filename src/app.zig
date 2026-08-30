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
/// - `onError`: An optional handler for errors produced by the `fud` runtime.
///
/// Validation should be performed in a predictable order, reporting the
/// first invalid requirement encountered.
pub fn validate(comptime App: type) void {
    validateModel(App);
    validateMsg(App);
    validateInit(App);

    // Verify App.update exists.
    //
    // If it does not:
    //   - Produce a diagnostic explaining that update processes messages
    //     and mutates application state.
    //
    // If it exists:
    //   - Verify that it is a function.
    //   - Verify that its first parameter is App.Msg.
    //   - Verify that its second parameter is *App.Model.
    //   - Verify that it returns fud.Cmd(App.Msg).
    //   - Report the expected and actual signatures when invalid.

    // Verify App.view exists.
    //
    // If it does not:
    //   - Produce a diagnostic explaining that view describes the UI.
    //
    // If it exists:
    //   - Verify that it is a function.
    //   - Verify that its parameter is *const App.Model.
    //   - Verify that it returns fud.View(App.Msg).
    //   - Report the expected and actual signatures when invalid.

    // Verify App.onError if it exists.
    //
    // If it exists:
    //   - Verify that it is a function.
    //   - Verify that it conforms to the Fud runtime error handler contract.
    //   - Report the expected and actual signatures when invalid.
    //
    // If it does not exist:
    //   - This is valid; onError is optional.
}

/// `validateModel` verifies that the user-defined `App` type contains
/// the required `Model` declaration.
fn validateModel(comptime App: type) void {
    const has_model = @hasDecl(App, "Model");
    if (has_model) {
        return;
    }

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

test "validateModel accepts an App with a Model declaration" {
    const AnyRandomAppName = struct {
        pub const Model = struct {
            count: i32,
        };
    };

    validateModel(AnyRandomAppName);
}

// Should produce a compilation error when uncommented, missing the Model declaration.
// test "validateModel rejects an App without a Model declaration" {
//     const App = struct {};

//     validateModel(App);
// }

/// `validateMsg` verifies that the user-defined `App` type contains
/// the required `Msg` declaration. It must be a tagged union type
/// because it simplifies the user experience for all but the most
/// trivial cases.
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

// Fails to compile because it's missing a Msg declaration.
// test "validateMsg fails to compile, missing Msg declaration" {
//     const App = struct {};
//     validateMsg(App);
// }

// Fails to compile because Msg is a union.
// test "validateMsg fails to compile, Msg declaration is union" {
//     const App = struct {
//         pub const Msg = union {
//             increment: bool,
//             decrement: bool,
//         };
//     };

//     validateMsg(App);
// }

// Fails to compile because Msg is an enum.
// test "validateMsg fails to compile, Msg declaration is enum" {
//     const App = struct {
//         pub const Msg = enum {
//             increment,
//             decrement,
//         };
//     };

//     validateMsg(App);
// }

// Fails to compile because Msg is a struct.
// test "validateMsg fails to compile, Msg declaration is enum" {
//     const App = struct {
//         pub const Msg = struct {};
//     };

//     validateMsg(App);
// }

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

/// `validateInit` ensures that the user provided `App` type contains
/// a proper `init` function definition that accepts no arguments and returns
/// an `App.Model`
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

// Fails to compile because it returns void.
// test "validateInit fails because it returns void" {
//     const App = struct {
//         const Model = struct {};
//         pub fn init() void {}
//     };

//     validateInit(App);
// }

// Fails to compile because it takes arguments.
// test "validateInit fails because it takes arguments" {
//     const App = struct {
//         const Model = struct {};
//         pub fn init(thing: i32) Model {
//             _ = thing;
//             return Model{};
//         }
//     };

//     validateInit(App);
// }

// Fails to compile because init is missing.
// test "validateInit fails because init is missing" {
//     const App = struct {
//         const Model = struct {};
//     };

//     validateInit(App);
// }

// Fails to compile because init is not a function.
// test "validateInit fails because init is not a function" {
//     const App = struct {
//         const Model = struct {};
//         const init = 2;
//     };

//     validateInit(App);
// }
