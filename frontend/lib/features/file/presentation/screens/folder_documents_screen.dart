import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/features/file/controller/file_controller.dart';
import 'package:frontend/features/file/data/file_repository.dart';
import 'package:frontend/features/file/model/file_document_model.dart';
import 'package:frontend/features/file/model/storage_summary_model.dart';
import 'package:frontend/features/file/presentation/widgets/document_card.dart';
import 'package:frontend/features/file/presentation/widgets/file_filter_bar.dart';
import 'package:frontend/features/file/presentation/widgets/rename_dialog.dart';
import 'package:frontend/features/file/presentation/widgets/upload_progress_sheet.dart';
import 'package:frontend/theme/palette.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class FolderDocumentsScreen extends ConsumerStatefulWidget {
  const FolderDocumentsScreen({
    super.key,
    required this.folderId,
    required this.folderName,
    this.patientUid,
  });

  final String folderId;
  final String folderName;

  /// Non-null when a doctor/caregiver is viewing a connected patient's folder.
  final String? patientUid;

  @override
  ConsumerState<FolderDocumentsScreen> createState() =>
      _FolderDocumentsScreenState();
}

class _FolderDocumentsScreenState extends ConsumerState<FolderDocumentsScreen> {
  FileSortOrder _sortOrder = FileSortOrder.dateDesc;
  String _searchQuery = '';

  List<FileDocumentModel> _applyFilters(List<FileDocumentModel> docs) {
    var filtered = docs;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((d) => d.name.toLowerCase().contains(q))
          .toList();
    }

    final sorted = List<FileDocumentModel>.from(filtered);
    switch (_sortOrder) {
      case FileSortOrder.dateDesc:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case FileSortOrder.dateAsc:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case FileSortOrder.nameAsc:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case FileSortOrder.nameDesc:
        sorted.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeNotifierProvider);
    final cs = appTheme.colorScheme;
    final isDark = appTheme.brightness == Brightness.dark;
    final bg = isDark ? Palette.darkSurfaceColor : const Color(0xFFF5F9F7);

    final currentUser = ref.watch(currentUserProvider);
    final role = currentUser?.role.toLowerCase() ?? '';
    final currentUid = currentUser?.uid ?? '';
    final bool isReadOnly =
        (role == 'doctor' || role == 'secretary') && widget.patientUid == null;

    // Guard: verify connection before allowing access to another patient's folder.
    // Secretaries connect to doctors (not patients directly), so skip the
    // direct-connection check for them — the backend enforces authorization
    // via the secretary→doctor→patient chain.
    if (widget.patientUid != null && role != 'secretary') {
      final connectionsAsync = ref.watch(acceptedConnectionsProvider);
      if (connectionsAsync.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final connections = connectionsAsync.value ?? const [];
      final isConnected = connections.any(
        (c) => c.otherUid(currentUid) == widget.patientUid,
      );
      if (!isConnected) {
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 64,
                    color: cs.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are not connected to this patient.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    final docsAsync = widget.patientUid == null
        ? ref.watch(folderDocumentsProvider(widget.folderId))
        : ref.watch(
            patientFolderDocumentsProvider((
              patientUid: widget.patientUid!,
              folderId: widget.folderId,
            )),
          );

    final summaryAsync = widget.patientUid == null
        ? ref.watch(storageSummaryProvider)
        : ref.watch(patientStorageSummaryProvider(widget.patientUid!));

    final repo = ref.read(fileRepositoryProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: cs.onSurfaceVariant,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.folderName,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
      ),
      floatingActionButton: isReadOnly
          ? null
          : FloatingActionButton(
              onPressed: () => _pickAndUpload(context, repo),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              child: const Icon(Icons.upload_file_rounded),
            ),
      body: Column(
        children: <Widget>[
          // ── Storage usage bar ─────────────────────────────────────────
          summaryAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (summary) => _StorageBar(summary: summary, cs: cs),
          ),

          // ── Filter bar ─────────────────────────────────────────────────
          FileFilterBar(
            sortOrder: _sortOrder,
            onSortChanged: (o) => setState(() => _sortOrder = o),
            searchQuery: _searchQuery,
            onSearchChanged: (q) => setState(() => _searchQuery = q),
          ),

          // ── Document grid ─────────────────────────────────────────────
          Expanded(
            child: docsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _ErrorState(
                message: err.toString(),
                onRetry: () => _invalidateDocs(ref),
              ),
              data: (docs) {
                final filtered = _applyFilters(docs);
                if (filtered.isEmpty) {
                  return _EmptyState(
                    isReadOnly: isReadOnly,
                    isFiltered: _searchQuery.isNotEmpty,
                  );
                }
                return _DocumentsGrid(
                  docs: filtered,
                  folderId: widget.folderId,
                  patientUid: widget.patientUid,
                  isReadOnly: isReadOnly,
                  repo: repo,
                  ref: ref,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _invalidateDocs(WidgetRef ref) {
    if (widget.patientUid == null) {
      ref.invalidate(folderDocumentsProvider(widget.folderId));
    } else {
      ref.invalidate(
        patientFolderDocumentsProvider((
          patientUid: widget.patientUid!,
          folderId: widget.folderId,
        )),
      );
    }
  }

  Future<void> _pickAndUpload(BuildContext context, FileRepository repo) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final mime = _inferMime(file.extension ?? '');
    if (mime == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unsupported file type')));
      }
      return;
    }

    // Show upload sheet
    if (!context.mounted) return;
    ref.read(uploadProgressProvider.notifier).state = 0.0;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => UploadProgressSheet(
        fileName: file.name,
        onCancel: () => ref.read(uploadProgressProvider.notifier).state = null,
      ),
    );

    try {
      if (widget.patientUid != null) {
        await repo.uploadPatientDocument(
          patientUid: widget.patientUid!,
          folderId: widget.folderId,
          fileBytes: bytes,
          fileName: file.name,
          mimeType: mime,
        );
      } else {
        await repo.uploadDocument(
          folderId: widget.folderId,
          fileBytes: bytes,
          fileName: file.name,
          mimeType: mime,
        );
      }
      ref.read(uploadProgressProvider.notifier).state = null;
      _invalidateDocs(ref);
      if (widget.patientUid != null) {
        ref.invalidate(patientStorageSummaryProvider(widget.patientUid!));
      } else {
        ref.invalidate(storageSummaryProvider);
      }
    } catch (e) {
      ref.read(uploadProgressProvider.notifier).state = null;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  static String? _inferMime(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Storage usage linear bar
// ─────────────────────────────────────────────────────────────────────────────

class _StorageBar extends StatelessWidget {
  const _StorageBar({required this.summary, required this.cs});

  final StorageSummaryModel summary;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final pct = summary.usagePercentage / 100;
    final color = pct > 0.90
        ? cs.error
        : pct > 0.75
        ? Colors.orange
        : cs.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Storage',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
              Text(
                summary.usageLabel,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: cs.outlineVariant.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.55
                    : 0.30,
              ),
              color: color,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Document grid
// ─────────────────────────────────────────────────────────────────────────────

class _DocumentsGrid extends StatelessWidget {
  const _DocumentsGrid({
    required this.docs,
    required this.folderId,
    required this.patientUid,
    required this.isReadOnly,
    required this.repo,
    required this.ref,
  });

  final List<FileDocumentModel> docs;
  final String folderId;
  final String? patientUid;
  final bool isReadOnly;
  final FileRepository repo;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final int cols = w < 400
            ? 2
            : w < 700
            ? 3
            : w < 1000
            ? 4
            : 5;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            return DocumentCard(
              document: doc,
              isReadOnly: isReadOnly,
              onTap: () {
                final q = Uri(
                  queryParameters: {
                    'url': doc.fileUrl,
                    'name': doc.name,
                    'type': doc.fileType,
                  },
                );
                context.push('/documents/$folderId/view${q.toString()}');
              },
              onRename: isReadOnly ? null : () => _renameDocument(context, doc),
              onDelete: isReadOnly ? null : () => _deleteDocument(context, doc),
            );
          },
        );
      },
    );
  }

  void _invalidateDocs(WidgetRef ref) {
    if (patientUid == null) {
      ref.invalidate(folderDocumentsProvider(folderId));
    } else {
      ref.invalidate(
        patientFolderDocumentsProvider((
          patientUid: patientUid!,
          folderId: folderId,
        )),
      );
    }
  }

  Future<void> _renameDocument(
    BuildContext context,
    FileDocumentModel doc,
  ) async {
    final newName = await showRenameDialog(
      context,
      currentName: doc.name,
      title: 'Rename file',
    );
    if (newName == null || newName.isEmpty || newName == doc.name) return;

    try {
      if (patientUid != null) {
        await repo.renamePatientDocument(
          patientUid!,
          folderId,
          doc.id,
          newName,
        );
      } else {
        await repo.renameDocument(folderId, doc.id, newName);
      }
      _invalidateDocs(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to rename: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(
    BuildContext context,
    FileDocumentModel doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('"${doc.name}" will be permanently deleted.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (patientUid != null) {
        await repo.deletePatientDocument(patientUid!, folderId, doc.id);
        _invalidateDocs(ref);
        ref.invalidate(patientStorageSummaryProvider(patientUid!));
      } else {
        await repo.deleteDocument(folderId, doc.id);
        _invalidateDocs(ref);
        ref.invalidate(storageSummaryProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty & error states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isReadOnly, required this.isFiltered});
  final bool isReadOnly;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isFiltered
                ? Icons.search_off_rounded
                : Icons.insert_drive_file_outlined,
            size: 56,
            color: isDark
                ? Colors.white.withValues(alpha: 0.45)
                : cs.outlineVariant,
          ),
          const SizedBox(height: 14),
          Text(
            isFiltered
                ? 'No files match your search'
                : isReadOnly
                ? 'No files in this folder'
                : 'No files yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          if (!isReadOnly && !isFiltered) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Tap + to upload a file',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
