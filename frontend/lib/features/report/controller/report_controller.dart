import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/report/data/report_repository.dart';
import 'package:frontend/features/report/model/report_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// ---------------------------------------------------------------------------
// List providers
// ---------------------------------------------------------------------------

/// All saved reports for the currently signed-in patient.
final reportListProvider = FutureProvider<List<ReportModel>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Future.value([]);
  return ref.read(reportRepositoryProvider).listReports();
});

/// All saved reports for a *connected* patient (professional use).
final patientReportListProvider =
    FutureProvider.family<List<ReportModel>, String>((ref, patientUid) {
      final user = ref.watch(authStateProvider).asData?.value;
      if (user == null) return Future.value([]);
      return ref.read(reportRepositoryProvider).listPatientReports(patientUid);
    });

// ---------------------------------------------------------------------------
// Generate-summary notifier
// ---------------------------------------------------------------------------

class GenerateSummaryState {
  const GenerateSummaryState({
    this.content,
    this.isLoading = false,
    this.error,
  });

  final String? content;
  final bool isLoading;
  final String? error;

  GenerateSummaryState copyWith({
    String? content,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearContent = false,
  }) {
    return GenerateSummaryState(
      content: clearContent ? null : (content ?? this.content),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class GenerateSummaryNotifier extends StateNotifier<GenerateSummaryState> {
  GenerateSummaryNotifier(this._repo) : super(const GenerateSummaryState());

  final ReportRepository _repo;

  // Patient — generate for own journals
  Future<void> generateOwn({
    required String startDate,
    required String endDate,
    required String period,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final content = await _repo.generateSummary(
        startDate: startDate,
        endDate: endDate,
        period: period,
      );
      state = GenerateSummaryState(content: content);
    } catch (e) {
      state = GenerateSummaryState(error: e.toString());
    }
  }

  // Professional — generate for connected patient
  Future<void> generateForPatient({
    required String patientUid,
    required String startDate,
    required String endDate,
    required String period,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final content = await _repo.generatePatientSummary(
        patientUid: patientUid,
        startDate: startDate,
        endDate: endDate,
        period: period,
      );
      state = GenerateSummaryState(content: content);
    } catch (e) {
      state = GenerateSummaryState(error: e.toString());
    }
  }

  void setContent(String content) {
    state = state.copyWith(content: content);
  }

  void clear() {
    state = const GenerateSummaryState();
  }
}

final generateSummaryNotifierProvider =
    StateNotifierProvider.autoDispose<
      GenerateSummaryNotifier,
      GenerateSummaryState
    >((ref) => GenerateSummaryNotifier(ref.read(reportRepositoryProvider)));

// ---------------------------------------------------------------------------
// Save-report notifier
// ---------------------------------------------------------------------------

class SaveReportNotifier extends StateNotifier<AsyncValue<ReportModel?>> {
  SaveReportNotifier(this._repo, this._ref)
    : super(const AsyncValue.data(null));

  final ReportRepository _repo;
  final Ref _ref;

  Future<void> saveOwn({
    required String startDate,
    required String endDate,
    required String period,
    required String content,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.saveReport(
        startDate: startDate,
        endDate: endDate,
        period: period,
        content: content,
      ),
    );
    if (!state.hasError) {
      _ref.invalidate(reportListProvider);
    }
  }

  Future<void> saveForPatient({
    required String patientUid,
    required String startDate,
    required String endDate,
    required String period,
    required String content,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.savePatientReport(
        patientUid: patientUid,
        startDate: startDate,
        endDate: endDate,
        period: period,
        content: content,
      ),
    );
    if (!state.hasError) {
      _ref.invalidate(patientReportListProvider(patientUid));
    }
  }
}

final saveReportNotifierProvider =
    StateNotifierProvider.autoDispose<
      SaveReportNotifier,
      AsyncValue<ReportModel?>
    >((ref) => SaveReportNotifier(ref.read(reportRepositoryProvider), ref));

// ---------------------------------------------------------------------------
// Update-report notifier
// ---------------------------------------------------------------------------

class UpdateReportNotifier extends StateNotifier<AsyncValue<ReportModel?>> {
  UpdateReportNotifier(this._repo, this._ref)
    : super(const AsyncValue.data(null));

  final ReportRepository _repo;
  final Ref _ref;

  Future<void> updateOwn({
    required String reportId,
    required String content,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.updateReport(reportId: reportId, content: content),
    );
    if (!state.hasError) {
      _ref.invalidate(reportListProvider);
    }
  }

  Future<void> updateForPatient({
    required String patientUid,
    required String reportId,
    required String content,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.updatePatientReport(
        patientUid: patientUid,
        reportId: reportId,
        content: content,
      ),
    );
    if (!state.hasError) {
      _ref.invalidate(patientReportListProvider(patientUid));
    }
  }
}

final updateReportNotifierProvider =
    StateNotifierProvider.autoDispose<
      UpdateReportNotifier,
      AsyncValue<ReportModel?>
    >((ref) => UpdateReportNotifier(ref.read(reportRepositoryProvider), ref));

// ---------------------------------------------------------------------------
// Download-PDF notifier
// ---------------------------------------------------------------------------

class DownloadPdfState {
  const DownloadPdfState({this.isLoading = false, this.bytes, this.error});

  final bool isLoading;
  final List<int>? bytes;
  final String? error;

  DownloadPdfState copyWith({
    bool? isLoading,
    List<int>? bytes,
    String? error,
    bool clearError = false,
    bool clearBytes = false,
  }) {
    return DownloadPdfState(
      isLoading: isLoading ?? this.isLoading,
      bytes: clearBytes ? null : (bytes ?? this.bytes),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DownloadPdfNotifier extends StateNotifier<DownloadPdfState> {
  DownloadPdfNotifier(this._repo) : super(const DownloadPdfState());

  final ReportRepository _repo;

  Future<void> downloadOwn({
    required String startDate,
    required String endDate,
    required String period,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearBytes: true);
    try {
      final bytes = await _repo.generatePdf(
        startDate: startDate,
        endDate: endDate,
        period: period,
      );
      state = DownloadPdfState(bytes: bytes);
    } catch (e) {
      state = DownloadPdfState(error: e.toString());
    }
  }

  Future<void> downloadForPatient({
    required String patientUid,
    required String patientName,
    required String startDate,
    required String endDate,
    required String period,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearBytes: true);
    try {
      final bytes = await _repo.generatePatientPdf(
        patientUid: patientUid,
        patientName: patientName,
        startDate: startDate,
        endDate: endDate,
        period: period,
      );
      state = DownloadPdfState(bytes: bytes);
    } catch (e) {
      state = DownloadPdfState(error: e.toString());
    }
  }

  void clear() => state = const DownloadPdfState();
}

final downloadPdfNotifierProvider =
    StateNotifierProvider.autoDispose<DownloadPdfNotifier, DownloadPdfState>(
      (ref) => DownloadPdfNotifier(ref.read(reportRepositoryProvider)),
    );

// ---------------------------------------------------------------------------
// Delete-report notifier
// ---------------------------------------------------------------------------

class DeleteReportNotifier extends StateNotifier<AsyncValue<void>> {
  DeleteReportNotifier(this._repo, this._ref)
    : super(const AsyncValue.data(null));

  final ReportRepository _repo;
  final Ref _ref;

  Future<void> deleteOwn(String reportId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.deleteReport(reportId));
    if (!state.hasError) {
      _ref.invalidate(reportListProvider);
    }
  }

  Future<void> deleteForPatient({
    required String patientUid,
    required String reportId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () =>
          _repo.deletePatientReport(patientUid: patientUid, reportId: reportId),
    );
    if (!state.hasError) {
      _ref.invalidate(patientReportListProvider(patientUid));
    }
  }
}

final deleteReportNotifierProvider =
    StateNotifierProvider<DeleteReportNotifier, AsyncValue<void>>(
      (ref) => DeleteReportNotifier(ref.read(reportRepositoryProvider), ref),
    );
