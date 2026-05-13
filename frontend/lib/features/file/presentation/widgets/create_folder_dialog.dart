import 'package:flutter/material.dart';

/// Shows an [AlertDialog] with a folder-name text field.
///
/// Returns the trimmed folder name on confirmation, or `null` if cancelled.
Future<String?> showCreateFolderDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _CreateFolderDialog(),
  );
}

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog();

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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
      title: const Text('New folder'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Folder name',
            prefixIcon: Icon(
              Icons.folder_outlined,
              color: cs.primary,
              size: 20,
            ),
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _confirm(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Folder name cannot be empty';
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
        FilledButton(onPressed: _confirm, child: const Text('Create')),
      ],
    );
  }
}
