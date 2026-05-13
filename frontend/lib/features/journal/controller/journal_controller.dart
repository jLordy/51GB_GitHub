import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/journal/data/journal_repository.dart';
import 'package:frontend/features/journal/model/journal_entry_model.dart';
import 'package:frontend/features/journal/model/question_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the list of journal entries for the current patient.
/// Re-fetches whenever the provider is invalidated (e.g. after saving a new entry).
///
/// Watching [authStateProvider] ensures the cached result is discarded and
/// re-fetched whenever the signed-in user changes, preventing one patient
/// from seeing another patient's cached journal entries.
final journalEntriesProvider = FutureProvider<List<JournalEntryModel>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Future.value([]);
  return ref.read(journalRepositoryProvider).fetchEntries();
});

/// Fetches the daily monitoring questions for the current patient.
/// Re-evaluates when the signed-in user changes (same auth-guard as above).
final journalQuestionsProvider = FutureProvider<JournalQuestionsResponse>((
  ref,
) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) {
    return Future.error('Not authenticated', StackTrace.current);
  }
  return ref.read(journalRepositoryProvider).fetchQuestions();
});

/// Fetches journal entries for a *connected* patient, keyed by [patientUid].
///
/// Used by doctors (read-only) and caregivers (read + write) to view the
/// entries of a patient they are connected to.  Re-invalidate this provider
/// after a caregiver creates or edits an entry to refresh the list.
final patientJournalEntriesProvider =
    FutureProvider.family<List<JournalEntryModel>, String>((ref, patientUid) {
      final user = ref.watch(authStateProvider).asData?.value;
      if (user == null) return Future.value([]);
      return ref.read(journalRepositoryProvider).listPatientEntries(patientUid);
    });

/// Fetches daily monitoring questions for a connected patient, keyed by [patientUid].
///
/// Used by doctor/caregiver journal screens to format entry previews using
/// the same question metadata as Monitoring summary.
final patientJournalQuestionsProvider =
    FutureProvider.family<JournalQuestionsResponse, String>((ref, patientUid) {
      final user = ref.watch(authStateProvider).asData?.value;
      if (user == null) {
        return Future.error('Not authenticated', StackTrace.current);
      }
      return ref
          .read(journalRepositoryProvider)
          .fetchPatientQuestions(patientUid);
    });