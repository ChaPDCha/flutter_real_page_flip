import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../../application/pdf_service.dart';

class PdfPageRenderer extends StatefulWidget {
  final String filePath;
  final int pageIndex; // 0-indexed page index

  const PdfPageRenderer({
    super.key,
    required this.filePath,
    required this.pageIndex,
  });

  @override
  State<PdfPageRenderer> createState() => _PdfPageRendererState();
}

class _PdfPageRendererState extends State<PdfPageRenderer> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _error;
  int _renderId = 0;

  @override
  void initState() {
    super.initState();
    final cachedBytes = PdfService.getCachedPageImage(widget.filePath, widget.pageIndex);
    if (cachedBytes != null) {
      _imageBytes = cachedBytes;
      _isLoading = false;
    } else {
      _renderPage();
    }
  }

  @override
  void didUpdateWidget(PdfPageRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath || oldWidget.pageIndex != widget.pageIndex) {
      final cachedBytes = PdfService.getCachedPageImage(widget.filePath, widget.pageIndex);
      if (cachedBytes != null) {
        setState(() {
          _imageBytes = cachedBytes;
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _isLoading = true;
          _imageBytes = null;
          _error = null;
        });
        _renderPage();
      }
    }
  }

  Future<void> _renderPage() async {
    final currentId = ++_renderId;
    try {
      final document = await PdfService.getOrOpenDocument(widget.filePath);
      // pdfx page indices are 1-based
      final pageNumber = widget.pageIndex + 1;
      
      if (pageNumber < 1 || pageNumber > document.pagesCount) {
        throw Exception('Invalid page number: $pageNumber');
      }

      final page = await document.getPage(pageNumber);

      // Render page at 2x scale for premium, sharp text clarity
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );

      await page.close();

      final bytes = pageImage?.bytes;
      if (bytes != null) {
        PdfService.cachePageImage(widget.filePath, widget.pageIndex, bytes);
      }

      if (mounted && _renderId == currentId) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _renderId == currentId) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8C6239)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              '페이지를 로드할 수 없습니다.\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_imageBytes == null) {
      return const Center(
        child: Text('빈 페이지'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Image.memory(
            _imageBytes!,
            fit: BoxFit.contain,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            gaplessPlayback: true, // Avoids flickering when turning pages
          ),
        );
      },
    );
  }
}
