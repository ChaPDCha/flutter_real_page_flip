/// Generates Play Store changelogs and in-app changelog JSON from CHANGELOG.md.
///
/// Usage: dart run tool/generate_changelogs.dart [version]
///
/// CHANGELOG.md list items can use a pipe separator for bilingual text:
///   - 한국어 텍스트 | English text
/// Without a separator, the text is used for both languages.
///
/// Outputs:
///   - android/fastlane/metadata/android/{lang}/changelogs/{versionCode}.txt
///   - assets/changelog.json  (in-app what's new data)
// ignore_for_file: avoid_print
library;

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final changelog = File('CHANGELOG.md').readAsStringSync();

  final entries = _parseChangelog(changelog);
  if (entries.isEmpty) {
    stderr.writeln('No version entries found in CHANGELOG.md');
    exitCode = 1;
    return;
  }

  final targetVersion = args.isNotEmpty ? args[0] : entries.first.version;
  final entry = entries.firstWhere(
    (e) => e.version == targetVersion,
    orElse: () => entries.first,
  );

  stdout.writeln('Generating changelogs for ${entry.version}');

  final versionCode = int.tryParse(entry.version.split('+').last) ?? 0;
  if (versionCode == 0) {
    stderr.writeln('Could not extract versionCode from ${entry.version}');
    exitCode = 1;
    return;
  }

  // Generate Play Store changelogs
  for (final locale in ['en-US', 'ko-KR']) {
    final lang = locale.split('-').first;
    final lines = entry.items
        .map((i) => i.text(lang))
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) continue;

    final dir = Directory('android/fastlane/metadata/android/$locale/changelogs');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$versionCode.txt');
    file.writeAsStringSync('${lines.map((l) => '• $l').join('\n')}\n');
    stdout.writeln('  ${file.path}');
  }

  // Generate in-app changelog JSON
  final jsonDir = Directory('assets');
  await jsonDir.create(recursive: true);
  final jsonFile = File('${jsonDir.path}/changelog.json');
  jsonFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(entry.toJson()),
  );
  stdout.writeln('  ${jsonFile.path}');
}

class _Entry {
  final String version;
  final String date;
  final List<_Item> items;

  _Entry({required this.version, required this.date, required this.items});

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'versionCode': int.tryParse(version.split('+').last) ?? 0,
      'versionName': version.split('+').first,
      'date': date,
      'ko': {'changes': items.map((i) => i.ko).where((t) => t.isNotEmpty).toList()},
      'en': {'changes': items.map((i) => i.en).where((t) => t.isNotEmpty).toList()},
    };
  }
}

class _Item {
  final String ko;
  final String en;

  _Item(this.ko, this.en);

  String text(String lang) => lang == 'ko' ? ko : en;
}

List<_Entry> _parseChangelog(String content) {
  final lines = content.split('\n');
  final entries = <_Entry>[];

  String? currentVersion;
  String? currentDate;
  final items = <_Item>[];

  for (final rawLine in lines) {
    final line = rawLine.trim();

    // Version header: ## [1.0.28+34] - 2026-06-27
    final vMatch = RegExp(r'^##\s+\[([\d.+\-]+)\]\s*-\s*(\d{4}-\d{2}-\d{2})\s*$')
        .firstMatch(line);
    if (vMatch != null) {
      if (currentVersion != null) {
        entries.add(_Entry(version: currentVersion, date: currentDate!, items: List.from(items)));
        items.clear();
      }
      currentVersion = vMatch.group(1)!;
      currentDate = vMatch.group(2)!;
      continue;
    }

    if (currentVersion == null) continue;

    // List item: - text
    if (line.startsWith('- ')) {
      final text = line.substring(2).trim();
      if (text.contains(' | ')) {
        final parts = text.split(' | ');
        items.add(_Item(parts[0].trim(), parts.sublist(1).join(' | ').trim()));
      } else {
        items.add(_Item(text, text));
      }
      continue;
    }
  }

  if (currentVersion != null) {
    entries.add(_Entry(version: currentVersion, date: currentDate!, items: List.from(items)));
  }

  return entries;
}
