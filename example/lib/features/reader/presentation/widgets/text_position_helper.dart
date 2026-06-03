import 'package:flutter/material.dart';

int getCharOffsetForPosition(
  Offset localOffset,
  String text,
  TextStyle style,
  double maxWidth,
) {
  final textPainter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout(maxWidth: maxWidth);
  final textPosition = textPainter.getPositionForOffset(localOffset);
  return textPosition.offset;
}

MapEntry<int, String> getSentenceAtOffset(String text, int charOffset) {
  if (text.isEmpty) return const MapEntry(0, '');
  final clampedOffset = charOffset.clamp(0, text.length - 1);

  int start = clampedOffset;
  while (start > 0) {
    final prevChar = text[start - 1];
    if (prevChar == '.' || prevChar == '?' || prevChar == '!') {
      while (start < clampedOffset && text[start] == ' ') {
        start++;
      }
      break;
    }
    start--;
  }

  int end = clampedOffset;
  while (end < text.length) {
    final char = text[end];
    if (char == '.' || char == '?' || char == '!') {
      end++;
      break;
    }
    end++;
  }

  final sentenceText = text.substring(start, end).trim();
  return MapEntry(start, sentenceText);
}
