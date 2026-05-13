import 'package:frontend/features/journal/model/journal_entry_model.dart';
import 'package:frontend/features/journal/model/question_model.dart';
import 'package:frontend/features/journal/presentation/widgets/edit_history_chip.dart';
import 'package:frontend/features/journal/presentation/widgets/edit_history_sheet.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_summary_row.dart';
import 'package:flutter/material.dart';

// ── Private helpers ───────────────────────────────────────────────────────────

String _formatDate(DateTime dt) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

// ── Public formatter (used by both summary and tests) ────────────────────────

/// Converts a raw answer value to a human-readable string for a given [q].
String formatAnswer(Question q, dynamic answer) {
  if (answer == null) return '—';
  switch (q.uiComponent) {
    case 'bp_input':
      final m = answer as Map<String, dynamic>;
      final sys = m['systolic'];
      final dia = m['diastolic'];
      return (sys != null && dia != null) ? '$sys / $dia' : '—';
    case 'weight_input':
      final m = answer as Map<String, dynamic>;
      final val = m['value'];
      final u = m['unit'] ?? 'kg';
      return val != null ? '$val $u' : '—';
    case 'toggle':
      return (answer as bool?) == true ? 'Yes' : 'No';
    case 'chip_selector':
      final list = answer as List<dynamic>;
      if (list.isEmpty) return '—';
      return list
          .map((v) {
            final opt = q.options?.firstWhere(
              (o) => o.value == v.toString(),
              orElse: () =>
                  QuestionOption(value: v.toString(), label: v.toString()),
            );
            return opt?.label ?? v.toString();
          })
          .join(', ');
    case 'multi_text_input':
      final list = answer as List<dynamic>;
      if (list.isEmpty) return '—';
      return list.map((v) => v.toString()).join(', ');
    case 'radio':
    case 'select':
      final opt = q.options?.firstWhere(
        (o) => o.value == answer.toString(),
        orElse: () => QuestionOption(value: '', label: answer.toString()),
      );
      return opt?.label ?? answer.toString();
    case 'slider':
      final v = (answer as double).toInt();
      final unit = q.validation?.unit;
      return unit != null ? '$v $unit' : '$v';
    case 'number_input':
      final unit = q.validation?.unit;
      return unit != null ? '$answer $unit' : '$answer';
    default:
      return answer.toString();
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class MonitoringSummaryPage extends StatelessWidget {
  const MonitoringSummaryPage({
    super.key,
    required this.questions,
    required this.answers,
    required this.notesCtrl,
    required this.isEditMode,
    required this.editCount,
    required this.historyLoading,
    required this.editHistory,
    required this.errorMsg,
    required this.onSubmit,
    required this.onBack,
    required this.onEditQuestion,
    this.readOnly = false,
  });

  final List<Question> questions;
  final Map<String, dynamic> answers;
  final TextEditingController notesCtrl;
  final bool isEditMode;
  final int editCount;
  final bool historyLoading;
  final List<EditHistoryEntry> editHistory;
  final String? errorMsg;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final void Function(int index) onEditQuestion;
  final bool readOnly;

  void _showSheet(BuildContext context) {
    final theme = Theme.of(context);
    final card = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerLow
        : theme.colorScheme.surfaceContainerLowest;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          EditHistorySheet(editHistory: editHistory, surfaceCard: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final surface = scheme.surface;
    final surfaceCard = Theme.of(context).brightness == Brightness.dark
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerLowest;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: scheme.onSurface),
          onPressed: onBack,
        ),
        title: Text(
          readOnly
              ? 'View Entry'
              : (isEditMode ? 'Edit Entry' : 'Journal Entry'),
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: readOnly
            ? null
            : [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: onSubmit,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: scheme.onPrimary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Edit history chip (existing entries only) ────────────
            if (isEditMode)
              EditHistoryChip(
                editCount: editCount,
                historyLoading: historyLoading,
                onViewHistory: () => _showSheet(context),
              ),

            // ── Error banner ─────────────────────────────────────────
            if (errorMsg != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.error),
                ),
                child: Text(
                  errorMsg!,
                  style: TextStyle(color: scheme.error, fontSize: 13),
                ),
              ),
            ],

            // ── Answered questions ───────────────────────────────────
            ...List.generate(questions.length, (i) {
              return JournalSummaryRow(
                label: questions[i].label,
                displayValue: formatAnswer(
                  questions[i],
                  answers[questions[i].id],
                ),
                onEdit: readOnly ? null : () => onEditQuestion(i),
              );
            }),

            // ── Additional notes text area ───────────────────────────
            const SizedBox(height: 4),
            Text(
              'Additional Symptoms Felt:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: TextField(
                controller: notesCtrl,
                maxLines: 6,
                readOnly: readOnly,
                decoration: InputDecoration(
                  hintText: readOnly ? null : 'Type here...',
                  hintStyle: readOnly
                      ? null
                      : TextStyle(
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.55,
                          ),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                _formatDate(now),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
