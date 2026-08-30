//! Commands produced by `fud` applications.
//!
//! This module defines `Cmd`, the type returned by an application's `update`
//! function. A command represents work that `fud` may perform outside of the
//! synchronous model update and that may eventually produce a message for the
//! application to process.
//!
//! `Cmd` is parameterized by the application's `Msg` type, ensuring that
//! commands can only produce messages understood by that application.
//!
//! Applications generally do not need to construct or manage `Cmd` values
//! directly. They are returned from `update` to describe work that should be
//! performed by the `fud` runtime.
//!
//! This module is part of the public `fud` API. `Cmd` is typically referenced
//! as `fud.Cmd(Msg)` by application code.

/// `Cmd(Msg)` represents an operation that Fud may execute outside the synchronous
/// update call and that may eventually produce a `Msg` to be processed by the application.
pub fn Cmd(comptime Msg: type) type {
    _ = Msg;
    return union(enum) {
        none,
    };
}
