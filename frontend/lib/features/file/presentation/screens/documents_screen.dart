import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/core/widgets/left_sidebar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/features/file/presentation/screens/documents_patient_picker_screen.dart';
import 'package:frontend/features/file/controller/file_controller.dart';
import 'package:frontend/features/file/data/file_repository.dart';
import 'package:frontend/features/file/model/file_folder_model.dart';
import 'package:frontend/features/file/presentation/widgets/create_folder_dialog.dart';
import 'package:frontend/features/file/presentation/widgets/folder_card.dart';
import 'package:frontend/features/file/presentation/widgets/rename_dialog.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DocumentsScreen — folder grid (root of the documents feature)
//
//  When [patientUid] is null, shows the current patient's own folders.
//  When non-null, shows a connected patient's folders (doctor/caregiver view).
// ─────────────────────────────────────────────────────────────────────────────

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key, this.patientUid, this.patientName});

  /// Set by the router when a doctor/caregiver opens a patient's documents.
  final String? patientUid;

  /// Display name of the patient — used for the app bar title.
  final String? patientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Palette.darkSurfaceColor : const Color(0xFFF5F9F7);

    final currentUser = ref.watch(currentUserProvider);
    final role = currentUser?.role.toLowerCase() ?? '';
    final currentUid = currentUser?.uid ?? '';

    // Doctor and secretary can write when viewing a connected patient's docs;
    // they have no documents of their own so the picker always redirects them.
    final bool isReadOnly =
        (role == 'doctor' || role == 'secretary') && patientUid == null;

    // Caregivers, doctors, and secretaries do not have their own patient records.
    // Show the patient picker so they can choose who to view.
    if (patientUid == null &&
        (role == 'caregiver' || role == 'doctor' || role == 'secretary')) {
      return const DocumentsPatientPickerScreen();
    }

    // When viewing another patient's documents, verify an accepted connection
    // exists before allowing access. Secretaries connect to doctors (not patients
    // directly), so we skip the direct-connection check for them — the backend
    // already enforces authorization via the secretary/doctor/patient chain.
    if (patientUid != null && role != 'secretary') {
      final connectionsAsync = ref.watch(acceptedConnectionsProvider);
      if (connectionsAsync.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final connections = connectionsAsync.value ?? const [];
      final isConnected = connections.any(
        (c) => c.otherUid(currentUid) == patientUid,
      );
      if (!isConnected) {
        return _AccessDeniedScaffold(bg: bg);
      }
    }

    final foldersAsync = patientUid == null
        ? ref.watch(fileFoldersProvider)
        : ref.watch(patientFileFoldersProvider(patientUid!));

    final repo = ref.read(fileRepositoryProvider);

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      drawerScrimColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.30)
          : Colors.black.withValues(alpha: 0.45),
      drawer: patientUid == null ? const LeftSidebar() : null,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: patientUid != null
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () => context.pop(),
              )
            : Builder(
                builder: (BuildContext ctx) => IconButton(
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  icon: Icon(Icons.menu_rounded, color: cs.onSurfaceVariant),
                ),
              ),
        title: Text(
          patientUid == null
              ? 'Documents'
              : patientName != null
              ? "$patientName's Documents"
              : 'Patient Documents',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      floatingActionButton: isReadOnly
          ? null
          : FloatingActionButton(
              onPressed: () => _createFolder(context, ref, repo),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              child: const Icon(Icons.create_new_folder_outlined),
            ),
      bottomNavigationBar: const BottomNavbar(selectedIndex: -1),
      body: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(
          message: err.toString(),
          onRetry: () => patientUid == null
              ? ref.invalidate(fileFoldersProvider)
              : ref.invalidate(patientFileFoldersProvider(patientUid!)),
        ),
        data: (folders) => folders.isEmpty
            ? _EmptyState(isReadOnly: isReadOnly)
            : _FolderGrid(
                folders: folders,
                patientUid: patientUid,
                isReadOnly: isReadOnly,
                repo: repo,
                ref: ref,
              ),
      ),
    );
  }

  Future<void> _createFolder(
    BuildContext context,
    WidgetRef ref,
    dynamic repo,
  ) async {
    final name = await showCreateFolderDialog(context);
    if (name == null || name.isEmpty) return;

    try {
      if (patientUid != null) {
        await repo.createPatientFolder(patientUid!, name);
        ref.invalidate(patientFileFoldersProvider(patientUid!));
      } else {
        await repo.createFolder(name);
        ref.invalidate(fileFoldersProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create folder: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Folder grid
// ─────────────────────────────────────────────────────────────────────────────

class _FolderGrid extends StatelessWidget {
  const _FolderGrid({
    required this.folders,
    required this.patientUid,
    required this.isReadOnly,
    required this.repo,
    required this.ref,
  });

  final List<FileFolderModel> folders;
  final String? patientUid;
  final bool isReadOnly;
  final dynamic repo;
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: folders.length,
          itemBuilder: (ctx, i) {
            final folder = folders[i];
            return FolderCard(
              folder: folder,
              isReadOnly: isReadOnly,
              onTap: () {
                final extra = <String, String>{
                  'name': folder.name,
                  'patientUid': ?patientUid,
                };
                context.push('/documents/${folder.id}', extra: extra);
              },
              onRename: isReadOnly || folder.isDefault
                  ? null
                  : () => _renameFolder(context, folder),
              onDelete: isReadOnly || folder.isDefault
                  ? null
                  : () => _deleteFolder(context, folder),
            );
          },
        );
      },
    );
  }

  Future<void> _renameFolder(
    BuildContext context,
    FileFolderModel folder,
  ) async {
    final newName = await showRenameDialog(
      context,
      currentName: folder.name,
      title: 'Rename folder',
    );
    if (newName == null || newName.isEmpty || newName == folder.name) return;

    try {
      if (patientUid != null) {
        await repo.renamePatientFolder(patientUid!, folder.id, newName);
        ref.invalidate(patientFileFoldersProvider(patientUid!));
      } else {
        await repo.renameFolder(folder.id, newName);
        ref.invalidate(fileFoldersProvider);
      }
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

  Future<void> _deleteFolder(
    BuildContext context,
    FileFolderModel folder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'All files inside "${folder.name}" will be permanently deleted.',
        ),
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
        await repo.deletePatientFolder(patientUid!, folder.id);
        ref.invalidate(patientFileFoldersProvider(patientUid!));
      } else {
        await repo.deleteFolder(folder.id);
        ref.invalidate(fileFoldersProvider);
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
  const _EmptyState({required this.isReadOnly});
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.folder_open_outlined, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            isReadOnly ? 'No documents yet' : 'No folders yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          if (!isReadOnly) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Tap + to create a folder',
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

// ─────────────────────────────────────────────────────────────────────────────
//  Access denied — shown when the viewer is not connected to the patient
// ─────────────────────────────────────────────────────────────────────────────

class _AccessDeniedScaffold extends StatelessWidget {
  const _AccessDeniedScaffold({required this.bg});
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          'Patient Documents',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.3,
          ),
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
