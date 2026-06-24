import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';
import '../../../shared/firebase/firebase_service.dart';

class PdfService {
  static final Map<String, PdfDocument> _documentCache = {};
  static final Map<String, Uint8List> _pageImageCache = {};
  static const int _maxCacheSize = 40;

  static String _cacheKey(String filePath, int pageIndex) =>
      '$filePath#$pageIndex';

  /// Retrieves a cached page image if it exists.
  static Uint8List? getCachedPageImage(String filePath, int pageIndex) {
    return _pageImageCache[_cacheKey(filePath, pageIndex)];
  }

  /// Caches a rendered page image.
  static void cachePageImage(String filePath, int pageIndex, Uint8List bytes) {
    final key = _cacheKey(filePath, pageIndex);
    if (_pageImageCache.length >= _maxCacheSize) {
      final firstKey = _pageImageCache.keys.first;
      _pageImageCache.remove(firstKey);
    }
    _pageImageCache[key] = bytes;
  }

  /// Retrieves an opened PdfDocument from cache or opens a new one.
  static Future<PdfDocument> getOrOpenDocument(String filePath) async {
    if (_documentCache.containsKey(filePath)) {
      return _documentCache[filePath]!;
    }
    final document = await PdfDocument.openFile(filePath);
    _documentCache[filePath] = document;
    return document;
  }

  /// Closes and removes a cached document when a book is closed.
  static Future<void> closeDocument(String filePath) async {
    final document = _documentCache.remove(filePath);
    if (document != null) {
      try {
        await document.close();
      } catch (e, st) {
        FirebaseService.recordError(e, st, reason: 'PDF document close');
      }
    }
    // Remove all cached page images for this file
    _pageImageCache.removeWhere((key, _) => key.startsWith('$filePath#'));
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
        final isLandscape = page.width > page.height;
        await page.close();
        return isLandscape;
      }
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'PDF landscape check');
      return false;
    }
    return false;
  }
}
