import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Serializable paging input for [compute] isolates.
@immutable
class EpubPagingParams {
  const EpubPagingParams({
    required this.text,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.fontSize,
    required this.lineHeight,
    required this.textColorArgb,
    this.fontFamily,
  });

  final String text;
  final double viewportWidth;
  final double viewportHeight;
  final double fontSize;
  final double lineHeight;
  final int textColorArgb;
  final String? fontFamily;
}

List<String> _splitIntoPagesIsolate(EpubPagingParams params) {
  return EpubPagingCalculator.splitIntoPages(
    text: params.text,
    viewportWidth: params.viewportWidth,
    viewportHeight: params.viewportHeight,
    fontSize: params.fontSize,
    lineHeight: params.lineHeight,
    baseStyle: TextStyle(
      fontSize: params.fontSize,
      height: params.lineHeight,
      color: Color(params.textColorArgb),
      fontWeight: FontWeight.w400,
      letterSpacing: -0.2,
      fontFamily: params.fontFamily,
    ),
    useCache: false,
  );
}

class EpubPagingCalculator {
  static final Map<String, List<String>> _pageCache = {};

  @visibleForTesting
  static void clearCache() => _pageCache.clear();

  static String _cacheKey({
    required String text,
    required double viewportWidth,
    required double viewportHeight,
    required double fontSize,
    required double lineHeight,
    required TextStyle baseStyle,
  }) {
    return '${text.hashCode}|'
        '${viewportWidth.toStringAsFixed(1)}|'
        '${viewportHeight.toStringAsFixed(1)}|'
        '$fontSize|$lineHeight|'
        '${baseStyle.color?.value}|'
        '${baseStyle.fontFamily}|'
        '${baseStyle.letterSpacing}|'
        '${baseStyle.fontWeight?.index}';
  }

  /// Splits chapter text off the UI thread for long chapters.
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

    // Isolate spawn overhead dominates for short chapters.
    if (text.length < 8000) {
      return splitIntoPages(
        text: text,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        fontSize: fontSize,
        lineHeight: lineHeight,
        baseStyle: baseStyle,
      );
    }

    final params = EpubPagingParams(
      text: text,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      fontSize: fontSize,
      lineHeight: lineHeight,
      textColorArgb: baseStyle.color?.value ?? 0xFF000000,
      fontFamily: baseStyle.fontFamily,
    );
    final pages = await compute(_splitIntoPagesIsolate, params);
    _pageCache[cacheKey] = pages;
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
      _pageCache[_cacheKey(
        text: text,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        fontSize: fontSize,
        lineHeight: lineHeight,
        baseStyle: baseStyle,
      )] = pages;
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

    // Calculate expected characters per page and safe bounds
    final double charArea = fontSize * fontSize * 0.45 * (lineHeight > 0 ? lineHeight : 1.2);
    final double viewportArea = viewportWidth * viewportHeight;
    final int expectedChars = (viewportArea / charArea).toInt();
    
    // Tighter, mathematically-backed bounds
    final int maxCharsPerPage = (expectedChars * 2.2).toInt().clamp(1000, 5000);
    final int minCharsPerPage = (expectedChars * 0.4).toInt().clamp(100, 2000);

    while (startOffset < text.length) {
      // Skip whitespace between pages so paragraph gaps do not become blank pages.
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

      // OPTIMIZATION 1: Shortcut for short chapters or final page
      if (remainingLength <= maxCharsPerPage) {
        // Safe check for surrogate pairs at the end
        int adjustedEnd = text.length;
        textPainter.text = TextSpan(
          text: text.substring(startOffset, adjustedEnd),
          style: resolvedStyle,
        );
        textPainter.layout(maxWidth: viewportWidth);
        if (textPainter.height <= viewportHeight) {
          pages.add(text.substring(startOffset, adjustedEnd).trim());
          break; // Completed
        }
      }

      int low = startOffset;
      int high = (startOffset + maxCharsPerPage).clamp(startOffset, text.length);

      // OPTIMIZATION 2: Predictive lower-bound shift
      // Verify if our predicted minimum character chunk fits on the page in a single layout
      int minEnd = startOffset + minCharsPerPage;
      if (minEnd < high) {
        // Adjust minEnd to keep surrogate pair together
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
          // If the minimum chunk fits, we skip binary search for anything smaller
          low = minEnd;
        }
      }

      int bestEnd = low;

      // Binary search to find the maximum substring length that fits the height
      while (low <= high) {
        int mid = (low + high) ~/ 2;
        
        // Safeguard: Align mid to avoid splitting UTF-16 surrogate pairs during binary search
        int adjustedMid = mid;
        if (adjustedMid > startOffset && adjustedMid < text.length) {
          final prevUnit = text.codeUnitAt(adjustedMid - 1);
          if (prevUnit >= 0xD800 && prevUnit <= 0xDBFF) {
            adjustedMid--; // Exclude high surrogate, push to next page
          }
        }

        final subText = text.substring(startOffset, adjustedMid);
        
        textPainter.text = TextSpan(
          text: subText,
          style: resolvedStyle,
        );
        
        textPainter.layout(maxWidth: viewportWidth);
        
        if (textPainter.height <= viewportHeight) {
          bestEnd = adjustedMid;
          low = mid + 1; // Try to fit more text
        } else {
          high = mid - 1; // Too long, shrink text
        }
      }

      // Edge case: ensure progress to prevent infinite loop
      if (bestEnd == startOffset) {
        bestEnd = startOffset + 1;
      }
      
      // Adjust boundary to split at space/newline instead of cutting words in half
      if (bestEnd < text.length) {
        int boundary = bestEnd;
        // Search backwards up to 50 characters to find a natural break point (whitespace)
        while (boundary > startOffset && (bestEnd - boundary) < 50) {
          final char = text[boundary - 1];
          if (char == ' ' || char == '\n') {
            bestEnd = boundary;
            break;
          }
          boundary--;
        }
      }

      // Safeguard: Ensure final page boundary does not split a UTF-16 surrogate pair
      if (bestEnd > startOffset && bestEnd < text.length) {
        final prevUnit = text.codeUnitAt(bestEnd - 1);
        if (prevUnit >= 0xD800 && prevUnit <= 0xDBFF) {
          bestEnd--; // Shift boundary left to keep surrogate pair on the next page
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
