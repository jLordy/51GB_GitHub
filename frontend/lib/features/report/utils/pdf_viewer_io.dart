import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

class PdfViewerWidget extends StatefulWidget {
  const PdfViewerWidget({super.key, required this.bytes});

  final List<int> bytes;

  @override
  State<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  String? _filePath;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _writeTempFile();
  }

  Future<void> _writeTempFile() async {
    try {
      // Desktop platforms are not supported by flutter_pdfview.
      if (!Platform.isAndroid && !Platform.isIOS) {
        setState(
          () => _error =
              'PDF preview is not supported on desktop.\nUse the download button instead.',
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/agapay_report_preview.pdf');
      await file.writeAsBytes(widget.bytes, flush: true);
      if (mounted) setState(() => _filePath = file.path);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      );
    }

    if (_filePath == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        PDFView(
          filePath: _filePath!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: false,
          fitPolicy: FitPolicy.BOTH,
          onRender: (pages) {
            if (mounted) setState(() => _totalPages = pages ?? 0);
          },
          onPageChanged: (page, total) {
            if (mounted) {
              setState(() {
                _currentPage = (page ?? 0) + 1;
                _totalPages = total ?? 0;
              });
            }
          },
        ),
        if (_totalPages > 0)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
