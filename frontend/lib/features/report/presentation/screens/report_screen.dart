import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/core/widgets/custom_snackbar.dart';
import 'package:frontend/core/widgets/left_sidebar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/report/controller/report_controller.dart';
import 'package:frontend/features/report/data/report_repository.dart';
import 'package:frontend/features/report/model/report_model.dart';
import 'package:frontend/features/report/presentation/screens/pdf_preview_screen.dart';
import 'package:frontend/features/report/presentation/widgets/date_range_row.dart';
import 'package:frontend/features/report/presentation/widgets/period_selector.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _kPeriods = ['Week', 'Month', 'Year', 'Custom'];

/// Main report screen.
///
/// [patientUid] and [patientName] are non-null when a professional opens this
/// screen after selecting a patient. They are null for the patient's own view.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, this.patientUid, this.patientName});

  final String? patientUid;
  final String? patientName;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  String _period = 'Month';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _applyPeriodPreset('Month');
  }

  // -------------------------------------------------------------------------
  // Period preset logic
  // -------------------------------------------------------------------------

  void _applyPeriodPreset(String period) {
    final now = DateTime.now();
    setState(() {
      _period = period;
      switch (period) {
        case 'Week':
          _startDate = now.subtract(const Duration(days: 6));
          _endDate = now;
        case 'Month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
        case 'Year':
          _startDate = DateTime(now.year, 1, 1);
          _endDate = now;
        case 'Custom':
          break;
      }
    });
  }

  // -------------------------------------------------------------------------
  // Generate PDF and open preview
  // -------------------------------------------------------------------------

  Future<void> _generateAndPreview() async {
    if (_startDate == null || _endDate == null) {
      _showSnack('Please select a date range first.');
      return;
    }
    final notifier = ref.read(downloadPdfNotifierProvider.notifier);
    final start = DateRangeRow.formatDate(_startDate!);
    final end = DateRangeRow.formatDate(_endDate!);
    final periodKey = _period.toLowerCase();

    if (widget.patientUid != null) {
      await notifier.downloadForPatient(
        patientUid: widget.patientUid!,
        patientName: widget.patientName ?? '',
        startDate: start,
        endDate: end,
        period: periodKey,
      );
    } else {
      await notifier.downloadOwn(
        startDate: start,
        endDate: end,
        period: periodKey,
      );
    }

    final pdfState = ref.read(downloadPdfNotifierProvider);
    if (pdfState.bytes != null) {
      // Invalidate history so the newly saved record appears.
      if (widget.patientUid != null) {
        ref.invalidate(patientReportListProvider(widget.patientUid!));
      } else {
        ref.invalidate(reportListProvider);
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            bytes: pdfState.bytes!,
            filename: 'health_diary.pdf',
          ),
        ),
      );
    } else if (pdfState.error != null) {
      _showSnack('Error: ${pdfState.error}');
    }
  }

  // Fetch the stored PDF for a saved report and open preview (no re-generation).
  Future<void> _previewSavedReport(ReportModel report) async {
    try {
      final repo = ref.read(reportRepositoryProvider);
      final List<int> bytes;
      if (widget.patientUid != null) {
        bytes = await repo.getPatientPdfForReport(
          patientUid: widget.patientUid!,
          reportId: report.reportId,
        );
      } else {
        bytes = await repo.getPdfForReport(report.reportId);
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(bytes: bytes, filename: 'health_diary.pdf'),
        ),
      );
    } catch (e) {
      _showSnack('Failed to load report: $e');
    }
  }

  Future<void> _confirmDelete(ReportModel report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete report?'),
        content: const Text(
          'This record will be permanently deleted and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final notifier = ref.read(deleteReportNotifierProvider.notifier);
    if (widget.patientUid != null) {
      await notifier.deleteForPatient(
        patientUid: widget.patientUid!,
        reportId: report.reportId,
      );
    } else {
      await notifier.deleteOwn(report.reportId);
    }
    if (!mounted) return;
    final state = ref.read(deleteReportNotifierProvider);
    if (state.hasError) {
      _showSnack('Error deleting: ${state.error}');
    } else {
      _showSnack('Report deleted.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    AppSnackBar.show(context, msg, type: SnackBarType.info);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final pdfState = ref.watch(downloadPdfNotifierProvider);
    final currentUid = ref.watch(authStateProvider).asData?.value?.uid;

    final reportsAsync = widget.patientUid != null
        ? ref.watch(patientReportListProvider(widget.patientUid!))
        : ref.watch(reportListProvider);

    final String title = widget.patientName != null
        ? '${widget.patientName}\'s Report'
        : 'Report';

    return Scaffold(
      backgroundColor: isDark
          ? Palette.darkSurfaceColor
          : const Color(0xFFF5F9F7),
      drawerScrimColor: isDark
          ? Colors.black.withValues(alpha: 0.30)
          : Colors.black.withValues(alpha: 0.45),
      drawer: const LeftSidebar(),
      appBar: AppBar(
        backgroundColor: isDark
            ? Palette.darkSurfaceColor
            : const Color(0xFFF5F9F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu_rounded, color: cs.onSurfaceVariant),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.3,
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavbar(selectedIndex: 4),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Period selector ───────────────────────────────────────────
            PeriodSelector(
              periods: _kPeriods,
              selected: _period,
              onChanged: _applyPeriodPreset,
            ),
            const SizedBox(height: 12),

            // ── Date range ────────────────────────────────────────────────
            DateRangeRow(
              startDate: _startDate,
              endDate: _endDate,
              onStartChanged: (d) => setState(() {
                _startDate = d;
                _period = 'Custom';
              }),
              onEndChanged: (d) => setState(() {
                _endDate = d;
                _period = 'Custom';
              }),
            ),
            const SizedBox(height: 20),

            // ── Generate Report button ────────────────────────────────────
            ElevatedButton.icon(
              onPressed: pdfState.isLoading ? null : _generateAndPreview,
              icon: pdfState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: Text(
                pdfState.isLoading
                    ? 'Building report\u2026'
                    : 'Generate Report',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.greenColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            if (pdfState.error != null) ...[
              const SizedBox(height: 8),
              Text(
                pdfState.error!,
                style: GoogleFonts.inter(fontSize: 13, color: cs.error),
              ),
            ],

            const SizedBox(height: 32),

            // ── Report history ────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Report History',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            reportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(
                'Could not load history: $e',
                style: GoogleFonts.inter(fontSize: 13, color: cs.error),
              ),
              data: (reports) => reports.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No past reports yet.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Column(
                      children: reports
                          .map(
                            (r) => _ReportTile(
                              report: r,
                              isDark: isDark,
                              cs: cs,
                              onTap: () => _previewSavedReport(r),
                              onDelete: r.generatedByUid == currentUid
                                  ? () => _confirmDelete(r)
                                  : null,
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Report history tile
// ---------------------------------------------------------------------------

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.report,
    required this.isDark,
    required this.cs,
    required this.onTap,
    required this.onDelete,
  });

  final ReportModel report;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, yyyy');
    final label =
        '${df.format(report.startDate)} \u2014 ${df.format(report.endDate)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Palette.greenColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 20,
                    color: Palette.greenColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        _capitalize(report.period),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: cs.error,
                    ),
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
