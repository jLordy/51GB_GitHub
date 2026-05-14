import 'package:frontend/core/widgets/custom_snackbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/features/connections/model/connection_model.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class AddConnectionSheet extends ConsumerStatefulWidget {
  const AddConnectionSheet({super.key});

  @override
  ConsumerState<AddConnectionSheet> createState() => _AddConnectionSheetState();
}

class _AddConnectionSheetState extends ConsumerState<AddConnectionSheet> {
  // Patient-side: tracks in-flight send requests
  final Map<String, bool> _sending = {};
  // Care-provider side: tracks in-flight accept/decline actions per connectionId
  final Map<String, bool> _actioning = {};

  @override
  void initState() {
    super.initState();
    // Refresh pending requests every time the sheet opens so recipients always
    // see the latest incoming requests without needing an app restart.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(pendingConnectionsProvider.notifier).refresh();
      }
    });
  }

  // ── Patient: send connection request ──────────────────────────────────────
  Future<void> _sendRequest(UserModel user) async {
    setState(() => _sending[user.uid] = true);
    try {
      await sendConnectionRequest(ref, user.uid);
      if (mounted) {
        AppSnackBar.show(
          context,
          'Connection request sent to ${user.displayName ?? user.email ?? 'user'}!',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final is409 =
          e is DioException && (e.response?.statusCode == 409);
      AppSnackBar.show(
        context,
        is409
            ? 'Request already sent — waiting for their response.'
            : 'Failed to send request. Please try again.',
        type: is409 ? SnackBarType.info : SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _sending[user.uid] = false);
    }
  }

  // ── Care-provider: accept incoming request ────────────────────────────────
  Future<void> _acceptRequest(String connectionId) async {
    setState(() => _actioning[connectionId] = true);
    try {
      await ref.read(pendingConnectionsProvider.notifier).accept(connectionId);
      if (mounted) {
        AppSnackBar.show(
          context,
          'Connection accepted!',
          type: SnackBarType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'Failed to accept request. Please try again.',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _actioning.remove(connectionId));
    }
  }

  // ── Care-provider: decline incoming request ───────────────────────────────
  Future<void> _declineRequest(String connectionId) async {
    setState(() => _actioning[connectionId] = true);
    try {
      await ref.read(pendingConnectionsProvider.notifier).decline(connectionId);
      if (mounted) {
        AppSnackBar.show(context, 'Request declined.', type: SnackBarType.info);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'Failed to decline request. Please try again.',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _actioning.remove(connectionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final myRole = currentUser?.role ?? '';

    if (myRole == 'doctor') {
      return _buildCareProviderSheet(context);
    }
    if (myRole == 'caregiver') {
      return _buildCaregiverSheet(context);
    }
    return _buildPatientSheet(context);
  }

  // ── Sheet for caregivers: tabbed — incoming requests + find patients ────────
  Widget _buildCaregiverSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingAsync = ref.watch(pendingConnectionsProvider);
    final patientsAsync = ref.watch(browsePatientsProvider);
    final usersAsync = ref.watch(browseUsersProvider);
    final secretariesAsync = ref.watch(browseSecretariesProvider);
    final connectionsState = ref.watch(acceptedConnectionsProvider);
    final authUser = ref.watch(authStateProvider).asData?.value;
    final currentUid = authUser?.uid ?? '';

    final connectedUids = <String>{currentUid};
    if (connectionsState.hasValue) {
      for (final c in connectionsState.value!) {
        connectedUids.add(c.requesterUid);
        connectedUids.add(c.recipientUid);
      }
    }
    if (pendingAsync.hasValue) {
      for (final c in pendingAsync.value!) {
        connectedUids.add(c.requesterUid);
        connectedUids.add(c.recipientUid);
      }
    }

    return DefaultTabController(
      length: 2,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Palette.darkOutlineColor
                      : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Health Circle',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Palette.darkOnSurfaceColor
                      : const Color(0xFF1A1A2E),
                ),
              ),
            ),
            // Tabs
            TabBar(
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              labelColor: Palette.greenColor,
              unselectedLabelColor: isDark
                  ? Palette.darkOnSurfaceVariantColor
                  : const Color(0xFF6B7280),
              indicatorColor: Palette.greenColor,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Requests'),
                Tab(text: 'Find Patients'),
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: TabBarView(
                children: [
                  // ── Tab 1: Pending incoming requests ──────────────────────
                  _buildPendingList(
                    context,
                    isDark: isDark,
                    pendingAsync: pendingAsync,
                    patientsAsync: patientsAsync,
                    usersAsync: usersAsync,
                    secretariesAsync: secretariesAsync,
                  ),
                  // ── Tab 2: Browse patients to send requests ─────────────
                  patientsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          color: Palette.greenColor,
                        ),
                      ),
                    ),
                    error: (_, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Could not load patients.',
                          style: GoogleFonts.inter(
                            color: isDark
                                ? Palette.darkOnSurfaceVariantColor
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    data: (List<UserModel> patients) {
                      final available = patients
                          .where((u) => !connectedUids.contains(u.uid))
                          .toList(growable: false);
                      if (available.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No available patients to connect with.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: isDark
                                    ? Palette.darkOnSurfaceVariantColor
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: available.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = available[index];
                          final isSending = _sending[user.uid] ?? false;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            leading: _PatientAvatar(
                              name: user.displayName ?? user.email ?? user.uid,
                            ),
                            title: Text(
                              user.displayName ?? user.email ?? user.uid,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Palette.darkOnSurfaceColor
                                    : const Color(0xFF1A1A2E),
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1A2820)
                                        : const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Patient',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Palette.greenColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            trailing: isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Palette.greenColor,
                                    ),
                                  )
                                : TextButton(
                                    onPressed: () => _sendRequest(user),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Palette.greenColor,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      textStyle: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    child: const Text('Connect'),
                                  ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sheet for doctors: incoming requests ──────────────────────────────────
  Widget _buildCareProviderSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingAsync = ref.watch(pendingConnectionsProvider);
    final patientsAsync = ref.watch(browsePatientsProvider);
    final usersAsync = ref.watch(browseUsersProvider);
    final secretariesAsync = ref.watch(browseSecretariesProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Palette.darkOutlineColor
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Connection Requests',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? Palette.darkOnSurfaceColor
                    : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Patients requesting to connect with you.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark
                    ? Palette.darkOnSurfaceVariantColor
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: _buildPendingList(
              context,
              isDark: isDark,
              pendingAsync: pendingAsync,
              patientsAsync: patientsAsync,
              usersAsync: usersAsync,
              secretariesAsync: secretariesAsync,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingList(
    BuildContext context, {
    required bool isDark,
    required AsyncValue<List<ConnectionModel>> pendingAsync,
    required AsyncValue<List<UserModel>> patientsAsync,
    required AsyncValue<List<UserModel>> usersAsync,
    required AsyncValue<List<UserModel>> secretariesAsync,
  }) {
    if (pendingAsync.isLoading ||
        patientsAsync.isLoading ||
        usersAsync.isLoading ||
        secretariesAsync.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Palette.greenColor),
        ),
      );
    }
    if (pendingAsync.hasError ||
        patientsAsync.hasError ||
        usersAsync.hasError ||
        secretariesAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Could not load requests.',
            style: GoogleFonts.inter(
              color: isDark
                  ? Palette.darkOnSurfaceVariantColor
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    final pending = pendingAsync.value ?? [];
    final patients = patientsAsync.value ?? [];
    final allUsers = usersAsync.value ?? [];
    final secretaries = secretariesAsync.value ?? [];
    // Merge all roles so any requester (patient/secretary/doctor/caregiver) resolves to a name.
    final patientMap = <String, UserModel>{
      for (final u in [...patients, ...allUsers, ...secretaries]) u.uid: u,
    };

    if (pending.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 44,
                color:
                    (isDark
                            ? Palette.darkOnSurfaceColor
                            : const Color(0xFF374151))
                        .withValues(alpha: 0.25),
              ),
              const SizedBox(height: 12),
              Text(
                'No pending requests',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color:
                      (isDark
                              ? Palette.darkOnSurfaceColor
                              : const Color(0xFF374151))
                          .withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Patients can send you a request\nto join your circle.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color:
                      (isDark
                              ? Palette.darkOnSurfaceColor
                              : const Color(0xFF374151))
                          .withValues(alpha: 0.35),
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: pending.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conn = pending[index];
        final requester = patientMap[conn.requesterUid];
        final name =
            requester?.displayName ?? requester?.email ?? conn.requesterUid;
        final role = requester?.role ?? 'unknown';
        final isActioning = _actioning[conn.connectionId] ?? false;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 4,
          ),
          leading: _PatientAvatar(name: name),
          title: Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Palette.darkOnSurfaceColor
                  : const Color(0xFF1A1A2E),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A2820)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _capitalize(role),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Palette.greenColor,
                  ),
                ),
              ),
            ),
          ),
          isThreeLine: false,
          trailing: isActioning
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Palette.greenColor,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Decline
                    GestureDetector(
                      onTap: () => _declineRequest(conn.connectionId),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFEF2F2),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Accept
                    TextButton(
                      onPressed: () => _acceptRequest(conn.connectionId),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Palette.greenColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Accept'),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ── Sheet for patients: tabbed — care team + patients + requests ──────────
  Widget _buildPatientSheet(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final myRole = currentUser?.role ?? '';
    // Secretaries only connect with doctors — keep the simple single-list sheet.
    if (myRole == 'secretary') return _buildSecretarySheet(context);
    return _buildPatientTabSheet(context);
  }

  // ── Secretary: simple doctor-browse sheet ────────────────────────────────
  Widget _buildSecretarySheet(BuildContext context) {
    final usersAsync = ref.watch(browseUsersProvider);
    final connectionsState = ref.watch(acceptedConnectionsProvider);
    final pendingState = ref.watch(pendingConnectionsProvider);
    final authUser = ref.watch(authStateProvider).asData?.value;
    final currentUid = authUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final connectedUids = <String>{currentUid};
    if (connectionsState.hasValue) {
      for (final c in connectionsState.value!) {
        connectedUids.add(c.requesterUid);
        connectedUids.add(c.recipientUid);
      }
    }
    if (pendingState.hasValue) {
      for (final c in pendingState.value!) {
        connectedUids.add(c.requesterUid);
        connectedUids.add(c.recipientUid);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Palette.darkOutlineColor
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'Add to Health Circle',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? Palette.darkOnSurfaceColor
                    : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Send a connection request to a doctor.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark
                    ? Palette.darkOnSurfaceVariantColor
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: usersAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Palette.greenColor),
                ),
              ),
              error: (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Could not load users.',
                    style: GoogleFonts.inter(
                      color: isDark
                          ? Palette.darkOnSurfaceVariantColor
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
              data: (List<UserModel> users) {
                final available = users
                    .where((u) => !connectedUids.contains(u.uid))
                    .where((u) => u.role == 'doctor')
                    .toList(growable: false);
                if (available.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No available doctors to connect with.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isDark
                              ? Palette.darkOnSurfaceVariantColor
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: available.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = available[index];
                    final isSending = _sending[user.uid] ?? false;
                    return _UserListTile(
                      user: user,
                      isSending: isSending,
                      isDark: isDark,
                      onConnect: () => _sendRequest(user),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Patient: 3-tab sheet — care team + patients + requests ────────────────
  Widget _buildPatientTabSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usersAsync = ref.watch(browseUsersProvider);
    final patientPeersAsync = ref.watch(browsePatientsProvider);
    final pendingAsync = ref.watch(pendingConnectionsProvider);
    final connectionsState = ref.watch(acceptedConnectionsProvider);
    final authUser = ref.watch(authStateProvider).asData?.value;
    final currentUid = authUser?.uid ?? '';
    final secretariesAsync = ref.watch(browseSecretariesProvider);

    final connectedUids = <String>{currentUid};
    if (connectionsState.hasValue) {
      for (final c in connectionsState.value!) {
        connectedUids.add(c.requesterUid);
        connectedUids.add(c.recipientUid);
      }
    }
    if (pendingAsync.hasValue) {
      for (final c in pendingAsync.value!) {
        connectedUids.add(c.requesterUid);
        connectedUids.add(c.recipientUid);
      }
    }

    return DefaultTabController(
      length: 3,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Palette.darkOutlineColor
                      : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Add to Health Circle',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Palette.darkOnSurfaceColor
                      : const Color(0xFF1A1A2E),
                ),
              ),
            ),
            TabBar(
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              labelColor: Palette.greenColor,
              unselectedLabelColor: isDark
                  ? Palette.darkOnSurfaceVariantColor
                  : const Color(0xFF6B7280),
              indicatorColor: Palette.greenColor,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Care Team'),
                Tab(text: 'Patients'),
                Tab(text: 'Requests'),
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: TabBarView(
                children: [
                  // ── Tab 1: Browse doctors & caregivers ─────────────────────
                  usersAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          color: Palette.greenColor,
                        ),
                      ),
                    ),
                    error: (_, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Could not load users.',
                          style: GoogleFonts.inter(
                            color: isDark
                                ? Palette.darkOnSurfaceVariantColor
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    data: (List<UserModel> users) {
                      final available = users
                          .where((u) => !connectedUids.contains(u.uid))
                          .toList(growable: false);
                      if (available.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No available doctors or caregivers\nto connect with.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: isDark
                                    ? Palette.darkOnSurfaceVariantColor
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: available.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = available[index];
                          return _UserListTile(
                            user: user,
                            isSending: _sending[user.uid] ?? false,
                            isDark: isDark,
                            onConnect: () => _sendRequest(user),
                          );
                        },
                      );
                    },
                  ),

                  // ── Tab 2: Browse peer patients ────────────────────────────
                  patientPeersAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          color: Palette.greenColor,
                        ),
                      ),
                    ),
                    error: (_, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Could not load patients.',
                          style: GoogleFonts.inter(
                            color: isDark
                                ? Palette.darkOnSurfaceVariantColor
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    data: (List<UserModel> patients) {
                      final available = patients
                          .where((u) => !connectedUids.contains(u.uid))
                          .toList(growable: false);
                      if (available.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No other patients to connect with.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: isDark
                                    ? Palette.darkOnSurfaceVariantColor
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: available.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = available[index];
                          return _PatientPeerTile(
                            user: user,
                            isSending: _sending[user.uid] ?? false,
                            isDark: isDark,
                            onConnect: () => _sendRequest(user),
                          );
                        },
                      );
                    },
                  ),

                  // ── Tab 3: Incoming pending requests ──────────────────────
                  _buildPendingList(
                    context,
                    isDark: isDark,
                    pendingAsync: pendingAsync,
                    patientsAsync: patientPeersAsync,
                    usersAsync: usersAsync,
                    secretariesAsync: secretariesAsync,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable list tile for doctor/caregiver browse rows
// ─────────────────────────────────────────────────────────────────────────────

class _UserListTile extends StatelessWidget {
  const _UserListTile({
    required this.user,
    required this.isSending,
    required this.isDark,
    required this.onConnect,
  });

  final UserModel user;
  final bool isSending;
  final bool isDark;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: _RoleAvatar(user: user),
      title: Text(
        user.displayName ?? user.email ?? user.uid,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Palette.darkOnSurfaceColor : const Color(0xFF1A1A2E),
        ),
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: user.role == 'doctor'
                  ? (isDark ? const Color(0xFF1E2D45) : const Color(0xFFEFF6FF))
                  : (isDark
                        ? const Color(0xFF1A2820)
                        : const Color(0xFFF0FDF4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user.role == 'doctor' ? 'Doctor' : 'Caregiver',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: user.role == 'doctor'
                    ? const Color(0xFF3B82F6)
                    : Palette.greenColor,
              ),
            ),
          ),
        ],
      ),
      trailing: isSending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Palette.greenColor,
              ),
            )
          : TextButton(
              onPressed: onConnect,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Palette.greenColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Connect'),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable list tile for peer patient browse rows
// ─────────────────────────────────────────────────────────────────────────────

class _PatientPeerTile extends StatelessWidget {
  const _PatientPeerTile({
    required this.user,
    required this.isSending,
    required this.isDark,
    required this.onConnect,
  });

  final UserModel user;
  final bool isSending;
  final bool isDark;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName ?? user.email ?? user.uid;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: _PatientAvatar(name: name),
      title: Text(
        name,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Palette.darkOnSurfaceColor : const Color(0xFF1A1A2E),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0D2D2A)
                  : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Patient',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0D9488),
              ),
            ),
          ),
        ),
      ),
      trailing: isSending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF0D9488),
              ),
            )
          : TextButton(
              onPressed: onConnect,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Connect'),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Role-colored avatar
// ─────────────────────────────────────────────────────────────────────────────

class _RoleAvatar extends StatelessWidget {
  const _RoleAvatar({required this.user});

  final UserModel user;

  static const _doctorColors = [Color(0xFF60A5FA), Color(0xFF3B82F6)];
  static const _caregiverColors = [Color(0xFFA78BFA), Color(0xFF7C3AED)];

  @override
  Widget build(BuildContext context) {
    final isDoctor = user.role == 'doctor';
    final colors = isDoctor ? _doctorColors : _caregiverColors;
    final initial = (user.displayName ?? user.email ?? '?')
        .substring(0, 1)
        .toUpperCase();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: user.photoUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: user.photoUrl!,
                fit: BoxFit.cover,
              ),
            )
          : Center(
              child: Text(
                initial,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Green-gradient avatar for patients (used in care-provider requests list)
// ─────────────────────────────────────────────────────────────────────────────

class _PatientAvatar extends StatelessWidget {
  const _PatientAvatar({required this.name});

  final String name;

  static const _colors = [Color(0xFF4ADE80), Color(0xFF16A34A)];

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _colors,
        ),
        boxShadow: [
          BoxShadow(
            color: _colors.last.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
