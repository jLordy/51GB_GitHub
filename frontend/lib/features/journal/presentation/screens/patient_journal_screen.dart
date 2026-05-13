import 'package:frontend/features/journal/controller/journal_controller.dart';
import 'package:frontend/features/journal/model/journal_entry_model.dart';
import 'package:frontend/features/journal/model/question_model.dart';
import 'package:frontend/features/journal/presentation/screens/monitoring_screen.dart';

import 'package:frontend/features/journal/presentation/widgets/journal_empty_state.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_entries_list.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_error_state.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_filter_bar.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_header_strip.dart';
import 'package:frontend/features/journal/presentation/widgets/monitoring_summary_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Viewer role ────────────────────────────────────────────────────────────────

/// The role of the user viewing a patient's journal.
///
/// [doctor]    — read-only access (no FAB, no edit/delete actions).
/// [secretary]  — read-only access (no FAB, no edit/delete actions).
/// [caregiver] — read + write access (FAB to add entry, edit via MonitoringScreen).
enum PatientJournalViewerRole { doctor, secretary, caregiver }

// ── Helpers ────────────────────────────────────────────────────────────────────

List<JournalEntryModel> _applyFilters(
  List<JournalEntryModel> entries,
  JournalSortOrder sortOrder,
  DateTime? dateFilter,
) {
  var filtered = entries;
  if (dateFilter != null) {
    final target = DateTime(dateFilter.year, dateFilter.month, dateFilter.day);
    filtered = filtered.where((e) {
      final d = e.submittedAt.toLocal();
      return DateTime(d.year, d.month, d.day) == target;
    }).toList();
  }
  final sorted = List<JournalEntryModel>.from(filtered);
  sorted.sort(
    (a, b) => sortOrder == JournalSortOrder.newestFirst
        ? b.submittedAt.compareTo(a.submittedAt)
        : a.submittedAt.compareTo(b.submittedAt),
  );
  return sorted;
}

// ── Screen ─────────────────────────────────────────────────────────────────────

/// Displays a connected patient's journal entries.
///
/// - **Doctor** viewers see the list read-only (no FAB, no edit / delete).
/// - **Caregiver** viewers can add entries via [MonitoringScreen] and edit
///   existing ones; the list refreshes automatically after changes.
class PatientJournalScreen extends ConsumerStatefulWidget {
  const PatientJournalScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
    required this.viewerRole,
  });

  final String patientUid;
  final String patientName;
  final PatientJournalViewerRole viewerRole;

  @override
  ConsumerState<PatientJournalScreen> createState() =>
      _PatientJournalScreenState();
}

class _PatientJournalScreenState extends ConsumerState<PatientJournalScreen> {
  JournalSortOrder _sortOrder = JournalSortOrder.newestFirst;
  DateTime? _dateFilter;

  String _buildPreviewWithQuestions(
    JournalEntryModel entry,
    List<Question> questions, {
    int maxLines = 3,
  }) {
    if (questions.isEmpty) return entry.buildPreview(maxLines: maxLines);

    final b = StringBuffer();
    int count = 0;

    for (final q in questions) {
      if (count >= maxLines) break;
      if (q.id == 'additional_notes') continue;
      if (!entry.answers.containsKey(q.id)) continue;

      final raw = entry.answers[q.id];
      final display = formatAnswer(q, raw);
      if (display == '—') continue;

      final cleanLabel = q.label.endsWith(':')
          ? q.label.substring(0, q.label.length - 1)
          : q.label;
      b.writeln('$cleanLabel: $display');
      count++;
    }

    final built = b.toString().trim();
    if (built.isNotEmpty) return built;
    return entry.buildPreview(maxLines: maxLines);
  }

  bool get _isReadOnly =>
      widget.viewerRole == PatientJournalViewerRole.doctor ||
      widget.viewerRole == PatientJournalViewerRole.secretary;

  void _refresh() =>
      ref.invalidate(patientJournalEntriesProvider(widget.patientUid));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entriesAsync = ref.watch(
      patientJournalEntriesProvider(widget.patientUid),
    );
    final questionsAsync = ref.watch(
      patientJournalQuestionsProvider(widget.patientUid),
    );

    final rawEntries = entriesAsync.asData?.value;
    final filtered = rawEntries != null
        ? _applyFilters(rawEntries, _sortOrder, _dateFilter)
        : null;
    final displayCount = filtered?.length;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.patientName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            Text(
              _isReadOnly
                  ? 'Read-only journal access'
                  : 'Caregiver journal access',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isReadOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute<void>(
                        builder: (_) => MonitoringScreen(
                          patientUid: widget.patientUid,
                          patientName: widget.patientName,
                        ),
                      ),
                    )
                    .then((_) => _refresh());
              },
              backgroundColor: cs.primaryContainer,
              elevation: 2,
              icon: Icon(Icons.add_rounded, color: cs.primary, size: 22),
              label: Text(
                'Add Entry',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          JournalHeaderStrip(entryCount: displayCount),
          JournalFilterBar(
            sortOrder: _sortOrder,
            dateFilter: _dateFilter,
            onSortChanged: (order) => setState(() => _sortOrder = order),
            onDateFilterChanged: (date) => setState(() => _dateFilter = date),
          ),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => JournalErrorState(onRetry: _refresh),
              data: (_) {
                if (filtered == null || filtered.isEmpty) {
                  if (_dateFilter != null) {
                    return _DateFilterEmpty(
                      onClear: () => setState(() => _dateFilter = null),
                    );
                  }
                  return JournalEmptyState(isReadOnly: _isReadOnly);
                }
                final questions =
                    questionsAsync.asData?.value.questions ??
                    const <Question>[];
                return JournalEntriesList(
                  entries: filtered,
                  previewBuilder: (entry) =>
                      _buildPreviewWithQuestions(entry, questions),
                  isReadOnly: _isReadOnly,
                  onTapEntry: (entry) {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) => MonitoringScreen(
                              existingEntry: entry,
                              patientUid: widget.patientUid,
                              patientName: widget.patientName,
                              readOnly: _isReadOnly,
                            ),
                          ),
                        )
                        .then((_) {
                          if (!_isReadOnly) _refresh();
                        });
                  },
                
                  onDeleteEntry: (_) {
                    // Delete is not available to caregivers / doctors.
                    // JournalEntriesList never calls this when isReadOnly = true.
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date-filter empty state ────────────────────────────────────────────────────

class _DateFilterEmpty extends StatelessWidget {
  const _DateFilterEmpty({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.event_busy_rounded, size: 52, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'No entries on this date',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Clear date filter'),
          ),
        ],
      ),
    );
  }
}