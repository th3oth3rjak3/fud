# Fud

**Fud** is a declarative MVU UI framework for [Zig](https://ziglang.org/), built on top of [raylib](https://www.raylib.com/) via raylib-zig.

The name is a dumb joke about **Fear, Uncertainty, and Doubt**.

Fud is heavily inspired by Elm and Elmish, but designed around Zig's strengths: explicit ownership, mutable state, and compile-time metaprogramming.

## The Idea

You define your application's **Model** and **Msg** types. Fud handles the UI, input, layout, rendering, and application loop.

```zig
const App = struct {
    pub const Model = struct {
        count: i32,
    };

    pub const Msg = union(enum) {
        increment,
        decrement,
    };

    pub fn init() Model {
        return .{ .count = 0 };
    }

    pub fn update(msg: Msg, model: *Model) fud.Cmd(Msg) {
        switch (msg) {
            .increment => model.count += 1,
            .decrement => model.count -= 1,
        }

        return .none;
    }

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
};
```

The application describes **what the UI should be**, rather than drawing it directly.

```text
Model
  │
  ▼
view(*const Model)
  │
  ▼
Declarative View
  │
  ▼
Fud
  │
  ├── Layout
  ├── Input
  ├── Hit Testing
  └── Rendering
          │
          ▼
      raylib-zig
```

When the user interacts with the UI, Fud produces the application's `Msg` and sends it through the MVU loop:

```text
Msg
 │
 ▼
update(msg, *Model)
 │
 ├── mutate Model
 │
 └── return Cmd(Msg)
          │
          ▼
        effect
          │
          ▼
         Msg
```

## Design Goals

* **Declarative UI** — describe the UI; Fud draws it.
* **Elmish MVU architecture** — Model, Msg, View, Update, and Commands.
* **Strongly typed messages** — the application's own `union(enum)` is used throughout the UI.
* **Zig-native ownership** — mutable Models and explicit memory management.
* **Comptime-driven** — Fud specializes itself around the application's types.
* **raylib simplicity** — raylib-zig provides the graphics backend without leaking rendering concerns into application code.
* **No framework-owned application state** — your Model and Msg types belong to you.

## Application Contract

The core application API is intentionally small:

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

`update()` receives mutable access to the Model.

`view()` receives read-only access to the Model and cannot mutate it.

Application errors are the application's responsibility. If an error needs to participate in the MVU loop, the application can represent it as a `Msg`.

Fud runtime errors are separate and may optionally be handled with an `onError` hook.

## Status

Fud is currently in the **architecture and early implementation phase**.

The initial focus is establishing the core:

1. Application contract
2. `View(Msg)`
3. Declarative UI elements
4. Layout
5. Message dispatch
6. raylib rendering
7. MVU runtime
8. Commands and subscriptions

The API is expected to evolve substantially while these foundations are developed.
