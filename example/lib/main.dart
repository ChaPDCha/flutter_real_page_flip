import 'package:flutter/material.dart';
import 'package:real_page_flip/real_page_flip.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real Page Flip Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        useMaterial3: true,
      ),
      home: const PageFlipShowcase(),
    );
  }
}

class PageFlipShowcase extends StatefulWidget {
  const PageFlipShowcase({super.key});

  @override
  State<PageFlipShowcase> createState() => _PageFlipShowcaseState();
}

class _PageFlipShowcaseState extends State<PageFlipShowcase> {
  final PageFlipController _controller = PageFlipController();
  
  // Config state
  bool _enableHaptics = true;
  bool _enableSound = true;
  double _sensitivity = 0.5;
  double _edgeTapRatio = 0.15;
  bool _skipTapAnimation = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real Page Flip Engine'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: PageFlipWidget(
            controller: _controller,
            config: PageFlipConfig(
              enableHaptics: _enableHaptics,
              enableSound: _enableSound,
              sensitivity: _sensitivity,
              edgeTapWidthRatio: _edgeTapRatio,
              skipTapAnimation: _skipTapAnimation,
              backgroundColor: const Color(0xFFF5F5F5),
            ),
            itemCount: 10,
            itemBuilder: (context, index) {
              return _buildPage(index);
            },
            onPageChanged: (page) {
              print('Page changed to: $page');
            },
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => _controller.previousPage(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Prev'),
            ),
            ElevatedButton.icon(
              onPressed: () => _controller.nextPage(),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    final colors = [
      Colors.blueGrey[50]!,
      Colors.orange[50]!,
      Colors.green[50]!,
      Colors.red[50]!,
      Colors.purple[50]!,
    ];
    
    final pageContent = [
      "The journey of a thousand miles begins with a single step. This engine brings that journey to life through tactile interaction.",
      "In the middle of every difficulty lies opportunity. Experience the smooth resistance of our physics-based paper modeling.",
      "Simplicity is the ultimate sophistication. Our API is designed to be powerful yet incredibly easy to integrate.",
      "Imagination is more important than knowledge. Visualize your content in a high-fidelity 3D-like flip environment.",
      "Quality is not an act, it is a habit. Every frame of this animation is calculated for maximum realism.",
      "Design is not just what it looks like and feels like. Design is how it works. And this engine works beautifully.",
      "The best way to predict the future is to create it. We are redefining reading experiences on mobile and web.",
      "Focus is a matter of deciding what things you're not going to do. We focused on the perfect flip, so you don't have to.",
      "Strive for excellence, not perfection. But in this engine, we've come pretty close to the perfect paper feel.",
      "The only limit to our realization of tomorrow will be our doubts of today. Flip the page to see what's next.",
    ];

    final color = colors[index % colors.length];
    final content = pageContent[index % pageContent.length];

    return Container(
      color: color,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'CHAPTER ${index + 1}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                content + "\n\n" + 
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
                'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
                'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris '
                'nisi ut aliquip ex ea commodo consequat.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black.withOpacity(0.8),
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '- Page ${index + 1} -',
            style: const TextStyle(fontWeight: FontWeight.w400, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Engine Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Haptic Feedback'),
                    value: _enableHaptics,
                    onChanged: (val) {
                      setState(() => _enableHaptics = val);
                      setModalState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Sound Effects'),
                    value: _enableSound,
                    onChanged: (val) {
                      setState(() => _enableSound = val);
                      setModalState(() {});
                    },
                  ),
                  const Text('Drag Sensitivity'),
                  Slider(
                    value: _sensitivity,
                    onChanged: (val) {
                      setState(() => _sensitivity = val);
                      setModalState(() {});
                    },
                  ),
                  const Text('Edge Tap Area Width'),
                  Slider(
                    value: _edgeTapRatio,
                    max: 0.4,
                    onChanged: (val) {
                      setState(() => _edgeTapRatio = val);
                      setModalState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Instant Tap Flip'),
                    value: _skipTapAnimation,
                    onChanged: (val) {
                      setState(() => _skipTapAnimation = val);
                      setModalState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
