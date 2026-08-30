//! Runtime configuration for `fud` applications.
//!
//! This module defines the configuration values used by the `fud` runtime
//! when creating and initializing an application window.
//!
//! Applications provide a `Config` value as part of their application type:
//!
//!     pub const Config = fud.Config{
//!         .title = "Hello, Fud!",
//!         .width = 800,
//!         .height = 600,
//!     };
//!
//! The configuration type is owned by `fud` so that the runtime can rely on
//! a consistent configuration contract across applications.

/// Configuration for a `fud` application.
///
/// `Config` defines the basic properties required by the `fud` runtime to
/// create the application's window.
///
/// Applications should provide a `Config` value as part of their application
/// type:
///
///     pub const Config = fud.Config{
///         .title = "Hello, Fud!",
///         .width = 800,
///         .height = 600,
///     };
pub const Config = struct {
    /// The title displayed by the application window.
    title: [:0]const u8,

    /// The initial width of the application window in pixels.
    width: i32,

    /// The initial height of the application window in pixels.
    height: i32,
};
