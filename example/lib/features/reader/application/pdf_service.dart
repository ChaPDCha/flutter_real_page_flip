import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';
import '../../../shared/firebase/firebase_service.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  PdfService._internal();

  factory PdfService() => _instance;

  final Map<String, PdfDocument> _documentCache = {};
  final Map<String, Uint8List> _pageImageCache = {};
  int _currentCacheMemoryBytes = 0;

  static const int _maxCacheSize = 40;
  static const int _maxCacheMemoryBytes = 128 * 1024 * 1024; // 128 MB
  static const int _maxDocuments = 5;

  static String _cacheKey(String filePath, int pageIndex) =>
      '$filePath#$pageIndex';

  /// Retrieves a cached page image if it exists.
  static Uint8List? getCachedPageImage(String filePath, int pageIndex) {
    return _instance._pageImageCache[_cacheKey(filePath, pageIndex)];
  }

  /// Caches a rendered page image with count and memory-budget eviction.
  static void cachePageImage(String filePath, int pageIndex, Uint8List bytes) {
    final key = _cacheKey(filePath, pageIndex);

    // Remove existing entry first to avoid double-counting.
    final existing = _instance._pageImageCache.remove(key);
    if (existing != null) {
      _instance._currentCacheMemoryBytes -= existing.length;
    }

    // Evict oldest entries while over count or memory budget.
    while (_instance._pageImageCache.isNotEmpty &&
        (_instance._pageImageCache.length >= _maxCacheSize ||
            _instance._currentCacheMemoryBytes + bytes.length >
                _maxCacheMemoryBytes)) {
      final firstKey = _instance._pageImageCache.keys.first;
      final removed = _instance._pageImageCache.remove(firstKey);
      if (removed != null) {
        _instance._currentCacheMemoryBytes -= removed.length;
      }
    }

    _instance._currentCacheMemoryBytes += bytes.length;
    _instance._pageImageCache[key] = bytes;
  }

  /// Retrieves an opened PdfDocument from cache or opens a new one.
  static Future<PdfDocument> getOrOpenDocument(String filePath) async {
    if (_instance._documentCache.containsKey(filePath)) {
      return _instance._documentCache[filePath]!;
    }

    // Evict oldest document if at capacity
    if (_instance._documentCache.length >= _maxDocuments) {
      final oldestKey = _instance._documentCache.keys.first;
      final oldDoc = _instance._documentCache.remove(oldestKey);
      if (oldDoc != null) {
        try {
          await oldDoc.close();
        } catch (_) {
          // Ignore close errors on evicted documents
        }
      }
      // Also evict page images for the evicted document
      _instance._pageImageCache.removeWhere(
        (key, _) => key.startsWith('$oldestKey#'),
      );
    }

    final document = await PdfDocument.openFile(filePath);
    _instance._documentCache[filePath] = document;
    return document;
  }

  /// Closes and removes a cached document when a book is closed.
  static Future<void> closeDocument(String filePath) async {
    final document = _instance._documentCache.remove(filePath);
    if (document != null) {
      try {
        await document.close();
      } catch (e, st) {
        FirebaseService.recordError(e, st, reason: 'PDF document close');
      }
    }
    // Remove all cached page images for this file
    _instance._pageImageCache.removeWhere(
      (key, _) => key.startsWith('$filePath#'),
    );
  }

  /// Retrieves the page count of a PDF file.
  Future<int> getPagesCount(String filePath) async {
    final document = await getOrOpenDocument(filePath);
    return document.pagesCount;
  }

  /// Checks if the PDF document has a landscape (horizontal) aspect ratio.
  static Future<bool> isLandscapeDocument(String filePath) async {
    try {
      final document = await getOrOpenDocument(filePath);
      if (document.pagesCount > 0) {
        final page = await document.getPage(1);
        try {
          final isLandscape = page.width > page.height;
          return isLandscape;
        } finally {
          await page.close();
        }
      }
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'PDF landscape check');
      return false;
    }
    return false;
  }
}
