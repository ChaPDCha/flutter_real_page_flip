import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/reader/application/pdf_service.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/pdf_page_renderer.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';

/// Valid 1×1 red pixel PNG bytes.
const _kRedPngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x02,
  0x00,
  0x00,
  0x00,
  0x90,
  0x77,
  0x53,
  0xDE,
  0x00,
  0x00,
  0x00,
  0x0C,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0xC9,
  0xFE,
  0x92,
  0xEF,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

/// The MethodChannel that pdfx uses for platform calls.
const _pdfxChannel = MethodChannel('io.scer.pdf_renderer');

Widget _buildPdfPageRenderer({
  required String filePath,
  required int pageIndex,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PdfPageRenderer(
        filePath: filePath,
        pageIndex: pageIndex,
        theme: ReaderThemeData.cream,
      ),
    ),
  );
}

void main() {
  group('PdfPageRenderer', () {
    const filePath = 'test_file.pdf';

    tearDown(() {
      PdfService.closeDocument(filePath);
    });

    testWidgets('shows loading indicator initially when no cache', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPdfPageRenderer(filePath: filePath, pageIndex: 0),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows image from cache without opening document', (
      tester,
    ) async {
      final dummyBytes = Uint8List.fromList(_kRedPngBytes);

      PdfService.cachePageImage(filePath, 0, dummyBytes);

      await tester.pumpWidget(
        _buildPdfPageRenderer(filePath: filePath, pageIndex: 0),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows error state when document fails to load', (
      tester,
    ) async {
      // Mock pdfx channel to throw so _renderPage catches an error.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _pdfxChannel,
        (MethodCall methodCall) async {
          throw PlatformException(
            code: 'file-not-found',
            message: 'No such file: /nonexistent/test.pdf',
          );
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _pdfxChannel,
          null,
        );
      });

      await tester.pumpWidget(
        _buildPdfPageRenderer(filePath: '/nonexistent/test.pdf', pageIndex: 0),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('updates when pageIndex changes', (tester) async {
      final dummyBytes = Uint8List.fromList(_kRedPngBytes);

      PdfService.cachePageImage(filePath, 0, dummyBytes);
      PdfService.cachePageImage(filePath, 1, dummyBytes);

      await tester.pumpWidget(
        _buildPdfPageRenderer(filePath: filePath, pageIndex: 0),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);

      await tester.pumpWidget(
        _buildPdfPageRenderer(filePath: filePath, pageIndex: 1),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows error text when platform call fails', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _pdfxChannel,
        (MethodCall methodCall) async {
          throw PlatformException(
            code: 'file-not-found',
            message: 'No such file: /fail/path.pdf',
          );
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _pdfxChannel,
          null,
        );
      });

      await tester.pumpWidget(
        _buildPdfPageRenderer(filePath: '/fail/path.pdf', pageIndex: 0),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('페이지를 로드할 수 없습니다'), findsOneWidget);
    });
  });
}
