import 'package:flutter/material.dart';

class PdfViewerWidget extends StatelessWidget {
  const PdfViewerWidget({super.key, required this.bytes});

  final List<int> bytes;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('PDF viewer is not supported on this platform.'),
    );
  }
}
