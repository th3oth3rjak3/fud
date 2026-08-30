//! Memory management for `fud`.
//!
//! This module owns the application allocator used by the `fud` runtime.
//! The allocator is process-wide and remains valid for the lifetime of the
//! running application.
//!
//! In debug-oriented build modes, `fud` uses `std.heap.DebugAllocator` so
//! that allocations can be tracked and memory leaks can be detected when
//! the application shuts down.
//!
//! In performance-oriented build modes, `fud` uses a high-performance
//! allocator without the additional debugging overhead.
//!
//! The allocator returned by this module is provided to the application's
//! `init`, `update`, and `deinit` functions. Applications may use it for
//! allocations whose lifetime extends beyond an individual view.
//!
//! Views use a separate temporary allocator owned by the `fud` runtime.
//! That allocator is not exposed through this module and has a shorter
//! lifetime than the application allocator.
//!
//! The allocator must be initialized before use and deinitialized exactly
//! once when the application shuts down. The `fud` runtime is responsible
//! for managing this lifecycle.
//!
//! This module is an implementation detail of `fud` and should generally
//! not need to be imported directly by applications.

const std = @import("std");
const builtin = @import("builtin");

const DebugAllocator = std.heap.DebugAllocator(.{});

var debug_allocator: DebugAllocator = .init;

pub fn allocator() std.mem.Allocator {
    return switch (builtin.mode) {
        .Debug, .ReleaseSafe => debug_allocator.allocator(),
        .ReleaseFast, .ReleaseSmall => std.heap.smp_allocator,
    };
}

pub fn deinit() void {
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            if (debug_allocator.deinit() == .leak) {
                std.debug.print(
                    "fud: memory leaks detected\n",
                    .{},
                );
            } else {
                std.debug.print(
                    "fud: no memory leaks detected, nice work!\n",
                    .{},
                );
            }
        },
        .ReleaseFast, .ReleaseSmall => {},
    }
}
