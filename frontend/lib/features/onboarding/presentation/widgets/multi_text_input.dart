import 'package:flutter/material.dart';

/// Chip-list text field for collecting a variable number of string items.
///
/// [onAdd] and [onRemove] are lifted to the parent that owns [items] state,
/// keeping this widget fully stateless and purely presentational.
/// [controller] is owned and disposed by the parent.
class MultiTextInput extends StatelessWidget {
  const MultiTextInput({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  final String label;
  final String hint;
  // Read-only view passed from parent — must not be mutated here.
  final List<String> items;
  // Owned and disposed by the parent widget.
  final TextEditingController controller;
  final void Function(String value) onAdd;
  final void Function(int index) onRemove;

  void _tryAdd() {
    final trimmed = controller.text.trim();
    if (trimmed.isNotEmpty) {
      onAdd(trimmed);
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: scheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.primary, width: 1.6),
                  ),
                ),
                onSubmitted: (_) => _tryAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _tryAdd,
              icon: Icon(Icons.add_circle_outline, color: scheme.primary),
              tooltip: 'Add',
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (int i = 0; i < items.length; i++)
                Chip(
                  label: Text(
                    items[i],
                    style: TextStyle(fontSize: 13, color: scheme.primary),
                  ),
                  deleteIcon: Icon(
                    Icons.close,
                    size: 16,
                    color: scheme.primary,
                  ),
                  onDeleted: () => onRemove(i),
                  backgroundColor: scheme.primaryContainer,
                  side: BorderSide(
                    color: scheme.primary.withValues(alpha: 0.4),
                  ),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
