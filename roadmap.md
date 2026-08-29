# Fud — Declarative MVU UI Framework for Zig + raylib

> Fud is an Elmish-inspired Model-View-Update framework for Zig, built on
> top of raylib-zig.
>
> The name is a joke about Fear, Uncertainty, and Doubt.
>
> Fud's goal is to make building desktop applications and interactive tools
> in Zig straightforward:
>
> - The application owns its Model and Msg types.
> - `update()` mutates the Model in response to messages.
> - `view()` declaratively describes the UI.
> - Fud handles layout, rendering, input, hit testing, and the application loop.
> - raylib-zig is the graphics backend and should remain an implementation detail.
> - Application errors belong to the application.
> - Fud runtime errors are handled separately through an optional error hook.

---

# 1. Project Philosophy

Fud should be a **declarative UI framework**, not a thin wrapper around raylib.

The application developer should NOT have to manually:

- call raylib drawing functions
- calculate widget positions
- calculate widget dimensions
- perform mouse hit testing
- translate mouse coordinates into UI actions
- manage the application loop
- maintain widget state separately from the application model

Instead, the developer describes what the UI should look like:

```zig
pub fn view(model: *const Model) fud.View(Msg) {
    return fud.column(.{
        fud.text("Counter"),
        fud.text(model.count),
        fud.button(.{
            .text = "Increment",
            .on_click = .increment,
        }),
    });
}
```

Fud turns that declarative description into:

```text
View Tree
    ↓
Layout
    ↓
Hit Testing
    ↓
Rendering
    ↓
raylib-zig
    ↓
raylib
```

The application should primarily deal with:

```text
Model
Msg
init
update
view
Cmd
```

---

# 2. High-Level Architecture

Fud consists of four major layers:

```text
┌──────────────────────────────────────────────┐
│                 APPLICATION                  │
│                                              │
│        Model │ Msg │ Update │ View           │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│                 FUD MVU                      │
│                                              │
│    Runtime │ Messages │ Commands │ Subs      │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│                  FUD UI                      │
│                                              │
│   Element │ Layout │ Style │ Interaction    │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│              RAYLIB BACKEND                  │
│                                              │
│              raylib-zig → raylib             │
└──────────────────────────────────────────────┘
```

The application does not interact directly with the rendering backend.

---

# 3. Core MVU Architecture

The application follows the basic Elmish architecture, adapted to Zig's
mutable ownership model:

```text
                  ┌─────────────┐
                  │    Model    │
                  └──────┬──────┘
                         │
                         │ *const Model
                         ▼
                  ┌─────────────┐
                  │    View     │
                  └──────┬──────┘
                         │
                         ▼
                    View Tree
                         │
                         ▼
                       Fud
                         │
                    user input
                         │
                         ▼
                  ┌─────────────┐
                  │     Msg     │
                  └──────┬──────┘
                         │
                         ▼
                  ┌─────────────┐
                  │    Update   │
                  └──────┬──────┘
                         │
                    *Model mutation
                         │
                    ┌────┴────┐
                    │         │
                    ▼         ▼
                  Model      Cmd(Msg)
                              │
                              ▼
                            effect
                              │
                              ▼
                             Msg
```

The fundamental state transition is:

```text
Msg
 ↓
update(msg, *Model)
 ↓
mutate Model
 ↓
Cmd(Msg)
```

The fundamental UI transition is:

```text
*const Model
      ↓
    view()
      ↓
  View(Msg)
```

The Model is owned by the Fud runtime.

The application receives:

- `*Model` in `update()` so it can mutate the existing Model.
- `*const Model` in `view()` so it can observe the Model but cannot mutate it.

This avoids unnecessary copying and provides a straightforward Zig ownership
model.

---

# 4. Application Type and Comptime

Fud should use Zig's `comptime` capabilities to specialize the framework around
the user's application types.

The preferred application structure is:

```zig
const App = struct {
    pub const Model = struct {
        count: i32,
    };

    pub const Msg = union(enum) {
        increment,
        decrement,
        reset,
    };

    pub fn init() Model {
        return .{
            .count = 0,
        };
    }

    pub fn update(
        msg: Msg,
        model: *Model,
    ) fud.Cmd(Msg) {
        switch (msg) {
            .increment => model.count += 1,
            .decrement => model.count -= 1,
            .reset => model.count = 0,
        }

        return .none;
    }

    pub fn view(
        model: *const Model,
    ) fud.View(Msg) {
        return fud.column(.{
            fud.text("Counter"),
            fud.text(model.count),

            fud.button(.{
                .text = "Increment",
                .on_click = .increment,
            }),

            fud.button(.{
                .text = "Decrement",
                .on_click = .decrement,
            }),

            fud.button(.{
                .text = "Reset",
                .on_click = .reset,
            }),
        });
    }
};
```

The user should eventually be able to run the application with something
similar to:

```zig
try fud.run(App, .{
    .title = "My Fud Application",
    .width = 800,
    .height = 600,
});
```

Internally, Fud specializes its types around the application:

```text
Runtime(App)
View(App.Msg)
Cmd(App.Msg)
MessageQueue(App.Msg)
```

This avoids:

- interfaces
- runtime type erasure
- `void*`
- global message types
- framework-owned application state

The user's Model and Msg remain ordinary Zig types.

---

# 5. Model Ownership

The Fud runtime owns the application's Model for the lifetime of the
application.

Conceptually:

```text
┌──────────────────────┐
│       Runtime        │
│                      │
│        owns          │
│         │            │
│         ▼            │
│       Model          │
│                      │
└──────────────────────┘
```

The runtime provides controlled access to that Model.

`update()` receives mutable access:

```zig
pub fn update(
    msg: Msg,
    model: *Model,
) fud.Cmd(Msg) {
    ...
}
```

`view()` receives read-only access:

```zig
pub fn view(
    model: *const Model,
) fud.View(Msg) {
    ...
}
```

This creates a clear boundary:

```text
                    Model
                   /     \
                  /       \
                 ▼         ▼
        update(*Model)   view(*const Model)
             │                │
             │                │
             ▼                ▼
          MUTABLE           READ ONLY
```

The view layer must never be able to mutate application state.

The only normal path for application state mutation is through `update()`.

---

# 6. Why Fud Uses Mutable Model Updates

Classic Elm and Elmish applications use immutable Model values.

Fud is written in Zig, where explicit mutable ownership is a better fit for
the language and its memory model.

Fud therefore intentionally uses:

```zig
update(msg, *Model)
```

instead of:

```text
update(msg, Model) → new Model
```

The runtime owns one Model rather than repeatedly copying and replacing it.

This is particularly important for Models containing:

- `ArrayList`
- hash maps
- allocated strings
- application-owned resources
- other structures containing pointers or allocations

The Model's allocations remain owned by the Model and therefore by the
application/runtime boundary.

Fud should not attempt to implement Elm-style persistent immutable data
structures.

---

# 7. Application Errors vs Fud Errors

Fud should make a strict distinction between **application errors** and
**Fud runtime errors**.

## Application Errors

Application errors belong to the application.

Fud should not require `update()` to return an error union.

Do NOT design the application contract as:

```zig
pub fn update(
    msg: Msg,
    model: *Model,
) !fud.Cmd(Msg) {
    ...
}
```

Instead:

```zig
pub fn update(
    msg: Msg,
    model: *Model,
) fud.Cmd(Msg) {
    ...
}
```

If an application performs an operation that can fail, the application decides
how that failure participates in its MVU architecture.

For example:

```zig
const FileError = enum {
    permission_denied,
    not_found,
    disk_full,
};

const Msg = union(enum) {
    save,
    save_succeeded,
    save_failed: FileError,
};
```

An application command can perform the operation and turn the result into an
appropriate `Msg`.

Conceptually:

```text
update()
   ↓
Cmd(Msg)
   ↓
application performs operation
   │
   ├── success ──→ Msg
   │
   └── failure ──→ Msg
                         ↓
                      update()
```

Fud does not need to understand what an application error means.

---

# 8. Fud Runtime Errors

Fud itself may encounter errors that are not application-level concerns.

Examples:

- raylib initialization failure
- window creation failure
- Fud-owned allocation failure
- backend initialization failure
- other framework/runtime failures

These errors should remain outside the application's `Msg` type.

The runtime may therefore return a Fud error from the top-level application
runner:

```zig
pub fn main() !void {
    try fud.run(App, .{});
}
```

The distinction is:

```text
Application error
    ↓
Application converts it to Msg
    ↓
MVU system

Fud runtime error
    ↓
Fud error handling
    ↓
optional App.onError()
```

Fud must not require applications to add framework errors to their own Msg
union.

---

# 9. Optional `onError` Hook

Applications may optionally define an error handler:

```zig
pub fn onError(err: fud.Error) void {
    std.log.err("Fud runtime error: {}", .{err});
}
```

The application does not need to provide this function.

Fud can use comptime introspection to determine whether `App.onError` exists.

Conceptually:

```text
Fud runtime error
       │
       ▼
App has onError?
   │          │
  yes         no
   │          │
   ▼          ▼
onError()   Fud default handling
```

This hook is specifically for Fud-owned runtime errors.

It is not part of the normal MVU message pipeline.

---

# 10. Phase 0 — Establish the Foundation

Before implementing UI features, establish the basic project and package
structure.

Tasks:

- [x] Create Fud repository
- [x] Create `build.zig`
- [x] Create `build.zig.zon`
- [x] Add raylib-zig dependency
- [x] Verify compatibility with Zig 0.16
- [x] Create Fud module
- [x] Create a minimal example that verifies the Fud module can be imported and linked.

Deliverable:

A Zig 0.16 project that successfully builds Fud and links raylib-zig.

---

# 11. Phase 1 — Define the Application Contract

Design and implement the application-level API.

The initial contract should be:

```text
App
├── Model
├── Msg
├── init()
├── update()
├── view()
└── optional onError()
```

The core signatures are:

```zig
pub fn init() Model

pub fn update(
    msg: Msg,
    model: *Model,
) fud.Cmd(Msg)

pub fn view(
    model: *const Model,
) fud.View(Msg)
```

Optional runtime error handling:

```zig
pub fn onError(err: fud.Error) void
```

Use comptime validation where appropriate.

Fud should detect invalid application definitions at compile time whenever
practical.

For example:

- `Model` must exist.
- `Msg` must exist.
- `init()` must return `Model`.
- `update()` must accept `Msg` and `*Model`.
- `update()` must return `fud.Cmd(Msg)`.
- `view()` must accept `*const Model`.
- `view()` must return `fud.View(Msg)`.
- `onError()` is optional.

Do not build a complicated reflection system.

Use Zig's comptime facilities directly.

## Comptime Diagnostics

Fud's comptime validation is part of its developer experience.

Invalid application definitions must produce clear, actionable compiler
diagnostics rather than relying on incidental Zig type errors.

Validation should:

- Check one contract requirement at a time.
- Detect missing declarations before accessing them.
- Report the declaration/function responsible for the failure.
- Show the expected signature.
- Show the discovered signature when practical.
- Explain why the requirement exists.
- Provide a minimal correction/example.
- Use consistent Fud-specific diagnostic wording.

The goal is that a developer unfamiliar with Fud should be able to fix an
invalid App definition from the compiler output without needing to search
through framework internals.

---

# 12. Phase 2 — Design the Declarative View System

This is the most important UI design phase.

Before implementing the renderer, define what `view()` returns.

The user should describe the UI declaratively:

```zig
pub fn view(model: *const Model) fud.View(Msg) {
    return fud.column(.{
        fud.text("Counter"),

        fud.text(model.count),

        fud.button(.{
            .text = "Increment",
            .on_click = .increment,
        }),

        fud.button(.{
            .text = "Decrement",
            .on_click = .decrement,
        }),
    });
}
```

The user should NOT draw anything manually.

The view is a description of the UI, not a sequence of raylib drawing commands.

---

# 13. `View(Msg)`

The View type should represent the declarative UI tree.

Conceptually:

```text
View(Msg)
    │
    └── Element(Msg)
            │
            ├── Text
            ├── Button
            ├── Container
            ├── Row
            ├── Column
            ├── Spacer
            ├── Image
            └── ...
```

The exact representation should be determined during implementation.

The important requirement is:

> A View is a description of UI, not a sequence of drawing commands.

`View(Msg)` should be specialized around the application's actual `Msg` type.

---

# 14. `Element(Msg)`

Elements represent individual nodes in the UI tree.

A conceptual representation might be:

```text
Element(Msg)
```

containing variants such as:

- Text
- Button
- Container
- Row
- Column
- Image
- Spacer

Interactive elements can contain messages.

For example:

```zig
fud.button(.{
    .text = "Increment",
    .on_click = .increment,
});
```

The button does not execute `.increment`.

It simply declares:

> When this element is activated, dispatch this message.

Fud handles the rest.

---

# 15. Messages Attached to UI Elements

The UI system should use the application's actual `Msg` type.

Conceptually:

```text
Button(Msg)
```

rather than a generic framework event system.

The user's Msg may contain data:

```zig
const Msg = union(enum) {
    increment,
    decrement,

    set_count: i32,

    delete_item: u64,

    save_item: struct {
        id: u64,
        name: []const u8,
    },
};
```

A UI element can therefore contain a complete application message:

```zig
fud.button(.{
    .text = "Delete",
    .on_click = .{
        .delete_item = item.id,
    },
});
```

The message path is:

```text
Button(Msg)
    ↓
actual App.Msg value
    ↓
Fud message queue
    ↓
update(msg, *Model)
```

There should be no need for:

- string-based event names
- event IDs
- runtime casts
- `void*`
- generic framework event objects

---

# 16. View Tree

A complete View should form a tree.

Example:

```text
Column
├── Text("Counter")
├── Text("0")
├── Row
│   ├── Button("Increment")
│   └── Button("Decrement")
└── Button("Reset")
```

Fud owns the runtime representation of this tree.

The application only describes it.

The tree becomes the input to subsequent stages:

```text
View Tree
    ↓
Layout
    ↓
Interaction
    ↓
Rendering
```

---

# 17. Phase 3 — Children and Tree Construction

Design how child elements are represented.

We need a solution that:

- works naturally with Zig
- avoids unnecessary heap allocation
- supports nested UI
- remains ergonomic
- can represent variable numbers of children
- can eventually support reusable components

Example desired syntax:

```zig
fud.column(.{
    fud.text("Hello"),

    fud.row(.{
        fud.button(.{
            .text = "Yes",
            .on_click = .yes,
        }),

        fud.button(.{
            .text = "No",
            .on_click = .no,
        }),
    }),
});
```

Investigate:

- tuples
- comptime tuples
- slices
- fixed arrays
- arena allocation
- runtime-owned view trees
- type-erased internal element representation

Do not choose a representation merely because it is convenient to implement.

The view API should be designed first.

---

# 18. Phase 4 — Layout Engine

Once the View tree exists, implement layout.

The layout engine transforms:

```text
Declarative View Tree
```

into:

```text
Positioned Layout Tree
```

Example:

```text
Column
├── Text      x=20 y=20  w=400 h=30
├── Button    x=20 y=60  w=400 h=40
└── Row       x=20 y=110 w=400 h=40
    ├── Button x=20  y=110 w=195 h=40
    └── Button x=225 y=110 w=195 h=40
```

Layout should determine:

- position
- width
- height
- padding
- margin
- spacing
- alignment
- minimum size
- maximum size
- available space
- row/column behavior

---

# 19. Layout Should Be Separate From Rendering

The renderer should not decide layout.

The pipeline should be:

```text
View
 ↓
Layout
 ↓
Geometry
 ↓
Render
```

This allows the same layout information to be used by:

- rendering
- hit testing
- accessibility later
- debugging
- UI inspection later

---

# 20. Phase 5 — Interaction and Hit Testing

Once every element has geometry, Fud can determine which element receives
input.

Example:

```text
raylib mouse click
        ↓
     position
        ↓
   hit testing
        ↓
     Button
        ↓
   associated Msg
        ↓
   message queue
```

The application should not perform hit testing.

For example, the application should never need:

```zig
if (mouse_x >= button_x and mouse_x <= button_x + button_width) {
    ...
}
```

Fud owns that responsibility.

---

# 21. Interaction States

Elements should eventually have interaction state such as:

- normal
- hovered
- pressed
- disabled
- focused

These states should generally be UI/runtime state, not application state,
unless the application explicitly needs them.

For example:

```text
Button
├── normal
├── hovered
├── pressed
└── disabled
```

Fud can use these states for styling and rendering without forcing them into
Model.

---

# 22. Phase 6 — raylib Backend

Only after the declarative View and layout system are established should we
implement the rendering backend.

The backend consumes:

```text
Element
+
Layout
+
Style
```

and produces:

```text
raylib drawing calls
```

Architecture:

```text
View Tree
    ↓
Layout Tree
    ↓
Raylib Backend
    ↓
raylib-zig
    ↓
raylib
```

The user should never need to interact with the backend directly for normal
UI development.

---

# 23. Backend Structure

The raylib backend should be an implementation detail.

Potential file:

```text
src/backend/raylib.zig
```

It should contain the code responsible for translating Fud's internal UI
representation into raylib operations.

The backend should know about:

- raylib-zig
- textures
- fonts
- drawing primitives
- clipping
- render targets
- window dimensions
- mouse position
- keyboard state

The rest of Fud should not need to know how those things are implemented.

---

# 24. Phase 7 — Styling

Once basic rendering works, establish the styling system.

Potential style properties:

- foreground color
- background color
- font
- font size
- padding
- margin
- border
- border width
- corner radius
- spacing
- alignment
- width
- height
- minimum size
- maximum size

Interactive styles should support states:

```text
normal
hovered
pressed
focused
disabled
```

Example conceptual API:

```zig
fud.button(.{
    .text = "Save",
    .on_click = .save,

    .style = .{
        .padding = 12,
    },
})
```

The exact style API should be designed after the core element model is
working.

---

# 25. Phase 8 — MVU Runtime

Once the UI pipeline is functional, implement the complete runtime.

The runtime owns:

- application lifecycle
- current Model
- message queue
- message dispatch
- command execution
- subscriptions
- raylib window
- frame timing
- input polling
- view generation
- layout
- rendering

The runtime loop should conceptually be:

1. Poll raylib events.
2. Convert relevant events into Fud input events.
3. Perform UI hit testing.
4. Generate application `Msg` values.
5. Queue messages.
6. Process queued messages.
7. Call `update()` for each message.
8. Allow `update()` to mutate the Model.
9. Receive the resulting `Cmd(Msg)`.
10. Execute Commands.
11. Queue any messages produced by Commands.
12. Generate the current View.
13. Lay out the View.
14. Render the result.
15. Repeat.

The runtime should not expect application errors from `update()`.

---

# 26. Message Queue

The message queue is the central nervous system of Fud.

Everything that wants to affect application state eventually produces a `Msg`.

Sources include:

- UI interaction
- commands
- subscriptions
- timers
- application-generated messages

The flow is:

```text
external event
    ↓
Msg
    ↓
message queue
    ↓
update(msg, *Model)
    ↓
mutated Model
    ↓
Cmd(Msg)
```

Dispatch should enqueue a message rather than immediately invoking `update()`.

Preferred:

```text
dispatch(msg)
    ↓
queue.push(msg)
```

Then the runtime decides when:

```text
queue.pop()
    ↓
update(msg, *Model)
```

---

# 27. Phase 9 — Commands

Commands represent side effects initiated by `update()`.

The command type should be specialized around the application's Msg type:

```text
Cmd(Msg)
```

Conceptually:

```text
Msg
 ↓
update()
 ↓
mutate Model
 ↓
Cmd(Msg)
 ↓
effect
 ↓
Msg
```

Examples:

- load a file
- save a file
- perform network operation
- query the filesystem
- perform asynchronous work

Commands should not directly modify the Model.

Commands produce `Msg` values that are returned to the normal message queue.

---

# 28. Command Ownership and Errors

Commands are application behavior, not Fud application-error handling.

If a command performs an operation that can fail, the command should translate
that result into an application-defined `Msg`.

For example:

```text
Cmd(Msg)
    ↓
filesystem operation
    │
    ├── success
    │      ↓
    │   .file_loaded
    │
    └── failure
           ↓
       .file_load_failed
```

The exact command API must be designed around Zig's ownership and lifetime
rules.

In particular, Fud must carefully define ownership for data captured by a
Command and data carried by a Msg.

---

# 29. Phase 10 — Subscriptions

Subscriptions represent ongoing external event sources.

Potential subscriptions include:

- timers
- keyboard input
- window events
- filesystem events
- application-defined event sources

Conceptually:

```text
Subscription
      ↓
 external event
      ↓
     Msg
      ↓
 message queue
      ↓
 update(msg, *Model)
```

Subscriptions must use the application's Msg type.

They should not bypass the MVU message queue.

---

# 30. Phase 11 — Primitive Widgets

Once the core framework is stable, implement the primitive widgets.

Initial widget set:

- [ ] Text
- [ ] Button
- [ ] Container
- [ ] Row
- [ ] Column
- [ ] Spacer
- [ ] Image
- [ ] Checkbox
- [ ] Text input
- [ ] Slider
- [ ] Scroll container

Widgets should primarily be declarative descriptions.

Avoid turning every widget into a special case in the runtime.

---

# 31. Phase 12 — Higher-Level Components

Build reusable components on top of the primitive UI system.

Potential components:

- Card
- Panel
- Dialog
- Modal
- Toolbar
- Sidebar
- Menu
- Tabs
- List
- Table
- Form

Components should ideally compose existing Fud primitives rather than
requiring custom rendering code.

---

# 32. Phase 13 — Resources

Establish resource management for things such as:

- fonts
- textures
- images
- render targets
- audio resources, if eventually supported

The application should not need to manually manage raw raylib resources for
normal UI usage.

Investigate an application-owned resource manager or runtime-owned resource
context.

Resource lifetime must be compatible with Zig's allocator and ownership model.

---

# 33. Phase 14 — Window and Application Configuration

Provide a clean configuration API for the application.

Potential configuration:

```zig
try fud.run(App, .{
    .title = "My Application",
    .width = 1280,
    .height = 720,
    .resizable = true,
    .vsync = true,
});
```

Potential future configuration:

- fullscreen
- target FPS
- MSAA
- window icons
- minimum window size
- maximum window size
- DPI scaling
- debug mode

---

# 34. Phase 15 — Testing

Fud should make as much of the framework testable without opening a window
as possible.

Unit-test:

- MVU update behavior
- message dispatch
- command behavior
- view construction
- layout calculations
- hit testing
- style resolution

Integration-test:

- view → layout
- layout → hit testing
- interaction → Msg
- Msg → update
- update → Cmd
- complete application loop

The core MVU and layout logic should not depend on a running raylib window
where unnecessary.

---

# 35. Phase 16 — Example Applications

Build progressively more complicated examples.

## Counter

Demonstrates:

- Model
- Msg
- init
- update
- view
- buttons
- message dispatch
- mutable Model updates

## Todo

Demonstrates:

- collections
- text input
- multiple messages
- conditional views
- lists

## Calculator

Demonstrates:

- richer message types
- nested layout
- buttons
- derived view state

## File Browser

Demonstrates:

- commands
- filesystem interaction
- application-defined errors
- dynamic lists
- selection
- asynchronous operations

## Password Manager

Potential long-term stress test.

Demonstrates:

- complex application state
- forms
- dialogs
- lists
- keyboard interaction
- commands
- resource management
- styling
- multiple screens/views

---

# 36. Proposed Source Tree

The exact source tree should evolve as implementation progresses, but the
initial architecture should roughly resemble:

```text
fud/
├── build.zig
├── build.zig.zon
├── README.md
│
├── src/
│   ├── fud.zig
│   │
│   ├── mvu/
│   │   ├── app.zig
│   │   ├── runtime.zig
│   │   ├── message.zig
│   │   ├── command.zig
│   │   └── subscription.zig
│   │
│   ├── ui/
│   │   ├── view.zig
│   │   ├── element.zig
│   │   ├── children.zig
│   │   ├── layout.zig
│   │   ├── style.zig
│   │   ├── interaction.zig
│   │   └── widgets/
│   │       ├── text.zig
│   │       ├── button.zig
│   │       ├── container.zig
│   │       ├── row.zig
│   │       ├── column.zig
│   │       ├── spacer.zig
│   │       └── image.zig
│   │
│   └── backend/
│       └── raylib.zig
│
├── examples/
│   ├── counter/
│   ├── todo/
│   ├── calculator/
│   └── file_browser/
│
└── tests/
    ├── mvu/
    ├── ui/
    ├── layout/
    └── backend/
```

This is a proposed organization, not a requirement to create every file
immediately.

---

# 37. Dependency Direction

The dependency direction should remain intentionally one-way:

```text
Application
    │
    ▼
   Fud
    │
    ├── MVU
    │
    ├── UI
    │
    ├── Layout
    │
    └── Backend
          │
          ▼
      raylib-zig
          │
          ▼
        raylib
```

The UI layer should not depend on the raylib backend.

The MVU layer should not depend on raylib.

The application should not need to know about raylib internals.

This separation is important because it keeps the architecture understandable
and leaves open the possibility of additional rendering backends in the future.

---

# 38. Critical Design Constraints

The following principles should guide implementation.

## 38.1 The application owns Model

Fud provides the runtime ownership boundary, but the Model is the application's
state.

The user defines:

```zig
const Model = struct {
    ...
};
```

---

## 38.2 The application owns Msg

Fud must not impose a framework-wide message enum.

The user defines:

```zig
const Msg = union(enum) {
    ...
};
```

Messages may contain arbitrary application-defined payloads.

Fud specializes itself around that type using comptime.

---

## 38.3 `update()` receives mutable Model access

The contract is:

```zig
pub fn update(
    msg: Msg,
    model: *Model,
) fud.Cmd(Msg)
```

`update()` is the normal mechanism through which application state changes.

---

## 38.4 `view()` receives immutable Model access

The contract is:

```zig
pub fn view(
    model: *const Model,
) fud.View(Msg)
```

The view must not be able to mutate application state.

---

## 38.5 View is declarative

The user describes what should exist.

The user does not manually draw it.

---

## 38.6 Fud owns UI interaction

The framework handles:

- mouse input
- keyboard input
- hit testing
- focus
- hover
- pressed state
- dispatching messages

---

## 38.7 Fud owns rendering

The application should not normally call raylib drawing functions.

---

## 38.8 All application state changes flow through Msg

The primary state transition is:

```text
Msg
 ↓
update(*Model)
 ↓
Model mutation
```

---

## 38.9 Commands do not mutate Model

Commands perform effects and eventually produce messages.

The resulting messages return to the normal MVU loop.

---

## 38.10 Application errors belong to the application

Fud does not require application error unions from:

```zig
update()
```

or other application-level MVU functions.

Application failures should become application-defined messages when they need
to participate in the MVU architecture.

---

## 38.11 Fud runtime errors are separate

Framework failures should not be injected into the application's Msg type.

They belong to Fud's runtime error path and may optionally be observed through:

```zig
pub fn onError(err: fud.Error) void
```

---

## 38.12 Layout is independent of rendering

Layout determines geometry.

Rendering consumes geometry.

---

## 38.13 Avoid premature abstraction

Do not create interfaces, registries, virtual dispatch, or complicated
component systems until the underlying use case requires them.

Zig's comptime system should be preferred where it naturally solves the
problem.

---

# 39. Immediate Next Step

Do NOT begin by implementing the entire runtime.

The immediate design task is:

> **Define exactly what `fud.View(Msg)` and `Element(Msg)` should look like.**

We need to settle:

1. What a `View(Msg)` actually is.
2. How elements are represented.
3. How children are represented.
4. How nested elements are constructed.
5. How an application-defined `Msg` is attached to interactive elements.
6. How comptime specializes the view tree around `Msg`.
7. What information belongs to the declarative view.
8. What information belongs to the runtime/layout tree.
9. How memory ownership works.
10. Whether the public API and internal representation should be different.
11. How the view tree survives between frames, if at all.
12. Whether Fud rebuilds the declarative tree every frame or introduces a
    retained representation.

Only after those decisions should we implement the layout engine.

The intended development order is therefore:

```text
Application Contract
        ↓
Model Ownership
        ↓
Msg / Cmd Contract
        ↓
View(Msg)
        ↓
Element(Msg)
        ↓
Children / Tree
        ↓
Layout
        ↓
Hit Testing
        ↓
raylib Backend
        ↓
Runtime
        ↓
Commands
        ↓
Subscriptions
        ↓
Widgets
        ↓
Styling / Components
```

The core architectural goal is:

```text
                    USER
                     │
                     ▼
              ┌─────────────┐
              │    Model    │
              └──────┬──────┘
                     │
                     │ *const Model
                     ▼
              ┌─────────────┐
              │   view()    │
              └──────┬──────┘
                     │
                     ▼
             Declarative View
                     │
                     ▼
                   Fud
                     │
          ┌──────────┼──────────┐
          │          │          │
        Layout    Interaction  Style
          │          │          │
          └──────────┼──────────┘
                     │
                     ▼
                raylib-zig
                     │
                     ▼
                   Screen

Screen interaction
        │
        ▼
      Fud
        │
        ▼
       Msg
        │
        ▼
 update(msg, *Model)
        │
        ├──────────────► Model mutation
        │
        ▼
    Cmd(Msg)
        │
        ▼
     effect
        │
        ▼
       Msg
```

Fud should make the MVU loop feel natural to a Zig developer while keeping
the underlying implementation strongly typed, explicit, and idiomatic to Zig.
