<video src="https://github.com/user-attachments/assets/656892d5-a426-4161-9630-511447a1b347" controls="controls" style="max-width: 100%;"></video>

Real Page Flip Engine for Flutter

Welcome! This is a Flutter library designed to give your app a highly realistic, 3D-like page turning effect. We focused on recreating the physical feel of paper, complete with proper shadow rendering, specular highlights, and fluid, natural motion.

Whether you're building a digital magazine, a realistic book reader, or a presentation app, this engine makes the reading experience feel tactile and beautiful.

Why We Built This

Most existing page flip effects in Flutter rely on simple 2D transformations that don't quite capture the physical essence of paper. We built this engine to solve that problem.

We engineered the layout structure to maintain a smooth 60 frames per second on all supported platforms. The engine carefully tracks touch gestures and calculates page snapping based on the velocity of your swipe, so taking hold of a page and flipping it feels just like the real thing.

Reliability and Performance

We also took care of the hidden complexities. Standard page flip implementations often break down or cause layout errors when dealing with dynamic widgets or expanding viewports.

This engine is built differently. It includes layers of protection to prevent unbounded layout constraint errors. We built it to be completely safe and predictable, even when you're flipping complex, stateful widgets. From an API perspective, we made sure programmatic state transitions are deferred until all animations finish safely, giving you reliable control over the navigation flow.

For where and how constraints are enforced in this widget, see [README_LAYOUT_CONSTRAINTS.md](README_LAYOUT_CONSTRAINTS.md).

Sensory Experience: Sound and Haptics

What truly sets this engine apart is the immersive sensory feedback. To complement the visual realism, we've integrated synchronized page-turning sounds and haptic feedback.

- **Physical Sound Effects**: Each flip triggers a high-quality, directional sound effect that mimics the rustle of a real page, varying naturally with the speed of your gesture.
- **Tactile Haptics**: Feel the friction and the "snap" of the paper through your device's haptic engine. These subtle vibrations are finely tuned to match the visual fold, making the digital experience feel incredibly solid and authentic.
- **Customizable**: A default `page_flip.mp3` is bundled with the package. You can turn sound and haptics off with `PageFlipConfig.enableSound` / `enableHaptics`, intercept events with `PageFlipWidget.onHandleEffect`, or plug in a fully custom `PageFlipConfig.effectHandler`.

Installation

Requirements: Flutter **3.10.0** or newer (see `pubspec.yaml`).

Add `real_page_flip` to your app `pubspec.yaml`:

```yaml
dependencies:
  real_page_flip: ^1.1.1
```

You can also depend on a Git revision:

```yaml
dependencies:
  real_page_flip:
    git:
      url: https://github.com/ChaPDCha/flutter_real_page_flip.git
      ref: main
```

Quick start

```dart
import 'package:flutter/material.dart';
import 'package:real_page_flip/page_flip.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  final PageFlipController _controller = PageFlipController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageFlipWidget(
        controller: _controller,
        itemCount: 3,
        config: const PageFlipConfig(
          enableSound: true,
          enableHaptics: true,
        ),
        itemBuilder: (context, index) {
          return Center(child: Text('Page ${index + 1}'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _controller.nextPage(),
        child: const Icon(Icons.navigate_next),
      ),
    );
  }
}
```

Programmatic control

Use `PageFlipController` with `PageFlipWidget`:

- `nextPage()` / `previousPage()` run a flip animation (unless `PageFlipConfig.skipTapAnimation` makes taps instant).
- `goToPage(index)` **jumps** to a page **without** a flip animation (see implementation in `PageFlipWidget`).

Sound, haptics, and custom effects

- Toggle defaults: `PageFlipConfig(enableSound: false)` or `enableHaptics: false`.
- Per-event hook: `PageFlipWidget(onHandleEffect: (event, {pageIndex, intensity, volume, texture, resistance, timestampMs}) { ... })` — when you set this, you take over handling for that event (the default handler is not used for those calls).
- Full replacement: `PageFlipConfig(effectHandler: MyHandler())` implementing `PageFlipEffectHandler`.

Layout constraints

If you embed the flip in unusual parents (nested scrollables, custom viewports), read [README_LAYOUT_CONSTRAINTS.md](README_LAYOUT_CONSTRAINTS.md) and the longer [doc/flutter_layout_constraints_guide.md](doc/flutter_layout_constraints_guide.md).

License

This project uses a **dual license**:

- **Non-commercial (free)**: personal projects, non-profit apps, academic tools — use, modify, and distribute under the terms in [LICENSE](LICENSE).
- **Commercial (paid)**: use in any product or service that **generates revenue or commercial benefit** — including paid apps, in-app purchases, advertising-supported apps, internal business tools sold or billed to customers, or SaaS — requires a **commercial license** from the copyright holder before use. See [LICENSE](LICENSE).

Korean text of the license: [LICENSE_KR](LICENSE_KR).

If you need a commercial license or have licensing questions, open an issue or contact the repository maintainer.
