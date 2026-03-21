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

Sensory Experience: Sound and Haptics
What truly sets this engine apart is the immersive sensory feedback. To complement the visual realism, we've integrated synchronized page-turning sounds and haptic feedback.
- **Physical Sound Effects**: Each flip triggers a high-quality, directional sound effect that mimics the rustle of a real page, varying naturally with the speed of your gesture.
- **Tactile Haptics**: Feel the friction and the "snap" of the paper through your device's haptic engine. These subtle vibrations are finely tuned to match the visual fold, making the digital experience feel incredibly solid and authentic.
- **Customizable Assets**: While a premium `page_flip.mp3` sound file is included as a default, the engine is fully modular. You can easily swap it for your own sound assets or provide a custom effect handler for complete brand control.

Getting Started 
To use this engine, you'll need at least Flutter 3.10.0. 

Simply add the dependency, instantiate the core widget, and pass in the list of pages you want to render. If you want to trigger page turns programmatically, you can maintain a reference to the internal widget state and call the transition methods directly. The engine will handle the complex asynchronous lifetimes of the animations for you.

Dual License and Usage
We offer a Dual License model for this project:

Free for Non-Commercial Use: If you are building a personal project, a non-profit app, or an academic tool, you are free to use, modify, and distribute this software at no cost.
Paid for Commercial Use: If you plan to use this library in a commercial product or any project that generates revenue, you must purchase a commercial license. 

For complete details, please check the LICENSE file. If you need a commercial license, feel free to reach out!
