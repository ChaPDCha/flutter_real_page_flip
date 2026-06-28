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
      title: 'Page Flip Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const PageFlipDemo(),
    );
  }
}

class PageFlipDemo extends StatefulWidget {
  const PageFlipDemo({super.key});

  @override
  State<PageFlipDemo> createState() => _PageFlipDemoState();
}

class _PageFlipDemoState extends State<PageFlipDemo> {
  final List<String> pages = List.generate(10, (index) => 'Page ${index + 1}');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real Page Flip Demo'),
        elevation: 2,
      ),
      body: Center(
        child: Container(
          width: 500,
          height: 700,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: PageFlipWidget(
            itemCount: pages.length,
            isDoubleSpread: false, // Set to true for side-by-side spread
            config: const PageFlipConfig(
              backgroundColor: Colors.white,
              // Configure performance/visual balance here
            ),
            itemBuilder: (context, index) {
              return Card(
                margin: EdgeInsets.zero,
                color: Colors.primaries[index % Colors.primaries.length].shade100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        pages[index],
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Text(
                          'Swipe from the right edge to turn forward, or swipe from the left edge to turn backward.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
