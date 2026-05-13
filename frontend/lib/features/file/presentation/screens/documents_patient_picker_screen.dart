import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/core/widgets/left_sidebar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/calendar/controller/calendar_provider.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/features/connections/model/patient_profile_model.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DocumentsPatientPickerScreen
//  Shown to doctors, caregivers, and secretaries when they tap "Documents".
//  Lists all connected patients; tapping one opens DocumentsScreen for that
//  patient.
// ─────────────────────────────────────────────────────────────────────────────

class DocumentsPatientPickerScreen extends ConsumerWidget {
  const DocumentsPatientPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bg = isDark ? Palette.darkSurfaceColor : const Color(0xFFF5F9F7);

    final currentUser = ref.watch(currentUserProvider);
    final role = currentUser?.role.toLowerCase() ?? '';
    final myUid = currentUser?.uid ?? '';

    final profilesAsync = ref.watch(patientProfilesProvider);

    // Secretaries are connected to doctors, not patients directly.
    // Use secretaryPatientsProvider to load patients via connected doctors.
    final bool isLoading;
    final List<String> patientUids;
    final Map<String, UserModel> userMap;

    if (role == 'secretary') {
      final secPatientsAsync = ref.watch(secretaryPatientsProvider);
      isLoading = secPatientsAsync.isLoading || profilesAsync.isLoading;
      final secPatients = secPatientsAsync.asData?.value ?? const [];
      userMap = {for (final u in secPatients) u.uid: u};
      patientUids = secPatients.map((u) => u.uid).toList();
    } else {
      final connectionsAsync = ref.watch(acceptedConnectionsProvider);
      final usersAsync = ref.watch(browsePatientsProvider);
      isLoading = connectionsAsync.isLoading || profilesAsync.isLoading;
      // Build a uid → UserModel map for quick avatar / name lookup.
      userMap = <String, UserModel>{
        for (final u in usersAsync.asData?.value ?? <UserModel>[]) u.uid: u,
      };
      // Only include UIDs that are actual patients (present in browsePatientsProvider
      // which is filtered to role=patient), so non-patient connections are excluded.
      patientUids =
          connectionsAsync.asData?.value
              .map((c) => c.otherUid(myUid))
              .where((uid) => userMap.containsKey(uid))
              .toSet()
              .toList() ??
          [];
    }

    final profiles = profilesAsync.asData?.value ?? {};

    return Scaffold(
      backgroundColor: bg,
      drawer: const LeftSidebar(),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (BuildContext ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: Icon(Icons.menu_rounded, color: cs.onSurfaceVariant),
          ),
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
            onPressed: () {
              ref.invalidate(patientProfilesProvider);
              if (role == 'secretary') {
                ref.invalidate(secretaryPatientsProvider);
                ref.invalidate(connectedCalendarDoctorsProvider);
              } else {
                ref.invalidate(acceptedConnectionsProvider);
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavbar(selectedIndex: -1),
      body: Builder(
        builder: (_) {
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
                  profile?.fullName ??
                  user?.displayName ??
                  user?.email ??
                  'Patient';

              return _PatientDocumentsTile(
                patientUid: uid,
                displayName: displayName,
                profile: profile,
                photoUrl: user?.photoUrl,
                isDark: isDark,
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Single patient tile
// ─────────────────────────────────────────────────────────────────────────────

class _PatientDocumentsTile extends StatelessWidget {
  const _PatientDocumentsTile({
    required this.patientUid,
    required this.displayName,
    required this.profile,
    required this.photoUrl,
    required this.isDark,
  });

  final String patientUid;
  final String displayName;
  final PatientProfileModel? profile;
  final String? photoUrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final parts = <String>[];
    if (profile != null) parts.add('${profile!.age} yrs');
    if (profile != null && profile!.illnessType.isNotEmpty) {
      parts.add(profile!.illnessType);
    }
    final subtitle = parts.isNotEmpty ? parts.join(' • ') : 'Patient';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          final encodedName = Uri.encodeComponent(displayName);
          context.push(
            '/documents?patientUid=$patientUid&patientName=$encodedName',
          );
        },
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
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _InitialsAvatar(
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
            const SizedBox(height: 10),
            Text(
              'Connect with patients to view their documents.',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
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
