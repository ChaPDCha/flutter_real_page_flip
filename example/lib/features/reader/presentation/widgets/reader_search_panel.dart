import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/reader_theme.dart';
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
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: widget.theme.panelColor.withValues(alpha: 0.88),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        child: Column(
          children: [
            // Search Input Header with Back Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: widget.theme.textColor, fontSize: 16),
                    cursorColor: widget.theme.accentColor,
                    decoration: InputDecoration(
                      hintText: '책 내용 검색...',
                      hintStyle: TextStyle(color: widget.theme.secondaryTextColor.withValues(alpha: 0.5)),
                      prefixIcon: Icon(Icons.search, color: widget.theme.secondaryTextColor),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: widget.theme.backgroundColor.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.theme.dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.theme.accentColor, width: 1.5),
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
                    style: TextStyle(color: widget.theme.accentColor, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Results Body
            Expanded(
              child: _isSearching
                  ? Center(child: CircularProgressIndicator(color: widget.theme.accentColor))
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty ? '검색어를 입력해 보세요.' : '검색 결과가 없습니다.',
                            style: TextStyle(color: widget.theme.secondaryTextColor, fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (context, index) => Divider(color: widget.theme.dividerColor, height: 1),
                          itemBuilder: (context, index) {
                            final result = _results[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                              title: Text(
                                result.snippet,
                                style: TextStyle(color: widget.theme.textColor, fontSize: 14, height: 1.4),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '제 ${result.chapterIndex + 1}장',
                                  style: TextStyle(color: widget.theme.accentColor, fontSize: 11, fontWeight: FontWeight.w600),
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
