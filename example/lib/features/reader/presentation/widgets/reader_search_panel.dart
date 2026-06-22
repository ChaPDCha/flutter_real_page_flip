import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/reader_theme.dart';
import '../../../../shared/theme/reader_typography.dart';
import '../../../bookshelf/domain/book.dart';
import '../../application/search_service.dart';
import '../../application/search_service_provider.dart';

class ReaderSearchPanel extends ConsumerStatefulWidget {
  final Book book;
  final ReaderThemeData theme;
  final Function(int chapterIndex, String query) onResultSelected;

  const ReaderSearchPanel({
    super.key,
    required this.book,
    required this.theme,
    required this.onResultSelected,
  });

  @override
  ConsumerState<ReaderSearchPanel> createState() => _ReaderSearchPanelState();
}

class _ReaderSearchPanelState extends ConsumerState<ReaderSearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _results = [];
  bool _isSearching = false;
  String _currentQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentQuery = query;
    });

    final searchService = ref.read(searchServiceProvider);
    final results = await searchService.searchBook(widget.book.id, query);

    if (mounted && query == _currentQuery) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelTheme = widget.theme;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        color: panelTheme.panelColor.withValues(alpha: 0.85),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          children: [
            // Search Input Header with Back Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: ReaderTypography.getUiStyle(color: panelTheme.textColor, fontSize: 15),
                    cursorColor: panelTheme.accentColor,
                    decoration: InputDecoration(
                      hintText: '책 내용 검색...',
                      hintStyle: ReaderTypography.getUiStyle(color: panelTheme.secondaryTextColor.withValues(alpha: 0.4), fontSize: 15),
                      prefixIcon: Icon(Icons.search_outlined, color: panelTheme.secondaryTextColor, size: 20),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: panelTheme.backgroundColor.withValues(alpha: 0.6),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: panelTheme.dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: panelTheme.accentColor, width: 1.2),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '닫기',
                    style: ReaderTypography.getUiStyle(
                      color: panelTheme.accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Results Body
            Expanded(
              child: _isSearching
                  ? Center(child: CircularProgressIndicator(color: panelTheme.accentColor))
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty ? '검색어를 입력해 보세요.' : '검색 결과가 없습니다.',
                            style: ReaderTypography.getUiStyle(color: panelTheme.secondaryTextColor, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (context, index) => Divider(color: panelTheme.dividerColor, height: 1),
                          itemBuilder: (context, index) {
                            final result = _results[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              title: Text(
                                result.snippet,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: ReaderTypography.getUiStyle(
                                  color: panelTheme.textColor,
                                  fontSize: 14,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '제 ${result.chapterIndex + 1}장',
                                  style: ReaderTypography.getGeometricStyle(
                                    color: panelTheme.accentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              onTap: () {
                                widget.onResultSelected(result.chapterIndex, _currentQuery);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

