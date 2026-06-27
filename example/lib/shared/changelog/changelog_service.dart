import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Displays a "What's New" dialog when the app version changes.
///
/// Fetches changelog from the remote Cloudflare Worker API first.
/// Falls back to the bundled assets/changelog.json if the network is unavailable.
class ChangelogService {
  static const _kKey = 'last_seen_changelog_version';
  static const _kCacheKey = 'cached_remote_changelog';
  static const _kCacheTimeKey = 'cached_remote_changelog_at';
  static const _cacheTtlHours = 24;

  /// Remote API base — uses workers.dev (production) or localhost (debug).
  static const _apiBase = 'https://realbook-changelog-api.sharebible.workers.dev';

  /// Checks if the changelog version differs from the stored version
  /// and shows the dialog if so.
  static Future<void> showIfNew({
    required BuildContext context,
    required SharedPreferences prefs,
  }) async {
    final data = await _fetchChangelog(prefs);
    if (data == null) return;

    final currentVersion = data['version'] as String;
    final versionName = data['versionName'] as String? ?? currentVersion;

    final locale = Localizations.localeOf(context).languageCode;
    final localizedData =
        (data[locale] ?? data['en']) as Map<String, dynamic>;
    final changes = (localizedData['changes'] as List<dynamic>).cast<String>();

    if (changes.isEmpty) return;

    final lastSeen = prefs.getString(_kKey);
    if (lastSeen == currentVersion) return;

    await prefs.setString(_kKey, currentVersion);

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _WhatsNewDialog(
        title:
            locale == 'ko' ? 'v$versionName 새로운 기능' : "What's New in v$versionName",
        changes: changes,
      ),
    );
  }

  /// Fetches the latest changelog entry — remote API first, bundled fallback.
  static Future<Map<String, dynamic>?> _fetchChangelog(
      SharedPreferences prefs) async {
    // Try remote API
    try {
      final cached = prefs.getString(_kCacheKey);
      final cachedAt = prefs.getInt(_kCacheKey) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      final isFresh = cached != null && age < _cacheTtlHours * 3600000;

      if (!isFresh) {
        final client = HttpClient();
        try {
          final request = await client.getUrl(
              Uri.parse('$_apiBase/api/changelog'));
          request.headers.set('Accept', 'application/json');
          final response = await request
              .close()
              .timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            final body = await response.transform(utf8.decoder).join();
            final list = json.decode(body) as List<dynamic>;
            if (list.isNotEmpty) {
              final latest = list.first as Map<String, dynamic>;
              await prefs.setString(_kCacheKey, json.encode(latest));
              await prefs.setInt(
                  _kCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
              return latest;
            }
          }
        } finally {
          client.close();
        }
      } else if (cached != null) {
        return json.decode(cached) as Map<String, dynamic>;
      }
    } catch (_) {
      // Network error — fall through to bundled fallback
    }

    // Fallback: bundled JSON
    try {
      final jsonStr = await rootBundle.loadString('assets/changelog.json');
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

class _WhatsNewDialog extends StatelessWidget {
  final String title;
  final List<String> changes;

  const _WhatsNewDialog({
    required this.title,
    required this.changes,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final change in changes) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(change)),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            Localizations.localeOf(context).languageCode == 'ko' ? '확인' : 'Done',
          ),
        ),
      ],
    );
  }
}

/// Renders its child and shows the "What's New" dialog once on first build
/// when the app version has changed.
class ChangelogGate extends StatefulWidget {
  final Widget child;
  const ChangelogGate({super.key, required this.child});

  @override
  State<ChangelogGate> createState() => _ChangelogGateState();
}

class _ChangelogGateState extends State<ChangelogGate> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      await ChangelogService.showIfNew(context: context, prefs: prefs);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
