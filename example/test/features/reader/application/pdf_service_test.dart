import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/reader/application/pdf_service.dart';

void main() {
  group('PdfService Page Image Cache Tests', () {
    setUp(() {
      // Clear cache before each test by simulated document closes
      PdfService.closeDocument('dummy_path_1');
      PdfService.closeDocument('dummy_path_2');
    });

    test('should cache and retrieve page image bytes correctly', () {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);
      
      PdfService.cachePageImage('dummy_path_1', 0, dummyBytes);
      
      final retrieved = PdfService.getCachedPageImage('dummy_path_1', 0);
      expect(retrieved, isNotNull);
      expect(retrieved, equals(dummyBytes));
    });

    test('should return null for non-existent cache keys', () {
      final retrieved = PdfService.getCachedPageImage('non_existent', 99);
      expect(retrieved, isNull);
    });

    test('should maintain maximum cache limit (40) and remove oldest item (FIFO)', () {
      // Fill cache to limit
      for (int i = 0; i < 40; i++) {
        PdfService.cachePageImage('dummy_path_1', i, Uint8List.fromList([i]));
      }

      // First item (page 0) must exist
      expect(PdfService.getCachedPageImage('dummy_path_1', 0), isNotNull);

      // Add 41st item
      PdfService.cachePageImage('dummy_path_1', 40, Uint8List.fromList([40]));

      // Oldest item (page 0) should be evicted due to size limit
      expect(PdfService.getCachedPageImage('dummy_path_1', 0), isNull);
      
      // Page 1 and Page 40 should still be intact
      expect(PdfService.getCachedPageImage('dummy_path_1', 1), isNotNull);
      expect(PdfService.getCachedPageImage('dummy_path_1', 40), isNotNull);
    });

    test('should only evict page images belonging to closed document', () {
      final bytes1 = Uint8List.fromList([10]);
      final bytes2 = Uint8List.fromList([20]);

      PdfService.cachePageImage('dummy_path_1', 1, bytes1);
      PdfService.cachePageImage('dummy_path_2', 1, bytes2);

      // Retrieve to verify initial state
      expect(PdfService.getCachedPageImage('dummy_path_1', 1), equals(bytes1));
      expect(PdfService.getCachedPageImage('dummy_path_2', 1), equals(bytes2));

      // Close document 1
      PdfService.closeDocument('dummy_path_1');

      // Document 1 cache should be deleted, but Document 2 cache must remain untouched
      expect(PdfService.getCachedPageImage('dummy_path_1', 1), isNull);
      expect(PdfService.getCachedPageImage('dummy_path_2', 1), equals(bytes2));
    });
  });
}
