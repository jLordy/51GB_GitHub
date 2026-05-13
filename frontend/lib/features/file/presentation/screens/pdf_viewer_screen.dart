import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PdfViewerScreen — in-app viewer for PDFs, images, and Word documents
//
//  Routing params (all passed as query parameters):
//    url   — remote file URL
//    name  — display name in the AppBar
//    type  — MIME type string (used to select the viewer strategy)
// ─────────────────────────────────────────────────────────────────────────────

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
  });

  final String fileUrl;
  final String fileName;

  /// MIME type, e.g. "application/pdf", "image/jpeg", etc.
  final String fileType;

  bool get _isImage =>
      fileType == 'image/jpeg' ||
      fileType == 'image/png' ||
      fileType == 'image/webp';

  bool get _isPdf => fileType == 'application/pdf';

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // PDF-specific state
  int _totalPages = 0;
  int _currentPage = 0;

  // Download state for PDF / Word docs
  bool _isDownloading = false;
  double? _downloadProgress;
  String? _localPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget._isImage) {
      _downloadFile();
    }
  }

  Future<void> _downloadFile() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _error = null;
    });

    try {
      final dir = await getTemporaryDirectory();
      // Use a unique name derived from the URL to avoid collisions
      final fileName = Uri.parse(widget.fileUrl).pathSegments.last;
      final path = '${dir.path}/$fileName';

      await Dio().download(
        widget.fileUrl,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (mounted) {
        setState(() {
          _localPath = path;
          _isDownloading = false;
        });

        // For Word docs, open immediately with the external app.
        if (!widget._isPdf) {
          await OpenFilex.open(path);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _error = 'Failed to download file: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.fileName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        // Page counter for PDFs
        actions: <Widget>[
          if (widget._isPdf && _totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _downloadFile, cs: cs);
    }

    // Image viewer
    if (widget._isImage) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: Image.network(
            widget.fileUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                      : null,
                  color: cs.primary,
                ),
              );
            },
            errorBuilder: (_, _, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.broken_image_rounded,
                  size: 56,
                  color: cs.outlineVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'Could not load image',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Downloading spinner
    if (_isDownloading || _localPath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: _downloadProgress,
                strokeWidth: 4,
                color: cs.primary,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading…',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // PDF viewer
    if (widget._isPdf) {
      return PDFView(
        filePath: _localPath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        fitPolicy: FitPolicy.BOTH,
        onRender: (pages) {
          if (mounted) setState(() => _totalPages = pages ?? 0);
        },
        onPageChanged: (page, _) {
          if (mounted) setState(() => _currentPage = page ?? 0);
        },
        onError: (err) {
          if (mounted) setState(() => _error = err.toString());
        },
      );
    }

    // Word doc — already opened externally; show a confirmation message.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.description_rounded,
              size: 56,
              color: const Color(0xFF2B6CB0),
            ),
            const SizedBox(height: 16),
            Text(
              'The file has been opened in an external app.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: cs.onSurface),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                if (_localPath != null && File(_localPath!).existsSync()) {
                  await OpenFilex.open(_localPath!);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Error view
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.cs,
  });

  final String message;
  final VoidCallback onRetry;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              'Failed to load file',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
