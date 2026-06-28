import 'dart:ui';
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
      title: 'Real Page Flip Premium Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F16),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
          primary: const Color(0xFF6C63FF),
          secondary: const Color(0xFFFF6584),
          surface: const Color(0xFF1E1E2F),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Roboto',
            ),
      ),
      home: const PremiumDemoScreen(),
    );
  }
}

class PremiumDemoScreen extends StatefulWidget {
  const PremiumDemoScreen({super.key});

  @override
  State<PremiumDemoScreen> createState() => _PremiumDemoScreenState();
}

class _PremiumDemoScreenState extends State<PremiumDemoScreen> {
  // PageFlip Config parameters
  double _sensitivity = 1.0;
  double _paperOpacity = 0.9;
  double _thinPaperStrength = 0.2;
  double _flapContentRevealStart = 0.85;
  double _flapContentRevealEnd = 0.95;
  bool _enableHaptics = true;
  bool _enableSound = true;
  bool _isDoubleSpread = false;
  bool _isRightSwipe = false;
  bool _enableSwipe = true;
  DevicePerformanceProfile _performanceProfile = DevicePerformanceProfile.high;
  PaperTexturePreset _hapticPreset = PaperTexturePreset.standard;
  bool _showTuningDeck = false;
  bool _autoPlay = true;

  // Controller to monitor state
  late PageFlipController _controller;
  int _currentPage = 0;
  String _animStatus = 'Idle';

  @override
  void initState() {
    super.initState();
    _controller = PageFlipController();
    _startAutoPlay();
  }

  void _startAutoPlay() async {
    // Settle time
    await Future.delayed(const Duration(seconds: 4));
    if (!_autoPlay || !mounted) return;

    // Single-page mode flips
    _controller.nextPage();
    await Future.delayed(const Duration(seconds: 3));
    if (!_autoPlay || !mounted) return;
    _controller.nextPage();
    await Future.delayed(const Duration(seconds: 3));
    if (!_autoPlay || !mounted) return;
    _controller.previousPage();
    await Future.delayed(const Duration(seconds: 4));
    if (!_autoPlay || !mounted) return;

    // Switch to Double Spread
    setState(() {
      _isDoubleSpread = true;
    });
    await Future.delayed(const Duration(seconds: 4));
    if (!_autoPlay || !mounted) return;

    // Double-spread mode flips
    _controller.nextPage();
    await Future.delayed(const Duration(seconds: 3));
    if (!_autoPlay || !mounted) return;
    _controller.nextPage();
    await Future.delayed(const Duration(seconds: 3));
    if (!_autoPlay || !mounted) return;
    _controller.previousPage();
    await Future.delayed(const Duration(seconds: 4));
    if (!_autoPlay || !mounted) return;

    // Settle back to original
    setState(() {
      _isDoubleSpread = false;
      _autoPlay = false;
    });
    _controller.goToPage(0);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 950;

    return Scaffold(
      body: Stack(
        children: [
          // Background cool gradient shapes
          Positioned(
            top: -200,
            right: -200,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                    blurRadius: 120,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6584).withValues(alpha: 0.12),
                    blurRadius: 100,
                  ),
                ],
              ),
            ),
          ),

          // Main Responsive Layout with top bar
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _showTuningDeck
                      ? (isWide ? _buildWideLayout() : _buildNarrowLayout())
                      : _buildFullscreenBookLayout(isWide),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161623).withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: App Name
          Row(
            children: [
              const Icon(Icons.menu_book, color: Color(0xFF6C63FF), size: 24),
              const SizedBox(width: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                ).createShader(bounds),
                child: const Text(
                  'ANTIGRAVITY FLIP',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          // Center: Layout option toggles
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildLayoutOption(
                  icon: Icons.article,
                  label: '1-Column (Single Page)',
                  isSelected: !_isDoubleSpread,
                  onTap: () {
                    setState(() {
                      _isDoubleSpread = false;
                      _autoPlay = false; // Stop autoplay on layout tap
                    });
                  },
                ),
                _buildLayoutOption(
                  icon: Icons.auto_stories,
                  label: '2-Column (Double Spread)',
                  isSelected: _isDoubleSpread,
                  onTap: () {
                    setState(() {
                      _isDoubleSpread = true;
                      _autoPlay = false; // Stop autoplay on layout tap
                    });
                  },
                ),
              ],
            ),
          ),
          // Right: Tuning deck toggle
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showTuningDeck = !_showTuningDeck;
                _autoPlay = false; // Stop autoplay on settings tap
              });
            },
            icon: Icon(
              _showTuningDeck ? Icons.visibility : Icons.tune,
              color: _showTuningDeck ? const Color(0xFFFF6584) : const Color(0xFF6C63FF),
              size: 20,
            ),
            label: Text(
              _showTuningDeck ? 'Hide Control Deck' : 'Show Control Deck',
              style: TextStyle(
                color: _showTuningDeck ? const Color(0xFFFF6584) : const Color(0xFF6C63FF),
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: _showTuningDeck 
                  ? const Color(0xFFFF6584).withValues(alpha: 0.1)
                  : const Color(0xFF6C63FF).withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _showTuningDeck 
                      ? const Color(0xFFFF6584).withValues(alpha: 0.2)
                      : const Color(0xFF6C63FF).withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade400,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade400,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenBookLayout(bool isWide) {
    final double maxWidth = _isDoubleSpread ? 1200 : 540;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: 760,
                ),
                child: _buildBookTheatre(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: _buildStatusBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left Column: Controller panel
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _buildControlPanel(),
          ),
        ),
        // Right Column: E-Book viewport
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: _buildBookTheatre()),
                const SizedBox(height: 16),
                _buildStatusBar(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: _buildBookTheatre(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildStatusBar(),
        ),
        const Divider(color: Colors.white10),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: _buildControlPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          ).createShader(bounds),
          child: const Text(
            'ANTIGRAVITY FLIP',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Physics-based Curvature Page Flip Engine',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildBookTheatre() {
    // Elegant frame representing a physical tablet/device
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: PageFlipWidget(
          controller: _controller,
          itemCount: 6,
          isDoubleSpread: _isDoubleSpread,
          initialIndex: _currentPage,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          onFlipStart: () {
            setState(() {
              _animStatus = 'Animating';
              _autoPlay = false; // Stop autoplay on manual swipe
            });
          },
          onFlipEnd: () {
            setState(() {
              _animStatus = 'Idle';
            });
          },
          config: PageFlipConfig(
            sensitivity: _sensitivity,
            paperOpacity: _paperOpacity,
            thinPaperStrength: _thinPaperStrength,
            flapContentRevealStart: _flapContentRevealStart,
            flapContentRevealEnd: _flapContentRevealEnd,
            enableHaptics: _enableHaptics,
            enableSound: _enableSound,
            isRightSwipe: _isRightSwipe,
            enableSwipe: _enableSwipe,
            performanceProfile: _performanceProfile,
            hapticTexturePreset: _hapticPreset,
            backgroundColor: const Color(0xFF161623),
          ),
          itemBuilder: (context, index) {
            return _buildBookPage(index);
          },
        ),
      ),
    );
  }

  Widget _buildBookPage(int index) {
    switch (index) {
      case 0:
        return _buildCoverPage();
      case 1:
        return _buildIntroductionPage();
      case 2:
        return _buildDashboardPage();
      case 3:
        return _buildCodePlayground();
      case 4:
        return _buildTypographyPage();
      case 5:
        return _buildBackCover();
      default:
        return Container();
    }
  }

  // --- Curated Book Pages ( 간지나는 디자인 ) ---

  Widget _buildCoverPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1335), Color(0xFF0F081D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Geometric decoration
          Positioned(
            top: 40,
            left: 40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFF6584).withValues(alpha: 0.15), width: 1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            right: -20,
            child: Transform.rotate(
              angle: 0.7,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.15), width: 1.5),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFFFF6584), size: 16),
                    SizedBox(width: 8),
                    Text(
                      'PORTFOLIO MAGAZINE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Color(0xFFFF6584),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THE ART OF\nANTIGRAVITY',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -1.0,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [Color(0xFFFFFFFF), Color(0xFFB1B1CF)],
                          ).createShader(const Rect.fromLTWH(0.0, 0.0, 300.0, 100.0)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 60,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Exploring advanced rendering physics, GPU mesh-caching, and tactical device optimization under Flutter.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  'PUBLISHED BY CHAPDCHA \u2022 VOL. I',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroductionPage() {
    return Container(
      color: const Color(0xFF161623),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '01 / BACKGROUND',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C63FF),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pushing Limits',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade100,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'The Antigravity Engine elevates traditional page flip shaders into full physics-based simulations. We model paper fold geometry, haptic stick-slip tension, and shadow falloffs as differential properties rather than cheap static masks.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'By implementing Adaptive Mesh Optimization (AMO), the GPU automatically skips high-cost rendering operations during visual transition zones on lower-profile devices, keeping fluid 60FPS active everywhere.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardPage() {
    return Container(
      color: const Color(0xFF181827),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '02 / METRICS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF6584),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Telemetry & AMO',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade100,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricsCard('Mesh Complexity', '120 vertices (curved)', Colors.blueAccent),
          const SizedBox(height: 10),
          _buildMetricsCard('Render Latency', '0.84 ms / frame', Colors.greenAccent),
          const SizedBox(height: 10),
          _buildMetricsCard('AMO Efficiency', 'Skip rates up to 74%', Colors.purpleAccent),
          const SizedBox(height: 16),
          Text(
            'AMO modulates clipping matrices depending on current screen coordinate bounds, securing consistent performance.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.4),
          )
        ],
      ),
    );
  }

  Widget _buildMetricsCard(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
              const SizedBox(width: 8),
              Text(val, style: TextStyle(fontSize: 13, color: Colors.grey.shade300, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCodePlayground() {
    return Container(
      color: const Color(0xFF131320),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '03 / PLAYGROUND',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8E2DE2),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Initialization',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade100,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: SingleChildScrollView(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontFamily: 'monospace', fontSize: 10, height: 1.5),
                    children: [
                      TextSpan(text: 'PageFlipWidget', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
                      TextSpan(text: '(\n'),
                      TextSpan(text: '  controller: controller,\n'),
                      TextSpan(text: '  config: PageFlipConfig(\n', style: TextStyle(color: Colors.tealAccent)),
                      TextSpan(text: '    sensitivity: 1.0,\n', style: TextStyle(color: Colors.orangeAccent)),
                      TextSpan(text: '    paperOpacity: 0.9,\n', style: TextStyle(color: Colors.orangeAccent)),
                      TextSpan(text: '    performanceProfile:\n'),
                      TextSpan(text: '      DevicePerformanceProfile.high,\n', style: TextStyle(color: Colors.purpleAccent)),
                      TextSpan(text: '  ),\n'),
                      TextSpan(text: '  itemBuilder: (context, idx) =>\n'),
                      TextSpan(text: '    YourBookPage(idx),\n', style: TextStyle(color: Colors.greenAccent)),
                      TextSpan(text: ');'),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTypographyPage() {
    return Container(
      color: const Color(0xFF161623),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '04 / CREATIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF6584),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '“',
            style: TextStyle(fontSize: 48, fontFamily: 'serif', color: Color(0xFF6C63FF), height: 0.8),
          ),
          const Text(
            'The paper curves, the shadows blend,\nA virtual touch that has no end.\nGravity pulls, friction holds,\nAs a brand new chapter unfolds.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              height: 1.8,
              fontFamily: 'serif',
              color: Color(0xE6FFFFFF),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '— ODE TO DART PHYSICS',
            style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
          )
        ],
      ),
    );
  }

  Widget _buildBackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F081D), Color(0xFF07040F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
                border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.import_contacts_sharp,
                size: 40,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ANTIGRAVITY ENGINE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Next-gen flip shader for Flutter',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Star on GitHub',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Control Deck UI ( Glassmorphic ) ---

  Widget _buildControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, color: Color(0xFF6C63FF), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'CONTROL DECK',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Performance Profile Selector
                _buildSectionTitle('Device Performance Optimization (AMO)'),
                _buildSegmentedButton<DevicePerformanceProfile>(
                  selectedValue: _performanceProfile,
                  values: DevicePerformanceProfile.values,
                  labelBuilder: (profile) => profile.name.toUpperCase(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _performanceProfile = val);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Physics Toggles
                _buildSectionTitle('Flip Dynamics'),
                _buildSlider(
                  label: 'Swipe Sensitivity',
                  val: _sensitivity,
                  min: 0.1,
                  max: 2.0,
                  onChanged: (v) => setState(() => _sensitivity = v),
                ),
                _buildSlider(
                  label: 'Paper Opacity',
                  val: _paperOpacity,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (v) => setState(() => _paperOpacity = v),
                ),
                _buildSlider(
                  label: 'Thin Paper Transparency Strength',
                  val: _thinPaperStrength,
                  min: 0.0,
                  max: 0.8,
                  onChanged: (v) => setState(() => _thinPaperStrength = v),
                ),
                const SizedBox(height: 20),

                // Flap Content Reveal Thresholds
                _buildSectionTitle('Flap Reveal Bounds'),
                _buildSlider(
                  label: 'Content Reveal Start Progress',
                  val: _flapContentRevealStart,
                  min: 0.5,
                  max: 0.95,
                  onChanged: (v) {
                    setState(() {
                      _flapContentRevealStart = v;
                      if (_flapContentRevealEnd < _flapContentRevealStart) {
                        _flapContentRevealEnd = _flapContentRevealStart + 0.02;
                      }
                    });
                  },
                ),
                _buildSlider(
                  label: 'Content Reveal End Progress',
                  val: _flapContentRevealEnd,
                  min: 0.55,
                  max: 0.99,
                  onChanged: (v) {
                    setState(() {
                      _flapContentRevealEnd = v;
                      if (_flapContentRevealStart > _flapContentRevealEnd) {
                        _flapContentRevealStart = _flapContentRevealEnd - 0.02;
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Haptic Texture Selector
                _buildSectionTitle('Haptic Paper Texture Feedback'),
                _buildSegmentedButton<PaperTexturePreset>(
                  selectedValue: _hapticPreset,
                  values: PaperTexturePreset.values,
                  labelBuilder: (preset) => preset.name.toUpperCase(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _hapticPreset = val);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Feature Switches
                _buildSectionTitle('Configurations'),
                _buildToggle('Double-spread Mode', _isDoubleSpread, (v) => setState(() => _isDoubleSpread = v)),
                _buildToggle('Haptic Feedback (Stick-Slip)', _enableHaptics, (v) => setState(() => _enableHaptics = v)),
                _buildToggle('Sound FX (Paper Friction)', _enableSound, (v) => setState(() => _enableSound = v)),
                _buildToggle('Right-to-Left (RTL) Swipe', _isRightSwipe, (v) => setState(() => _isRightSwipe = v)),
                _buildToggle('Enable Gesture Swipe', _enableSwipe, (v) => setState(() => _enableSwipe = v)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade400,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double val,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade300)),
              Text(val.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF6584))),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF6C63FF),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: const Color(0xFFFF6584),
              overlayColor: const Color(0xFFFF6584).withValues(alpha: 0.12),
              trackHeight: 3.0,
            ),
            child: Slider(
              value: val,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool val, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade300)),
          Switch(
            value: val,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedButton<T>({
    required T selectedValue,
    required List<T> values,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: values.map((val) {
          final isSelected = val == selectedValue;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  labelBuilder(val),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Real-time Status Bar ---

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem(Icons.menu_book, 'Page', '${_currentPage + 1} / 6'),
          _buildStatusItem(Icons.settings_suggest, 'AMO Profiling', _performanceProfile.name.toUpperCase()),
          _buildStatusItem(Icons.bolt, 'Engine', _animStatus),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF6584), size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
