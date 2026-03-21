import 'package:flutter/material.dart';
import 'package:real_page_flip/page_flip.dart';

void main() {
  runApp(const RealPageFlipExampleApp());
}

class RealPageFlipExampleApp extends StatelessWidget {
  const RealPageFlipExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real Page Flip Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const PageFlipDemoHome(),
    );
  }
}

class PageFlipDemoHome extends StatefulWidget {
  const PageFlipDemoHome({super.key});

  @override
  State<PageFlipDemoHome> createState() => _PageFlipDemoHomeState();
}

class _PageFlipDemoHomeState extends State<PageFlipDemoHome> {
  final PageFlipController _controller = PageFlipController();
  int _currentPage = 0;

  // Premium sample content
  final List<Color> _pageColors = [
    Colors.teal.shade50,
    Colors.orange.shade50,
    Colors.blue.shade50,
    Colors.purple.shade50,
    Colors.green.shade50,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real Page Flip Engine'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: PageFlipWidget(
        controller: _controller,
        itemCount: _pageColors.length,
        config: const PageFlipConfig(
          backgroundColor: Colors.white,
          enableSound: true,
          enableHaptics: true,
          // You can also pass a custom PageFlipEffectHandler() here
        ),
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        itemBuilder: (context, index) {
          return _buildPage(index);
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'prev',
            onPressed: _currentPage > 0 ? () => _controller.previousPage() : null,
            child: const Icon(Icons.arrow_back),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'next',
            onPressed: _currentPage < _pageColors.length - 1
                ? () => _controller.nextPage()
                : null,
            child: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    return Container(
      color: _pageColors[index],
      child: Center(
        child: Column(
          mainAxisAlignment: Main--;(MainAxisAlignment.center),
          children: [
            Text(
              'Page ${index + 1}',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _getSampleText(index),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      color: Colors.black54,
                    ),
              ),
            ),
            if (index == 0) ...[
              const SizedBox(height: 48),
              const Icon(Icons.swipe, size: 48, color: Colors.teal),
              const SizedBox(height: 8),
              const Text('Try swiping the edge!'),
            ]
          ],
        ),
      ),
    );
  }

  String _getSampleText(int index) {
    const texts = [
      "Experience the tactile feel of physical paper. Our engine uses real physics to calculate shadows and highlights.",
      "Integrated sound effects and haptic feedback provide a deep, immersive sensory experience on every flip.",
      "Engineered for high performance. Stable 60FPS across all mobile platforms with robust layout management.",
      "Fully customizable. Swap out sound assets or implement your own effect handlers to match your brand.",
      "Thank you for trying out Real Page Flip. We hope you build something beautiful with it!",
    ];
    return texts[index % texts.length];
  }
}
