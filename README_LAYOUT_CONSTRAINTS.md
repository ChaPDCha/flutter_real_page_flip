# Layout constraints and PageFlipWidget

This package renders a multi-layer page stack (`Stack`, offstage pages, `RepaintBoundary`). Those layouts only work when children receive **finite** width and height. If a parent passes **unbounded** max height or max width (common on the first frame of `Scaffold.body`, or inside some scrollables), Flutter may throw constraint errors or behave unpredictably.

## What PageFlipWidget does

`PageFlipWidget` wraps its content in a `LayoutBuilder` and:

1. Reads the incoming `constraints`.
2. If either max width or max height is not finite, it wraps the subtree in a `SizedBox` sized from `MediaQuery` so descendants always see a **bounded** box.
3. Passes an explicit `constrainedSize` into `PageFlipLayerView`, which wraps each page layer in `_wrapWithConstraints` (`SizedBox`) so `Stack(fit: StackFit.expand)` does not propagate infinite constraints to page content.

See the implementation in `lib/src/page_flip_widget.dart` and `lib/src/page_flip_layer_view.dart`.

## Do / don’t (practical)

**Do**

- Place `PageFlipWidget` where it normally gets a bounded area: for example under `Scaffold.body`, inside `Expanded`, or inside a `SizedBox` with explicit height.
- Keep complex scrollable content *inside* each page; the engine snapshots adjacent pages and expects each page to lay out within the flip area.

**Don’t**

- Avoid putting `PageFlipWidget` as the only child of a vertical scrollable when that scrollable does not give the flip a finite height (the parent must constrain height).
- If you nest flips or overlays, ensure each layer still receives finite constraints from its parent.

## More detail

For a short Flutter constraints refresher and troubleshooting, see [doc/flutter_layout_constraints_guide.md](doc/flutter_layout_constraints_guide.md).
