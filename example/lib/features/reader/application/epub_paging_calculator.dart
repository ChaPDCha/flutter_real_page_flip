import 'package:flutter/material.dart';

class EpubPagingCalculator {
  /// Splits the text of a chapter into pages based on display constraints.
  static List<String> splitIntoPages({
    required String text,
    required double viewportWidth,
    required double viewportHeight,
    required double fontSize,
    required double lineHeight,
    required TextStyle baseStyle,
  }) {
    if (text.trim().isEmpty) {
      return [''];
    }

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
      pages.add(pageText.isNotEmpty ? pageText : '');
      startOffset = bestEnd;
    }

    return pages;
  }
}
