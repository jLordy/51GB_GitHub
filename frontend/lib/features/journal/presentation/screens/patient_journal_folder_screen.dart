import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/core/widgets/left_sidebar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/features/connections/model/patient_profile_model.dart';
import 'package:frontend/features/journal/controller/journal_controller.dart';
import 'package:frontend/features/journal/presentation/screens/patient_journal_screen.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Patient Journal Folder Screen
//  Shown to doctors, caregivers, and secretaries when they tap the Journal nav.
//  Each card represents a patient's journal "folder".
//  Secretaries see the patients of their connected doctor.
// ─────────────────────────────────────────────────────────────────────────────

class PatientJournalFolderScreen extends ConsumerWidget {
  const PatientJournalFolderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final currentUser = ref.watch(currentUserProvider);
    final isSecretary = currentUser?.role == 'secretary';

    final viewerRole = currentUser?.role == 'caregiver'
        ? PatientJournalViewerRole.caregiver
        : currentUser?.role == 'secretary'
        ? PatientJournalViewerRole.secretary
        : PatientJournalViewerRole.doctor;

    return Scaffold(
      backgroundColor: isDark
          ? Palette.darkSurfaceColor
          : const Color(0xFFF5F9F7),
      drawer: const LeftSidebar(),
      appBar: AppBar(
        backgroundColor: isDark
            ? Palette.darkSurfaceColor
            : const Color(0xFFF5F9F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (BuildContext ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: Icon(Icons.menu_rounded, color: cs.onSurfaceVariant),
          ),
        ),
        title: Text(
          'Patient Journals',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
            onPressed: () {
              if (isSecretary) {
                ref.invalidate(secretaryConnectedDoctorProvider);
                ref.invalidate(secretaryDoctorPatientsProvider);
              } else {
                ref.invalidate(acceptedConnectionsProvider);
                ref.invalidate(patientProfilesProvider);
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavbar(selectedIndex: 2),
      body: isSecretary
          ? _SecretaryJournalBody(isDark: isDark, viewerRole: viewerRole)
          : _DoctorCaregiverJournalBody(
              isDark: isDark,
              viewerRole: viewerRole,
              myUid: currentUser?.uid ?? '',
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Secretary journal body
//  Resolves the connected doctor UID, then delegates to _SecretaryPatientList.
// ─────────────────────────────────────────────────────────────────────────────

class _SecretaryJournalBody extends ConsumerWidget {
  const _SecretaryJournalBody({required this.isDark, required this.viewerRole});

  final bool isDark;
  final PatientJournalViewerRole viewerRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorAsync = ref.watch(secretaryConnectedDoctorProvider);

    return doctorAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _EmptyState(isDark: isDark),
      data: (doctorUid) {
        if (doctorUid == null || doctorUid.isEmpty) {
          return _EmptyState(isDark: isDark);
        }
        return _SecretaryPatientList(
          doctorUid: doctorUid,
          isDark: isDark,
          viewerRole: viewerRole,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Secretary patient list
//  Fetches the doctor's patients via secretaryDoctorPatientsProvider.
// ─────────────────────────────────────────────────────────────────────────────

class _SecretaryPatientList extends ConsumerWidget {
  const _SecretaryPatientList({
    required this.doctorUid,
    required this.isDark,
    required this.viewerRole,
  });

  final String doctorUid;
  final bool isDark;
  final PatientJournalViewerRole viewerRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(secretaryDoctorPatientsProvider(doctorUid));

    if (patientsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final patients = patientsAsync.asData?.value ?? const <UserModel>[];
    if (patients.isEmpty) return _EmptyState(isDark: isDark);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: patients.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = patients[index];
        return _PatientFolderTile(
          patientUid: user.uid,
          displayName: user.displayName ?? user.email ?? 'Patient',
          profile: null,
          photoUrl: user.photoUrl,
          viewerRole: viewerRole,
          isDark: isDark,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Doctor / caregiver journal body
//  Uses accepted connections filtered to role=patient UIDs.
// ─────────────────────────────────────────────────────────────────────────────

class _DoctorCaregiverJournalBody extends ConsumerWidget {
  const _DoctorCaregiverJournalBody({
    required this.isDark,
    required this.viewerRole,
    required this.myUid,
  });

  final bool isDark;
  final PatientJournalViewerRole viewerRole;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(acceptedConnectionsProvider);
    final profilesAsync = ref.watch(patientProfilesProvider);
    final usersAsync = ref.watch(browsePatientsProvider);

    final bool isLoading =
        connectionsAsync.isLoading || profilesAsync.isLoading;

    // Build a uid → UserModel map for quick avatar/name lookup.
    final userMap = {for (final u in usersAsync.asData?.value ?? []) u.uid: u};

    // Patient UIDs connected to the current user.
    // Filter to only UIDs in browsePatientsProvider (role=patient) so secretaries
    // and other non-patient roles are excluded.
    final patientUids =
        connectionsAsync.asData?.value
            .map((c) => c.otherUid(myUid))
            .where((uid) => userMap.containsKey(uid))
            .toSet()
            .toList() ??
        const <String>[];

    final profiles = profilesAsync.asData?.value ?? {};

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (patientUids.isEmpty) {
      return _EmptyState(isDark: isDark);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: patientUids.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final uid = patientUids[index];
        final profile = profiles[uid];
        final user = userMap[uid];
        final displayName =
            profile?.fullName ?? user?.displayName ?? user?.email ?? 'Patient';

        return _PatientFolderTile(
          patientUid: uid,
          displayName: displayName,
          profile: profile,
          photoUrl: user?.photoUrl,
          viewerRole: viewerRole,
          isDark: isDark,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Single patient folder tile
// ─────────────────────────────────────────────────────────────────────────────

class _PatientFolderTile extends ConsumerWidget {
  const _PatientFolderTile({
    required this.patientUid,
    required this.displayName,
    required this.profile,
    required this.photoUrl,
    required this.viewerRole,
    required this.isDark,
  });

  final String patientUid;
  final String displayName;
  final PatientProfileModel? profile;
  final String? photoUrl;
  final PatientJournalViewerRole viewerRole;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final entriesAsync = ref.watch(patientJournalEntriesProvider(patientUid));
    final entryCount = entriesAsync.asData?.value.length;

    final String subtitle = _buildSubtitle(entryCount);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PatientJournalScreen(
              patientUid: patientUid,
              patientName: displayName,
              viewerRole: viewerRole,
            ),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // ── Folder icon ───────────────────────────────────────────
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Palette.greenColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.folder_rounded,
                    size: 28,
                    color: Palette.greenColor,
                  ),
                ),
                const SizedBox(width: 14),

                // ── Name + subtitle ───────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // ── Avatar ────────────────────────────────────────────────
                _Avatar(
                  displayName: displayName,
                  photoUrl: photoUrl,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildSubtitle(int? entryCount) {
    final parts = <String>[];
    if (profile != null) parts.add('${profile!.age} yrs');
    if (entryCount != null) {
      parts.add('$entryCount ${entryCount == 1 ? 'entry' : 'entries'}');
    } else {
      parts.add('Loading…');
    }
    return parts.join(' • ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Circle avatar — photo URL when available, else coloured initials
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.displayName,
    required this.photoUrl,
    required this.isDark,
  });

  final String displayName;
  final String? photoUrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => _InitialsAvatar(
            displayName: displayName,
            size: size,
            isDark: isDark,
          ),
        ),
      );
    }
    return _InitialsAvatar(
      displayName: displayName,
      size: size,
      isDark: isDark,
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.displayName,
    required this.size,
    required this.isDark,
  });

  final String displayName;
  final double size;
  final bool isDark;

  String get _initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF43A97A), Palette.greenColor],
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          _initials,
          style: GoogleFonts.inter(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty state — no connected patients yet
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_rounded, size: 64, color: cs.outlineVariant),
            const SizedBox(height: 18),
            Text(
              'No connected patients',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Once a patient accepts your connection request, their journal will appear here.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
