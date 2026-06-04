import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../shared/theme/reader_theme.dart';
import '../../../bookshelf/domain/book.dart';
import '../reader_state.dart';

class ReaderAppBar extends StatelessWidget {
  final bool showUi;
  final Book book;
  final ReaderState readerState;
  final ReaderThemeData themeData;
  final bool isTtsPlaying;
  final VoidCallback onBack;
  final VoidCallback onTtsPressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onSearchPressed;

  const ReaderAppBar({
    super.key,
    required this.showUi,
    required this.book,
    required this.readerState,
    required this.themeData,
    required this.isTtsPlaying,
    required this.onBack,
    required this.onTtsPressed,
    required this.onSettingsPressed,
    required this.onSearchPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      top: showUi ? 0 : -80 - MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: showUi ? 1.0 : 0.0,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              height: kToolbarHeight + MediaQuery.of(context).padding.top,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              color: themeData.panelColor.withValues(alpha: 0.8),
              child: NavigationToolbar(
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: themeData.textColor, size: 20),
                  onPressed: onBack,
                ),
                middle: Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'serif',
                    color: themeData.textColor,
                    fontSize: 16,
                  ),
                ),
                trailing: book.format == BookFormat.pdf
                    ? const SizedBox.shrink()
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.search, color: themeData.textColor, size: 22),
                            onPressed: onSearchPressed,
                          ),
                          IconButton(
                            icon: Icon(
                              isTtsPlaying ? Icons.pause_circle_filled : Icons.volume_up,
                              color: isTtsPlaying ? themeData.accentColor : themeData.textColor,
                              size: 22,
                            ),
                            onPressed: onTtsPressed,
                          ),
                          IconButton(
                            icon: Icon(Icons.text_fields, color: themeData.textColor, size: 22),
                            onPressed: onSettingsPressed,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
