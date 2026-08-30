//! Declarative UI views for `fud` applications.
//!
//! This module defines `View`, the type returned by an application's `view`
//! function. A view describes the user interface for the application's current
//! state and provides the `fud` runtime with the information it needs to
//! render the UI and produce application messages from user interaction.
//!
//! `View` is parameterized by the application's `Msg` type so that user
//! interactions can produce messages understood by that application.
//!
//! Applications generally create views from their `view` function rather than
//! interacting with the view representation directly. The `fud` runtime owns
//! the process of interpreting and rendering the resulting view.
//!
//! This module is part of the public `fud` API. `View` is typically referenced
//! as `fud.View(Msg)` by application code.

/// Creates the view type used by a `fud` application.
///
/// `View` represents a declarative description of the application's user
/// interface. It is parameterized by the application's `Msg` type so that
/// user interactions described by the view can produce messages understood
/// by the application.
///
/// The resulting type is returned by the application's `view` function and
/// is interpreted by the `fud` runtime to construct and update the UI.
///
/// `Msg` must be the application's message type.
pub fn View(comptime Msg: type) type {
    _ = Msg;
    return struct {
        // TODO: decide how this should actually be implemented.
    };
}
