import 'package:flutter/material.dart';
import '../../../bookshelf/data/database.dart'; // Drift database contains Highlight model

List<TextSpan> buildPageSpans({
  required String pageText,
  required List<Highlight> pageHighlights,
  required int pageStartOffset,
  required int ttsStartInPage,
  required int ttsEndInPage,
  required TextStyle baseStyle,
}) {
  final splitPoints = <int>{0, pageText.length};
  for (final hl in pageHighlights) {
    splitPoints.add(
      (hl.startOffset - pageStartOffset).clamp(0, pageText.length),
    );
    splitPoints.add((hl.endOffset - pageStartOffset).clamp(0, pageText.length));
  }

  if (ttsStartInPage != -1 && ttsEndInPage != -1) {
    splitPoints.add(ttsStartInPage.clamp(0, pageText.length));
    splitPoints.add(ttsEndInPage.clamp(0, pageText.length));
  }

  final sortedSplits = splitPoints.toList()..sort();
  final spans = <TextSpan>[];

  // Pre-build an interval-map keyed by adjusted start offset so each text
  // segment can look up its highlight in O(1) instead of O(n) per segment.
  final highlightByStart = <int, Highlight>{};
  for (final hl in pageHighlights) {
    final adjStart = (hl.startOffset - pageStartOffset).clamp(0, pageText.length);
    highlightByStart[adjStart] = hl;
  }

  // Track the highlight that covers the current position (segments are
  // processed in sorted order, so a running pointer suffices).
  Highlight? currentUserHl;
  int currentUserHlEnd = -1;

  for (int i = 0; i < sortedSplits.length - 1; i++) {
    final start = sortedSplits[i];
    final end = sortedSplits[i + 1];
    if (start == end) continue;

    final segmentText = pageText.substring(start, end);

    // 1. TTS Karaoke-style highlight takes priority
    final isTts =
        ttsStartInPage != -1 &&
        ttsEndInPage != -1 &&
        start >= ttsStartInPage &&
        end <= ttsEndInPage;

    if (isTts) {
      spans.add(
        TextSpan(
          text: segmentText,
          style: baseStyle.copyWith(
            backgroundColor: Colors.amber.withValues(alpha: 0.3),
          ),
        ),
      );
      continue;
    }

    // 2. User dynamic highlight — O(1) lookup via pre-built map
    if (currentUserHl != null && start >= currentUserHlEnd) {
      currentUserHl = null;
      currentUserHlEnd = -1;
    }
    if (currentUserHl == null) {
      final found = highlightByStart[start];
      if (found != null) {
        final adjEnd = (found.endOffset - pageStartOffset)
            .clamp(0, pageText.length);
        if (end <= adjEnd) {
          currentUserHl = found;
          currentUserHlEnd = adjEnd;
        }
      }
    }

    if (currentUserHl != null) {
      Color color = Colors.yellow.withValues(alpha: 0.3);
      try {
        final hex = currentUserHl.highlightColor.replaceAll('#', '');
        if (hex.length == 6) {
          color = Color(int.parse('0x4D$hex'));
        }
      } catch (_) {}

      spans.add(
        TextSpan(
          text: segmentText,
          style: baseStyle.copyWith(backgroundColor: color),
        ),
      );
    } else {
      spans.add(TextSpan(text: segmentText, style: baseStyle));
    }
  }

  return spans;
}
