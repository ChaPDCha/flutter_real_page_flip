import 'package:flutter/material.dart';

class EpubPagingCalculator {
  static final Map<String, List<String>> _pageCache = {};
  static const int _maxCacheSize = 60;

  @visibleForTesting
  static void clearCache() => _pageCache.clear();

  static void _cachePut(String key, List<String> pages) {
    if (_pageCache.length >= _maxCacheSize) {
      // Evict oldest entry (insertion-ordered map)
      _pageCache.remove(_pageCache.keys.first);
    }
    _pageCache[key] = pages;
  }

  static String _cacheKey({
    required String text,
    required double viewportWidth,
    required double viewportHeight,
    required double fontSize,
    required double lineHeight,
    required TextStyle baseStyle,
  }) {
    // Use text prefix + length as a collision-resistant key instead of .hashCode
    final textPrefix = text.length > 200 ? text.substring(0, 200) : text;
    return '${text.length}:$textPrefix|'
        '${viewportWidth.toStringAsFixed(1)}|'
        '${viewportHeight.toStringAsFixed(1)}|'
        '$fontSize|$lineHeight|'
        '${baseStyle.color?.toARGB32()}|'
        '${baseStyle.fontFamily}|'
        '${baseStyle.letterSpacing}|'
        '${baseStyle.fontWeight?.value}';
  }

  /// Splits chapter text on the root isolate ([TextPainter] is not isolate-safe).
  static Future<List<String>> splitIntoPagesAsync({
    required String text,
    required double viewportWidth,
    required double viewportHeight,
    required double fontSize,
    required double lineHeight,
    required TextStyle baseStyle,
  }) async {
    final cacheKey = _cacheKey(
      text: text,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      fontSize: fontSize,
      lineHeight: lineHeight,
      baseStyle: baseStyle,
    );
    final cached = _pageCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    // Yield once so callers awaiting pagination can repaint loading UI.
    await Future<void>.delayed(Duration.zero);

    final pages = splitIntoPages(
      text: text,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      fontSize: fontSize,
      lineHeight: lineHeight,
      baseStyle: baseStyle,
      useCache: false,
    );

    _cachePut(cacheKey, pages);
    return pages;
  }

  /// Splits the text of a chapter into pages based on display constraints.
  static List<String> splitIntoPages({
    required String text,
    required double viewportWidth,
    required double viewportHeight,
    required double fontSize,
    required double lineHeight,
    required TextStyle baseStyle,
    bool useCache = true,
  }) {
    if (text.trim().isEmpty) {
      return [''];
    }

    if (useCache) {
      final cacheKey = _cacheKey(
        text: text,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        fontSize: fontSize,
        lineHeight: lineHeight,
        baseStyle: baseStyle,
      );
      final cached = _pageCache[cacheKey];
      if (cached != null) {
        return cached;
      }
    }

    final pages = _splitIntoPagesImpl(
      text: text,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      fontSize: fontSize,
      lineHeight: lineHeight,
      baseStyle: baseStyle,
    );

    if (useCache) {
      _cachePut(
        _cacheKey(
          text: text,
          viewportWidth: viewportWidth,
          viewportHeight: viewportHeight,
          fontSize: fontSize,
          lineHeight: lineHeight,
          baseStyle: baseStyle,
        ),
        pages,
      );
    }

    return pages;
  }

  static List<String> _splitIntoPagesImpl({
    required String text,
    required double viewportWidth,
    required double viewportHeight,
    required double fontSize,
    required double lineHeight,
    required TextStyle baseStyle,
  }) {
    final pages = <String>[];
    int startOffset = 0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    final resolvedStyle = baseStyle.copyWith(
      fontSize: fontSize,
      height: lineHeight,
    );

    final double charArea =
        fontSize * fontSize * 0.45 * (lineHeight > 0 ? lineHeight : 1.2);
    final double viewportArea = viewportWidth * viewportHeight;
    final int expectedChars = (viewportArea / charArea).toInt();

    final int maxCharsPerPage = (expectedChars * 2.2).toInt().clamp(1000, 5000);
    final int minCharsPerPage = (expectedChars * 0.4).toInt().clamp(100, 2000);

    while (startOffset < text.length) {
      while (startOffset < text.length) {
        final codeUnit = text.codeUnitAt(startOffset);
        if (codeUnit != 0x20 &&
            codeUnit != 0x0A &&
            codeUnit != 0x0D &&
            codeUnit != 0x09) {
          break;
        }
        startOffset++;
      }
      if (startOffset >= text.length) {
        break;
      }

      final int remainingLength = text.length - startOffset;

      if (remainingLength <= maxCharsPerPage) {
        final adjustedEnd = text.length;
        textPainter.text = TextSpan(
          text: text.substring(startOffset, adjustedEnd),
          style: resolvedStyle,
        );
        textPainter.layout(maxWidth: viewportWidth);
        if (textPainter.height <= viewportHeight) {
          pages.add(text.substring(startOffset, adjustedEnd).trim());
          break;
        }
      }

      int low = startOffset;
      int high = (startOffset + maxCharsPerPage).clamp(
        startOffset,
        text.length,
      );

      int minEnd = startOffset + minCharsPerPage;
      if (minEnd < high) {
        final prevUnit = text.codeUnitAt(minEnd - 1);
        if (prevUnit >= 0xD800 && prevUnit <= 0xDBFF) {
          minEnd--;
        }

        textPainter.text = TextSpan(
          text: text.substring(startOffset, minEnd),
          style: resolvedStyle,
        );
        textPainter.layout(maxWidth: viewportWidth);

        if (textPainter.height <= viewportHeight) {
          low = minEnd;
        }
      }

      int bestEnd = low;

      while (low <= high) {
        int mid = (low + high) ~/ 2;

        int adjustedMid = mid;
        if (adjustedMid > startOffset && adjustedMid < text.length) {
          final prevUnit = text.codeUnitAt(adjustedMid - 1);
          if (prevUnit >= 0xD800 && prevUnit <= 0xDBFF) {
            adjustedMid--;
          }
        }

        final subText = text.substring(startOffset, adjustedMid);

        textPainter.text = TextSpan(text: subText, style: resolvedStyle);

        textPainter.layout(maxWidth: viewportWidth);

        if (textPainter.height <= viewportHeight) {
          bestEnd = adjustedMid;
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }

      if (bestEnd == startOffset) {
        bestEnd = startOffset + 1;
      }

      if (bestEnd < text.length) {
        int boundary = bestEnd;
        while (boundary > startOffset && (bestEnd - boundary) < 50) {
          final char = text[boundary - 1];
          if (char == ' ' || char == '\n') {
            bestEnd = boundary;
            break;
          }
          boundary--;
        }
      }

      if (bestEnd > startOffset && bestEnd < text.length) {
        final prevUnit = text.codeUnitAt(bestEnd - 1);
        if (prevUnit >= 0xD800 && prevUnit <= 0xDBFF) {
          bestEnd--;
        }
      }

      final pageText = text.substring(startOffset, bestEnd).trim();
      if (pageText.isNotEmpty) {
        pages.add(pageText);
      }
      startOffset = bestEnd;
    }

    if (pages.isEmpty) {
      return [''];
    }

    return pages;
  }
}
