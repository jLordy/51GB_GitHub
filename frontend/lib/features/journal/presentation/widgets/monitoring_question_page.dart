import 'package:frontend/features/journal/model/question_model.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_input_widgets.dart';
import 'package:flutter/material.dart';

class MonitoringQuestionPage extends StatelessWidget {
  const MonitoringQuestionPage({
    super.key,
    required this.questions,
    required this.currentIndex,
    required this.backToSummary,
    required this.answers,
    required this.getController,
    required this.onAnswerChanged,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  final List<Question> questions;
  final int currentIndex;
  final bool backToSummary;
  final Map<String, dynamic> answers;
  final TextEditingController Function(String key, {String seed}) getController;
  final void Function(String key, dynamic value) onAnswerChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final q = questions[currentIndex];
    final progress = (currentIndex + 1) / questions.length;
    final isLast = currentIndex == questions.length - 1;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                    onPressed: onClose,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: scheme.outlineVariant.withValues(
                              alpha: 0.45,
                            ),
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // ── Question content ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: SizedBox(
                        width: 110,
                        height: 110,
                        child: Image.asset(
                          'assets/images/agapay_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      q.label,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (q.hintText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        q.hintText!,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    JournalInputDispatcher(
                      question: q,
                      answers: answers,
                      getController: getController,
                      onAnswerChanged: onAnswerChanged,
                    ),
                  ],
                ),
              ),
            ),
            // ── Bottom actions ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: onPrev,
                    child: Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (!q.isRequired)
                        TextButton(
                          onPressed: onNext,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 15,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          minimumSize: const Size(56, 56),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 18,
                          ),
                          elevation: 0,
                        ),
                        onPressed: onNext,
                        child: Icon(
                          isLast || backToSummary
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
