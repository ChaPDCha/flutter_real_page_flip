import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:real_page_flip/real_page_flip.dart';
import '../../bookshelf/domain/book.dart';
import '../../../shared/theme/app_theme_controller.dart';
import '../../../shared/theme/reader_theme.dart';
import '../../tts/application/supertonic_tts_provider.dart';
import 'reader_controller.dart';
import 'widgets/pdf_page_renderer.dart';
import 'widgets/reader_app_bar.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/reader_search_panel.dart';
import 'widgets/reader_settings_panel.dart';
import 'widgets/reflowable_page_content.dart';

class BookReaderScreen extends ConsumerStatefulWidget {
  final Book book;

  const BookReaderScreen({super.key, required this.book});

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  final PageFlipController _pageFlipController = PageFlipController();
  bool _showUi = false; // Toggle Appbar/BottomBar on tap
  bool _mountUi =
      false; // Controls mounting/unmounting to optimize BackdropFilter
  Timer? _uiTimer;
  bool _isTtsPlaying = false;
  bool _isFlipping = false;
  Offset? _readerTapDownPosition;
  StreamSubscription<PlayerState>? _ttsSubscription;

  bool _isImageOnlyPage(int index, dynamic state) {
    if (index >= state.pages.length) return false;
    final content = state.pages[index] as String;
    final hasImgTag = content.contains('<img') || content.contains('<image');
    if (!hasImgTag) return false;
    final textOnly = content
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', '')
        .trim();
    return textOnly.length < 50;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ttsSubscription = ref
            .read(supertonicTtsProvider)
            .playerStateStream
            .listen((state) {
              if (mounted) {
                setState(() {
                  _isTtsPlaying = state.playing;
                });
              }
            });
      }
    });
  }

  @override
  void dispose() {
    _ttsSubscription?.cancel();
    _uiTimer?.cancel();
    try {
      ref.read(supertonicTtsProvider).stop();
    } catch (_) {
      // Ignore errors when calling ref after element disposal/hot restart
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(readerControllerProvider(widget.book));
    final controller = ref.read(readerControllerProvider(widget.book).notifier);
    final themeType = ref.watch(appThemeControllerProvider);
    final themeData = ReaderThemeData.get(themeType);

    // Dynamic system UI styling based on global theme
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeData.isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: themeData.backgroundColor,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // 1. Core Page Flip Viewer
                Positioned.fill(
                  child: readerState.isLoading
                      ? _buildLoadingState(themeData)
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            // Adjust padding to keep text clear of screen edges
                            final padding = MediaQuery.of(context).padding;
                            const hPadding = 32.0;
                            final topPadding = padding.top + 20.0;
                            final bottomPadding = padding.bottom + 20.0;
                            final vPadding = topPadding + bottomPadding;

                            final width = constraints.maxWidth - (hPadding * 2);
                            final height = constraints.maxHeight - vPadding;

                            // Update viewport size inside controller to trigger paging recalculations
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                controller.setViewportSize(
                                  width,
                                  height - 110.0,
                                );
                              }
                            });

                            if (readerState.pages.isEmpty) {
                              return Center(
                                child: Text(
                                  '로딩 중...',
                                  style: TextStyle(color: themeData.textColor),
                                ),
                              );
                            }

                            final isDouble = readerState.isDoublePage;
                            final step =
                                (isDouble && !readerState.isPdfLandscape)
                                ? 2
                                : 1;

                            // Raw [Listener] avoids competing with [PageFlipGestureLayer] in the
                            // gesture arena (fixes PDF letterbox swipes not completing flips).
                            return Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (event) {
                                _readerTapDownPosition = event.localPosition;
                              },
                              onPointerCancel: (_) {
                                _readerTapDownPosition = null;
                              },
                              onPointerUp: (event) {
                                if (_isFlipping) return;

                                final down = _readerTapDownPosition;
                                _readerTapDownPosition = null;
                                if (down != null &&
                                    (event.localPosition - down).distance >
                                        20) {
                                  return;
                                }

                                final x = event.localPosition.dx;
                                final screenWidth = constraints.maxWidth;
                                final leftEdge = screenWidth * 0.25;
                                final rightEdge = screenWidth * 0.75;

                                if (x < leftEdge) {
                                  if (readerState.currentPageIndex >= step) {
                                    _pageFlipController.previousPage();
                                  } else if (readerState.currentChapterIndex >
                                      0) {
                                    controller.previousPage();
                                  }
                                } else if (x > rightEdge) {
                                  if (readerState.currentPageIndex + step <
                                      readerState.pages.length) {
                                    _pageFlipController.nextPage();
                                  } else if (readerState.currentChapterIndex <
                                      readerState.chapters.length - 1) {
                                    controller.nextPage();
                                  }
                                } else {
                                  _toggleUi();
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.only(
                                  top: topPadding,
                                  bottom: bottomPadding,
                                ),
                                child: PageFlipWidget(
                                  controller: _pageFlipController,
                                  config: PageFlipConfig(
                                    enableHaptics:
                                        readerState.settings.enableHaptics,
                                    enableSound:
                                        readerState.settings.enableSound,
                                    backgroundColor: themeData.backgroundColor,
                                    sensitivity: 0.6,
                                    edgeTapWidthRatio: 0.0,
                                    // Animate tap flips so spine-band reveal is visible (not instant jump).
                                    skipTapAnimation: false,
                                  ),
                                  itemCount: isDouble
                                      ? (readerState.isPdfLandscape
                                            ? readerState.pages.length
                                            : (readerState.pages.length / 2)
                                                  .ceil())
                                      : readerState.pages.length,
                                  initialIndex: isDouble
                                      ? (readerState.isPdfLandscape
                                            ? readerState.currentPageIndex
                                                  .clamp(
                                                    0,
                                                    (readerState.pages.length -
                                                            1)
                                                        .clamp(0, 99999),
                                                  )
                                            : (readerState.currentPageIndex / 2)
                                                  .floor()
                                                  .clamp(
                                                    0,
                                                    ((readerState.pages.length /
                                                                    2)
                                                                .ceil() -
                                                            1)
                                                        .clamp(0, 99999),
                                                  ))
                                      : (readerState.currentPageIndex <
                                                readerState.pages.length
                                            ? readerState.currentPageIndex
                                            : 0),
                                  spreadMode: isDouble
                                      ? PageFlipSpreadMode.doubleSpread
                                      : PageFlipSpreadMode.single,
                                  // Stable method reference — inline closures reset spread snapshots every build.
                                  itemBuilder: _buildFlipSpreadPage,
                                  onFlipStart: () {
                                    _isFlipping = true;
                                  },
                                  onFlipEnd: () {
                                    _isFlipping = false;
                                  },
                                  onPageChanged: (index) {
                                    _isFlipping = false;
                                    // Defer reader state update to post-frame so the
                                    // PageFlipWidget fully transitions to non-drag mode
                                    // before Riverpod triggers a rebuild of this screen.
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          if (isDouble &&
                                              !readerState.isPdfLandscape) {
                                            controller.goToPageIndex(index * 2);
                                          } else {
                                            controller.goToPageIndex(index);
                                          }
                                        });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // 2. Brightness overlay (dims content without affecting UI chrome)
                if (readerState.settings.brightness < 1.0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: 1.0 - readerState.settings.brightness,
                        ),
                      ),
                    ),
                  ),

                // 3. Persistent Back Button (visible even when ui is hidden)
                if (!readerState.isLoading && readerState.pages.isNotEmpty)
                  _buildPersistentBackButton(themeData),

                // 4. AppBar (Appears on Tap)
                if (_mountUi)
                  ReaderAppBar(
                    showUi: _showUi,
                    book: widget.book,
                    readerState: readerState,
                    themeData: themeData,
                    isTtsPlaying: _isTtsPlaying,
                    onBack: () => Navigator.of(context).pop(),
                    onTtsPressed: () {
                      if (_isTtsPlaying) {
                        ref.read(supertonicTtsProvider).pause();
                      } else {
                        final currentText =
                            readerState.pages[readerState.currentPageIndex];
                        ref.read(supertonicTtsProvider).speak(currentText);
                      }
                    },
                    onSettingsPressed: () => ReaderSettingsPanel.show(
                      context: context,
                      ref: ref,
                      book: widget.book,
                      state: readerState,
                      controller: controller,
                    ),
                    onSearchPressed: () {
                      showGeneralDialog(
                        context: context,
                        barrierDismissible: true,
                        barrierLabel: 'Search',
                        pageBuilder: (context, _, __) {
                          return Scaffold(
                            backgroundColor: Colors.transparent,
                            body: ReaderSearchPanel(
                              book: widget.book,
                              theme: themeData,
                              onResultSelected: (chapterIndex, query) {
                                controller.jumpToChapterWithQuery(
                                  chapterIndex,
                                  query,
                                );
                                final targetIndex = ref
                                    .read(readerControllerProvider(widget.book))
                                    .currentPageIndex;
                                if (readerState.isDoublePage) {
                                  _pageFlipController.goToPage(
                                    (targetIndex / 2).floor(),
                                  );
                                } else {
                                  _pageFlipController.goToPage(targetIndex);
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),

                // 5. Bottom Bar (Appears on Tap)
                if (_mountUi)
                  ReaderBottomBar(
                    showUi: _showUi,
                    book: widget.book,
                    readerState: readerState,
                    themeData: themeData,
                    onPreviousChapter: () {
                      controller.previousPage();
                      _pageFlipController.goToPage(0);
                    },
                    onNextChapter: () {
                      controller.nextPage();
                      _pageFlipController.goToPage(0);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ReaderThemeData themeData) {
    return Container(
      color: themeData.backgroundColor,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: themeData.accentColor),
                const SizedBox(height: 24),
                Text(
                  '책을 불러오는 중...',
                  style: TextStyle(
                    fontSize: 16,
                    color: themeData.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: themeData.textColor,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersistentBackButton(ReaderThemeData themeData) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeData.isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: themeData.textColor,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  /// PageFlip host: each [spreadIndex] is one full two-page spread when double-page mode is on.
  /// PreRenderManager captures spreadSnapshots[spreadIndex ± 1] for spine reveal and flap texture.
  Widget _buildFlipSpreadPage(BuildContext context, int spreadIndex) {
    final readerState = ref.read(readerControllerProvider(widget.book));
    final themeType = ref.watch(appThemeControllerProvider);
    final themeData = ReaderThemeData.get(themeType);
    final isPdf = widget.book.format == BookFormat.pdf;
    final isDouble = readerState.isDoublePage;

    if (isDouble) {
      if (isPdf && readerState.isPdfLandscape) {
        return Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: clipSpreadPageHalf(
                    alignment: Alignment.centerLeft,
                    child: isPdf
                        ? PdfPageRenderer(
                            filePath: widget.book.filePath,
                            pageIndex: spreadIndex,
                            theme: themeData,
                          )
                        : ReflowablePageContent(
                            state: readerState,
                            theme: themeData,
                            index: spreadIndex,
                          ),
                  ),
                ),
                Expanded(
                  child: clipSpreadPageHalf(
                    alignment: Alignment.centerRight,
                    child: isPdf
                        ? PdfPageRenderer(
                            filePath: widget.book.filePath,
                            pageIndex: spreadIndex,
                            theme: themeData,
                          )
                        : ReflowablePageContent(
                            state: readerState,
                            theme: themeData,
                            index: spreadIndex,
                          ),
                  ),
                ),
              ],
            ),
          ],
        );
      }

      final leftIndex = spreadIndex * 2;
      final rightIndex = spreadIndex * 2 + 1;
      final hasRight = rightIndex < readerState.pages.length;

      final isLeftImage = isPdf || _isImageOnlyPage(leftIndex, readerState);
      final isRightImage =
          isPdf || (hasRight && _isImageOnlyPage(rightIndex, readerState));
      final isImageSpread = isLeftImage && isRightImage;

      final gutterPadding = isImageSpread ? 0.0 : 28.0;
      final outerHPadding = isImageSpread ? 0.0 : 32.0;

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: outerHPadding),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: gutterPadding),
                    child: isPdf
                        ? PdfPageRenderer(
                            filePath: widget.book.filePath,
                            pageIndex: leftIndex,
                            theme: themeData,
                          )
                        : ReflowablePageContent(
                            state: readerState,
                            theme: themeData,
                            index: leftIndex,
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: gutterPadding),
                    child: hasRight
                        ? (isPdf
                              ? PdfPageRenderer(
                                  filePath: widget.book.filePath,
                                  pageIndex: rightIndex,
                                  theme: themeData,
                                )
                              : ReflowablePageContent(
                                  state: readerState,
                                  theme: themeData,
                                  index: rightIndex,
                                ))
                        : Container(color: themeData.backgroundColor),
                  ),
                ),
              ],
            ),
            if (!isImageSpread)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.03),
                              Colors.black.withValues(alpha: 0.12),
                            ],
                            stops: const [0.85, 0.95, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.12),
                              Colors.black.withValues(alpha: 0.03),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.05, 0.15],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    if (isPdf) {
      return PdfPageRenderer(
        filePath: widget.book.filePath,
        pageIndex: spreadIndex,
        theme: themeData,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: ReflowablePageContent(
        state: readerState,
        theme: themeData,
        index: spreadIndex,
      ),
    );
  }

  void _toggleUi() {
    _uiTimer?.cancel();
    if (_showUi) {
      setState(() {
        _showUi = false;
      });
      _uiTimer = Timer(const Duration(milliseconds: 260), () {
        if (mounted) {
          setState(() {
            _mountUi = false;
          });
        }
      });
    } else {
      setState(() {
        _mountUi = true;
        _showUi = true;
      });
    }
  }
}
