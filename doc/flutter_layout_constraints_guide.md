# Flutter layout constraints (quick guide) and this package

## How constraints work in Flutter (short)

Every `RenderBox` receives **BoxConstraints** from its parent:

- **min/max width** and **min/max height** describe what size the child may be.
- A constraint is **bounded** when `maxWidth` / `maxHeight` are finite numbers.
- A constraint is **unbounded** when the corresponding max is infinite (`double.infinity`), for example the main axis of a vertical `ListView` or some `Viewport` children.

Children must pick a size that satisfies the constraints. Layouts like `Stack` with `StackFit.expand`, or “fill the parent” patterns, assume the incoming max is finite along the axis they expand on. If that max is infinite, you often get assertions or confusing overflow during build.

## Typical error messages

- `BoxConstraints forces an infinite height` or `has non-zero ... maxHeight ... but incoming height constraints are unbounded`
- `RenderFlex` overflow combined with a scrollable parent that never gave a bounded height to a non-scroll child

When you see these, walk **up** the widget tree and ask: *who was supposed to supply a finite height or width here?*

## How Real Page Flip uses constraints

The flip UI is built from stacked layers. Offstage pages and the active page must all receive the same finite box so:

- `RepaintBoundary` snapshots have a stable size.
- Internal animations and hit testing behave consistently.

`PageFlipWidget` therefore implements a **single constraint gate**:

- `LayoutBuilder` reads parent constraints.
- If width or height is not finite, the widget inserts a `SizedBox` using `MediaQuery` so the subtree is bounded.
- `PageFlipLayerView` receives `constrainedSize` and wraps each page branch in `SizedBox(width, height)` via `_wrapWithConstraints`.

This mirrors the comments in `lib/src/page_flip_widget.dart` and `lib/src/page_flip_layer_view.dart`.

## Checklist when something still breaks

1. **Confirm the flip region has a bounded size in your screen.** For example `Scaffold` body usually works; a bare `ListView` child with unbounded height does not unless you wrap the flip in `SizedBox`/`Expanded`.
2. **Don’t fight the gate:** wrapping `PageFlipWidget` in widgets that force unbounded expansion on both axes at once can still produce odd layouts; prefer one clear parent box (fixed aspect, `Expanded`, etc.).
3. **Heavy pages:** large `ListView`s inside a page are fine if the flip area itself is height-bounded; the list scrolls inside the page box.

## Related reading

- Package overview: [README.md](../README.md) (English), [README_KR.md](../README_KR.md) (Korean)
- Layout summary for this widget: [README_LAYOUT_CONSTRAINTS.md](../README_LAYOUT_CONSTRAINTS.md)
