// ignore_for_file: public_member_api_docs

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
      home: const DemoHost(),
    );
  }
}

class DemoHost extends StatelessWidget {
  const DemoHost({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Real Page Flip Engine'),
          centerTitle: true,
          elevation: 4,
          shadowColor: Colors.black26,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.book), text: 'Standard'),
              Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Stress Test'),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(), // Prevent swipe conflict
          children: [
            SimpleDemo(),
            HeavyLoadDemo(),
          ],
        ),
      ),
    );
  }
}

class SimpleDemo extends StatefulWidget {
  const SimpleDemo({super.key});

  @override
  State<SimpleDemo> createState() => _SimpleDemoState();
}

class _SimpleDemoState extends State<SimpleDemo> {
  final PageFlipController _controller = PageFlipController();
  int _currentPage = 0;

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
      backgroundColor: Colors.grey.shade200,
      body: PageFlipWidget(
        controller: _controller,
        itemCount: _pageColors.length,
        config: const PageFlipConfig(
          backgroundColor: Colors.white,
          enableSound: true,
          enableHaptics: true,
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
            heroTag: 'prev1',
            onPressed:
                _currentPage > 0 ? () => _controller.previousPage() : null,
            child: const Icon(Icons.arrow_back),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'next1',
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
          mainAxisAlignment: MainAxisAlignment.center,
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

class HeavyLoadDemo extends StatefulWidget {
  const HeavyLoadDemo({super.key});

  @override
  State<HeavyLoadDemo> createState() => _HeavyLoadDemoState();
}

class _HeavyLoadDemoState extends State<HeavyLoadDemo> {
  final PageFlipController _controller = PageFlipController();
  int _currentPage = 0;
  final int _totalPages = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageFlipWidget(
        controller: _controller,
        itemCount: _totalPages,
        config: const PageFlipConfig(
          backgroundColor: Colors.grey,
          enableSound: true,
          enableHaptics: true,
        ),
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        itemBuilder: (context, index) {
          return _buildHeavyPage(index);
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'prev2',
            backgroundColor: Colors.red.shade800,
            onPressed:
                _currentPage > 0 ? () => _controller.previousPage() : null,
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'next2',
            backgroundColor: Colors.red.shade800,
            onPressed: _currentPage < _totalPages - 1
                ? () => _controller.nextPage()
                : null,
            child: const Icon(Icons.arrow_forward, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildHeavyPage(int index) {
    // 50 complex cards per page to stress rendering
    return Container(
      color: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: 50,
        itemBuilder: (context, itemIndex) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 4,
            shadowColor: Colors.black38,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.primaries[
                          (index + itemIndex) % Colors.primaries.length],
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${index * 50 + itemIndex}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complex Item $itemIndex',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Page $index rendering load test with intricate widget trees.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: itemIndex % 2 == 0,
                    onChanged: (val) {},
                    activeThumbColor: Colors.red,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
