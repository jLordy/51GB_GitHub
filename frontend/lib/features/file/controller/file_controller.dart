import 'package:frontend/features/file/data/file_repository.dart';
import 'package:frontend/features/file/model/file_document_model.dart';
import 'package:frontend/features/file/model/file_folder_model.dart';
import 'package:frontend/features/file/model/storage_summary_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// ── Patient self-access providers ────────────────────────────────────────────

/// Resolves the list of folders for the currently authenticated patient.
final fileFoldersProvider = FutureProvider<List<FileFolderModel>>((ref) async {
  return ref.read(fileRepositoryProvider).fetchFolders();
});

/// Resolves documents inside a folder for the current patient.
final folderDocumentsProvider =
    FutureProvider.family<List<FileDocumentModel>, String>((ref, folderId) {
      return ref.read(fileRepositoryProvider).fetchDocuments(folderId);
    });

/// Resolves the storage usage summary for the current patient.
final storageSummaryProvider = FutureProvider<StorageSummaryModel>((ref) async {
  return ref.read(fileRepositoryProvider).fetchStorageSummary();
});

// ── Connected-user access providers ──────────────────────────────────────────

/// Resolves the list of folders for a connected patient (doctor/caregiver/secretary).
final patientFileFoldersProvider =
    FutureProvider.family<List<FileFolderModel>, String>((
      ref,
      patientUid,
    ) async {
      return ref.read(fileRepositoryProvider).fetchPatientFolders(patientUid);
    });

/// Resolves documents inside a connected patient's folder.
/// The family key is a record: (patientUid, folderId).
final patientFolderDocumentsProvider =
    FutureProvider.family<
      List<FileDocumentModel>,
      ({String patientUid, String folderId})
    >((ref, args) {
      return ref
          .read(fileRepositoryProvider)
          .fetchPatientDocuments(args.patientUid, args.folderId);
    });

/// Resolves the storage summary for a connected patient.
final patientStorageSummaryProvider =
    FutureProvider.family<StorageSummaryModel, String>((ref, patientUid) {
      return ref
          .read(fileRepositoryProvider)
          .fetchPatientStorageSummary(patientUid);
    });

// ── Upload progress ───────────────────────────────────────────────────────────

/// null = not uploading; 0.0–1.0 = progress fraction.
final uploadProgressProvider = StateProvider<double?>((ref) => null);
