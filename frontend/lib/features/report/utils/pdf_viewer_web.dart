import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

int _viewCounter = 0;

class PdfViewerWidget extends StatefulWidget {
  const PdfViewerWidget({super.key, required this.bytes});

  final List<int> bytes;

  @override
  State<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  late final String _viewType;
  late final String _blobUrl;

  @override
  void initState() {
    super.initState();
    _viewType = 'agapay-pdf-viewer-${++_viewCounter}';
    final blob = web.Blob(
      [Uint8List.fromList(widget.bytes).toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    _blobUrl = web.URL.createObjectURL(blob);
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return web.document.createElement('iframe') as web.HTMLIFrameElement
        ..src = _blobUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }

  @override
  void dispose() {
    web.URL.revokeObjectURL(_blobUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
