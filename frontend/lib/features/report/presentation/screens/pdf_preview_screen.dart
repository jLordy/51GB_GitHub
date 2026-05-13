import 'package:frontend/features/report/utils/pdf_saver.dart';
import 'package:frontend/features/report/utils/pdf_viewer.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.filename,
  });

  final List<int> bytes;
  final String filename;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await savePdf(widget.bytes, widget.filename);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Palette.greenColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Report Preview',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        actions: [
          _downloading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Download PDF',
                  onPressed: _download,
                ),
        ],
      ),
      body: PdfViewerWidget(bytes: widget.bytes),
    );
  }
}
