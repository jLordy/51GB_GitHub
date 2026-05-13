import 'package:flutter/material.dart';

/// Shows an [AlertDialog] pre-filled with [currentName] for in-place renaming.
///
/// Used for both folders and documents.
/// Returns the trimmed new name on confirmation, or `null` if cancelled.
Future<String?> showRenameDialog(
  BuildContext context, {
  required String currentName,
  String title = 'Rename',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(currentName: currentName, title: title),
  );
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.currentName, required this.title});

  final String currentName;
  final String title;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.currentName.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.title),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'New name'),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _confirm(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Name cannot be empty';
            }
            if (value.trim().length > 80) {
              return 'Must be 80 characters or fewer';
            }
            return null;
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Save')),
      ],
    );
  }
}
