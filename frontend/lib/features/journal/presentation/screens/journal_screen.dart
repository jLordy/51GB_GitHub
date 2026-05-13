import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/core/widgets/left_sidebar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/journal/controller/journal_controller.dart';
import 'package:frontend/features/journal/data/journal_repository.dart';
import 'package:frontend/features/journal/model/journal_entry_model.dart';
import 'package:frontend/features/journal/model/question_model.dart';
import 'package:frontend/features/journal/presentation/screens/monitoring_screen.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_empty_state.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_entries_list.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_error_state.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_filter_bar.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_guest_empty.dart';
import 'package:frontend/features/journal/presentation/widgets/journal_header_strip.dart';
import 'package:frontend/features/journal/presentation/widgets/monitoring_summary_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
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

  List<JournalEntryModel> _applyFilters(List<JournalEntryModel> entries) {
    var filtered = entries;
    if (_dateFilter != null) {
      final target = DateTime(
        _dateFilter!.year,
        _dateFilter!.month,
        _dateFilter!.day,
      );
      filtered = filtered.where((e) {
        final d = e.submittedAt.toLocal();
        return DateTime(d.year, d.month, d.day) == target;
      }).toList();
    }
    final sorted = List<JournalEntryModel>.from(filtered);
    sorted.sort(
      (a, b) => _sortOrder == JournalSortOrder.newestFirst
          ? b.submittedAt.compareTo(a.submittedAt)
          : a.submittedAt.compareTo(b.submittedAt),
    );
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = cs.onSurfaceVariant;
    final accentColor = cs.primary;

    final entriesAsync = ref.watch(journalEntriesProvider);
    final questionsAsync = ref.watch(journalQuestionsProvider);
    final authUser = ref.watch(authStateProvider).asData?.value;
    final currentUser = ref.watch(currentUserProvider);
    final bool isGuest = authUser == null || authUser.isAnonymous;

    // Pre-compute filtered count for the header badge
    final rawEntries = entriesAsync.asData?.value;
    final displayCount = rawEntries != null
        ? _applyFilters(rawEntries).length
        : null;

    return Scaffold(
      backgroundColor: cs.surface,
      extendBody: true,
      drawerScrimColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.30)
          : Colors.black.withValues(alpha: 0.45),
      drawer: const LeftSidebar(),
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: Builder(
          builder: (BuildContext ctx) {
            return IconButton(
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              icon: Icon(Icons.menu_rounded, color: iconColor),
            );
          },
        ),
        title: const Text(
          'AGAPAY',
          style: TextStyle(
            fontFamily: 'TanSongbird',
            color: Colors.transparent,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 56, top: 12),
            child: Text(
              'AGAPAY',
              style: TextStyle(
                fontFamily: 'TanSongbird',
                color: accentColor,
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
        actions: const <Widget>[],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (currentUser?.status.toLowerCase() != 'active') {
            context.go('/onboarding');
            return;
          }
          Navigator.of(context)
              .push(
                MaterialPageRoute<void>(
                  builder: (_) => const MonitoringScreen(),
                ),
              )
              .then((_) => ref.invalidate(journalEntriesProvider));
        },
        backgroundColor: cs.primary.withValues(alpha: 0.85),
        foregroundColor: cs.onPrimary,
        elevation: 2,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Add Entry',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      bottomNavigationBar: BottomNavbar(
        selectedIndex: 1,
        onHomeTap: () => context.go('/community'),
        onJournalTap: () {},
        onNotificationsTap: () => context.go('/notifications'),
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
            child: isGuest
                ? const JournalGuestEmpty()
                : entriesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => JournalErrorState(
                      onRetry: () => ref.invalidate(journalEntriesProvider),
                    ),
                    data: (List<JournalEntryModel> entries) {
                      if (entries.isEmpty) return const JournalEmptyState();
                      final filtered = _applyFilters(entries);
                      final questions =
                          questionsAsync.asData?.value.questions ??
                          const <Question>[];
                      if (filtered.isEmpty) {
                        return _DateFilterEmpty(
                          date: _dateFilter!,
                          onClear: () => setState(() => _dateFilter = null),
                        );
                      }
                      return JournalEntriesList(
                        entries: filtered,
                        previewBuilder: (entry) =>
                            _buildPreviewWithQuestions(entry, questions),
                        onTapEntry: (entry) => Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    MonitoringScreen(existingEntry: entry),
                              ),
                            )
                            .then(
                              (_) => ref.invalidate(journalEntriesProvider),
                            ),
                      
                        onDeleteEntry: (entry) async {
                          try {
                            await ref
                                .read(journalRepositoryProvider)
                                .deleteEntry(entry.entryId);
                            ref.invalidate(journalEntriesProvider);
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to delete entry. Please try again.',
                                ),
                              ),
                            );
                          }
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

// ── Date filter empty state ────────────────────────────────────────────────────

class _DateFilterEmpty extends StatelessWidget {
  const _DateFilterEmpty({required this.date, required this.onClear});

  final DateTime date;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const months = <String>[
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
    final label = '${months[date.month - 1]} ${date.day}, ${date.year}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.event_busy_rounded,
              size: 56,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No entries on $label',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no journal entries recorded for this date.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onClear,
              icon: Icon(Icons.clear_all_rounded, color: cs.primary),
              label: Text(
                'Clear date filter',
                style: TextStyle(color: cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}