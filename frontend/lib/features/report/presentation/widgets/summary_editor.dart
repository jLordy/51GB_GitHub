import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Scrollable multiline text editor that displays the generated diary summary.
///
/// The field is pre-filled with [content] and is editable. Any changes are
/// reported through [onChanged].  While [isLoading] is true, a centered
/// circular indicator is shown instead of the text field.
class SummaryEditor extends StatefulWidget {
  const SummaryEditor({
    super.key,
    required this.content,
    required this.onChanged,
    this.isLoading = false,
    this.readOnly = false,
  });

  final String content;
  final ValueChanged<String> onChanged;
  final bool isLoading;
  final bool readOnly;

  @override
  State<SummaryEditor> createState() => _SummaryEditorState();
}

class _SummaryEditorState extends State<SummaryEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void didUpdateWidget(SummaryEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update the controller text when the content changed externally
    // (e.g. after a new generation), not on every keystroke.
    if (widget.content != oldWidget.content &&
        widget.content != _controller.text) {
      _controller.text = widget.content;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        color: isDark
            ? Palette.darkSurfaceContainerColor
            : const Color(0xFFF8FCFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: .25)),
      ),
      child: widget.isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 48, 14),
                  child: TextField(
                    controller: _controller,
                    onChanged: widget.onChanged,
                    readOnly: widget.readOnly,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 12.5,
                      height: 1.65,
                      color: cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Generated diary summary will appear here…',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: cs.onSurfaceVariant.withValues(alpha: .6),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                // Copy button overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    tooltip: 'Copy to clipboard',
                    onPressed: _controller.text.isNotEmpty
                        ? _copyToClipboard
                        : null,
                    splashRadius: 18,
                  ),
                ),
              ],
            ),
    );
  }
}
