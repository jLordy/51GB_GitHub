import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/features/connections/model/connection_model.dart';
import 'package:frontend/features/connections/model/user_connection_summary.dart';
import 'package:frontend/features/call/controller/call_controller.dart';
import 'package:frontend/features/call/presentation/screens/call_screen.dart';
import 'package:frontend/features/chat/data/chat_repository.dart';
import 'package:frontend/features/connections/presentation/widgets/add_connection_sheet.dart';
import 'package:frontend/features/connections/presentation/widgets/connection_details_card.dart';
import 'package:frontend/features/connections/presentation/widgets/connection_top_bar.dart';
import 'package:frontend/features/connections/presentation/widgets/health_circle_view.dart';
import 'package:frontend/features/connections/presentation/widgets/painters.dart';
import 'package:frontend/features/connections/presentation/widgets/patient_circle_view.dart';
import 'package:frontend/features/connections/presentation/widgets/patient_connection_card.dart';
import 'package:frontend/features/calendar/presentation/screens/public_doctor_calendar_screen.dart';
import 'package:frontend/features/journal/presentation/screens/patient_journal_screen.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // Patient view: selected care-team member's connection ID
  String? _selectedConnId;

  // Care-provider view: currently selected patient node
  UserModel? _selectedPatient;
  String? _selectedPatientConnId;

  // Care-provider view: currently selected caregiver node
  UserConnectionSummary? _selectedCaregiver;

  // Care-provider view: currently selected secretary node
  UserModel? _selectedSecretary;
  String? _selectedSecretaryConnId;

  // Patient view: selected secretary sub-node display name
  String? _selectedSecretaryDisplayName;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.14,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _openChatWith(String otherUid) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final conv = await repo.createOrFetchConversation(otherUid);
      if (!mounted) return;
      context.push('/chat/${conv.conversationId}', extra: conv);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open conversation')),
      );
    }
  }

  void _showAddConnectionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddConnectionSheet(),
    );
  }

  void _showSecretaryPatients(
    BuildContext context,
    String doctorUid,
    String doctorName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => _SecretaryPatientsSheet(
          doctorUid: doctorUid,
          doctorName: doctorName,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final myRole = currentUser?.role ?? '';
    if (myRole == 'doctor' || myRole == 'caregiver') {
      return _buildCareProviderScaffold(context, myRole);
    }
    return _buildPatientScaffold(context);
  }

  Widget _buildPatientScaffold(BuildContext context) {
    final authUser = ref.watch(authStateProvider).asData?.value;
    final connectionsState = ref.watch(acceptedConnectionsProvider);
    final usersAsync = ref.watch(browseUsersProvider);
    final patientPeersAsync = ref.watch(browsePatientsProvider);
    final myRole = ref.watch(currentUserProvider)?.role ?? '';

    final connections = connectionsState.asData?.value ?? <ConnectionModel>[];
    final users = usersAsync.asData?.value ?? <UserModel>[];
    final patientPeers = patientPeersAsync.asData?.value ?? <UserModel>[];
    final userMap = <String, UserModel>{
      for (final u in [...users, ...patientPeers]) u.uid: u,
    };
    final currentUid = authUser?.uid ?? '';

    // Collect ALL doctors, caregivers, and peer patients as CareTeamMember entries.
    final List<CareTeamMember> careTeam = <CareTeamMember>[];
    for (final conn in connections) {
      final otherUid = conn.otherUid(currentUid);
      final user = userMap[otherUid];
      if (user == null) continue;
      if (user.role == 'doctor') {
        careTeam.add(
          CareTeamMember(
            displayName: user.displayName ?? 'Doctor',
            connectionId: conn.connectionId,
            isDoctor: true,
          ),
        );
      } else if (user.role == 'caregiver') {
        careTeam.add(
          CareTeamMember(
            displayName: user.displayName ?? 'Caregiver',
            connectionId: conn.connectionId,
            isDoctor: false,
          ),
        );
      } else if (user.role == 'patient') {
        careTeam.add(
          CareTeamMember(
            displayName: user.displayName ?? 'Patient',
            connectionId: conn.connectionId,
            isDoctor: false,
            isPatient: true,
          ),
        );
      }
    }

    // Find the currently selected member (if any).
    CareTeamMember? selectedMember;
    if (_selectedConnId != null) {
      for (final m in careTeam) {
        if (m.connectionId == _selectedConnId) {
          selectedMember = m;
          break;
        }
      }
    }

    // Resolve the other user's UID for the selected connection (used for chat).
    String? selectedOtherUid;
    if (selectedMember != null) {
      for (final c in connections) {
        if (c.connectionId == selectedMember.connectionId) {
          selectedOtherUid = c.otherUid(currentUid);
          break;
        }
      }
    }

    // For a secretary selecting a doctor node: resolve the doctor's UID.
    String? selectedDoctorUid;
    if (myRole == 'secretary' &&
        selectedMember != null &&
        selectedMember.isDoctor) {
      for (final c in connections) {
        if (c.connectionId == selectedMember.connectionId) {
          selectedDoctorUid = c.otherUid(currentUid);
          break;
        }
      }
    }

    // For secretary: build patient sub-orbit map (index → patient names)
    // for each doctor node. ref.watch calls must be unconditional, so we
    // always resolve the doctor UIDs first, then watch the provider.
    final Map<int, List<String>> patientSubOrbit = {};
    if (myRole == 'secretary') {
      for (int i = 0; i < careTeam.length; i++) {
        if (!careTeam[i].isDoctor) continue;
        // Resolve doctor UID from connections
        String? docUid;
        for (final c in connections) {
          if (c.connectionId == careTeam[i].connectionId) {
            docUid = c.otherUid(currentUid);
            break;
          }
        }
        if (docUid == null) continue;
        final patients =
            ref.watch(secretaryDoctorPatientsProvider(docUid)).value ?? [];
        if (patients.isNotEmpty) {
          patientSubOrbit[i] = patients
              .map((p) => p.displayName ?? p.email ?? 'Patient')
              .toList();
        }
      }
    }

    // For patient: build secretary sub-orbit map (index → secretary names)
    // for each doctor node the patient is connected to.
    final Map<int, List<String>> secretarySubOrbit = {};
    if (myRole == 'patient') {
      for (int i = 0; i < careTeam.length; i++) {
        if (!careTeam[i].isDoctor) continue;
        String? docUid;
        for (final c in connections) {
          if (c.connectionId == careTeam[i].connectionId) {
            docUid = c.otherUid(currentUid);
            break;
          }
        }
        if (docUid == null) continue;
        final secs = ref.watch(doctorSecretariesProvider(docUid)).value ?? [];
        if (secs.isNotEmpty) {
          secretarySubOrbit[i] = secs.map((s) => s.displayName).toList();
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? Palette.darkSurfaceColor
          : const Color(0xFFF5F9F7),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: GridBgPainter())),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ConnectionTopBar(onAdd: () => _showAddConnectionSheet(context)),
                const SizedBox(height: 4),
                Expanded(
                  flex: 5,
                  child: HealthCircleView(
                    pulseAnimation: _pulseAnim,
                    members: careTeam,
                    onMemberTap: (member) => setState(() {
                      _selectedConnId = _selectedConnId == member.connectionId
                          ? null
                          : member.connectionId;
                      _selectedSecretaryDisplayName = null;
                    }),
                    patientSubOrbit: patientSubOrbit,
                    secretarySubOrbit: secretarySubOrbit,
                    onPatientSubTap: myRole == 'secretary'
                        ? (memberIndex, patientName) {
                            // Resolve the doctor UID for this member index
                            if (memberIndex >= careTeam.length) return;
                            String? docUid;
                            for (final c in connections) {
                              if (c.connectionId ==
                                  careTeam[memberIndex].connectionId) {
                                docUid = c.otherUid(currentUid);
                                break;
                              }
                            }
                            if (docUid == null) return;
                            _showSecretaryPatients(
                              context,
                              docUid,
                              careTeam[memberIndex].displayName,
                            );
                          }
                        : null,
                    onSecretarySubTap: myRole == 'patient'
                        ? (_, secretaryName) => setState(() {
                            _selectedSecretaryDisplayName =
                                _selectedSecretaryDisplayName == secretaryName
                                ? null
                                : secretaryName;
                            _selectedConnId = null;
                          })
                        : null,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _selectedSecretaryDisplayName != null
                      ? _SecretaryDetailsCard(
                          key: ValueKey('sec_$_selectedSecretaryDisplayName'),
                          displayName: _selectedSecretaryDisplayName!,
                          onDismiss: () => setState(
                            () => _selectedSecretaryDisplayName = null,
                          ),
                        )
                      : selectedMember != null
                      ? ConnectionDetailsCard(
                          key: ValueKey(_selectedConnId),
                          connectionType: selectedMember.isDoctor
                              ? ConnectionType.doctor
                              : selectedMember.isPatient
                              ? ConnectionType.patient
                              : ConnectionType.caregiver,
                          displayName: selectedMember.displayName,
                          roleLabel: selectedMember.isDoctor
                              ? 'Physician'
                              : selectedMember.isPatient
                              ? 'Peer Patient'
                              : 'Family Caregiver',
                          connectionId: selectedMember.connectionId,
                          onRemove: () {
                            ref
                                .read(acceptedConnectionsProvider.notifier)
                                .remove(selectedMember!.connectionId);
                            setState(() => _selectedConnId = null);
                          },
                          onMessageTap: selectedOtherUid != null
                              ? () => _openChatWith(selectedOtherUid!)
                              : () {},
                          onCallTap: () {},
                          // Secretary: override 3rd button to show doctor's patients.
                          thirdButtonIcon:
                              (myRole == 'secretary' && selectedMember.isDoctor)
                              ? Icons.people_rounded
                              : null,
                          thirdButtonLabel:
                              (myRole == 'secretary' && selectedMember.isDoctor)
                              ? 'Patients'
                              : null,
                          onThirdButtonTap:
                              (myRole == 'secretary' &&
                                  selectedDoctorUid != null)
                              ? () => _showSecretaryPatients(
                                  context,
                                  selectedDoctorUid!,
                                  selectedMember!.displayName,
                                )
                              : () {},
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
                const SizedBox(height: 12),
                BottomNavbar(
                  selectedIndex: -1,
                  onHomeTap: () => context.go('/home'),
                  onJournalTap: () => context.go('/journal'),
                  onNotificationsTap: () => context.go('/notifications'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareProviderScaffold(BuildContext context, String myRole) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authUser = ref.watch(authStateProvider).asData?.value;
    final connectionsState = ref.watch(acceptedConnectionsProvider);
    final patientsAsync = ref.watch(browsePatientsProvider);
    final secretariesAsync = ref.watch(browseSecretariesProvider);
    final currentUid = authUser?.uid ?? '';

    final connections = connectionsState.asData?.value ?? <ConnectionModel>[];
    final connectedUids = connections
        .map((c) => c.otherUid(currentUid))
        .toSet();

    // Separate patients from secretaries early so ref.watch calls are
    // always made deterministically on every build.
    final allPatients = patientsAsync.asData?.value ?? <UserModel>[];
    final allSecretaries = secretariesAsync.asData?.value ?? <UserModel>[];
    final connectedPatients = allPatients
        .where((u) => connectedUids.contains(u.uid))
        .toList(growable: false);
    final connectedSecretaries = allSecretaries
        .where((u) => connectedUids.contains(u.uid))
        .toList(growable: false);

    // Build sub-orbit map:
    //   doctors    → see their patients' caregivers in the sub-orbit
    //   caregivers → see their patients' doctors in the sub-orbit;
    //                secretaries go one level deeper (under the doctor node)
    final subOrbitMap = <String, List<UserConnectionSummary>>{};
    final patientDoctorSecretsMap = <String, List<UserConnectionSummary>>{};
    for (final u in connectedPatients) {
      if (myRole == 'doctor') {
        subOrbitMap[u.uid] =
            ref.watch(patientCaregiversProvider(u.uid)).value ?? const [];
      } else {
        subOrbitMap[u.uid] =
            ref.watch(patientDoctorsProvider(u.uid)).value ?? const [];
        patientDoctorSecretsMap[u.uid] =
            ref.watch(patientDoctorSecretariesProvider(u.uid)).value ??
            const [];
      }
    }

    return Scaffold(
      backgroundColor: isDark
          ? Palette.darkSurfaceColor
          : const Color(0xFFF5F9F7),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: GridBgPainter())),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ConnectionTopBar(
                  title: 'My Connections',
                  onAdd: () => _showAddConnectionSheet(context),
                ),
                const SizedBox(height: 4),
                Expanded(
                  flex: 5,
                  child: patientsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: Palette.greenColor,
                      ),
                    ),
                    error: (_, _) => Center(
                      child: Text(
                        'Could not load connections.',
                        style: GoogleFonts.inter(
                          color: isDark
                              ? Palette.darkOnSurfaceVariantColor
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    data: (_) => PatientCircleView(
                      pulseAnimation: _pulseAnim,
                      patients: connectedPatients,
                      secretaries: connectedSecretaries,
                      connections: connections,
                      currentUid: currentUid,
                      patientCaregivers: subOrbitMap,
                      patientDoctorSecretaries: patientDoctorSecretsMap,
                      onPatientTap: (patient, connId) {
                        setState(() {
                          _selectedCaregiver = null;
                          _selectedSecretary = null;
                          _selectedSecretaryConnId = null;
                          if (_selectedPatient?.uid == patient.uid) {
                            _selectedPatient = null;
                            _selectedPatientConnId = null;
                          } else {
                            _selectedPatient = patient;
                            _selectedPatientConnId = connId;
                          }
                        });
                      },
                      onCaregiverTap: (cg) {
                        setState(() {
                          _selectedPatient = null;
                          _selectedPatientConnId = null;
                          _selectedSecretary = null;
                          _selectedSecretaryConnId = null;
                          _selectedCaregiver =
                              _selectedCaregiver?.userUid == cg.userUid
                              ? null
                              : cg;
                        });
                      },
                      onSecretaryTap: (secretary, connId) {
                        setState(() {
                          _selectedPatient = null;
                          _selectedPatientConnId = null;
                          _selectedCaregiver = null;
                          if (_selectedSecretary?.uid == secretary.uid) {
                            _selectedSecretary = null;
                            _selectedSecretaryConnId = null;
                          } else {
                            _selectedSecretary = secretary;
                            _selectedSecretaryConnId = connId;
                          }
                        });
                      },
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _selectedPatient != null
                      ? PatientConnectionCard(
                          key: ValueKey(_selectedPatient!.uid),
                          patient: _selectedPatient!,
                          profile: ref
                              .watch(patientProfilesProvider)
                              .value?[_selectedPatient!.uid],
                          connectionId: _selectedPatientConnId,
                          onRemove: () {
                            if (_selectedPatientConnId != null) {
                              ref
                                  .read(acceptedConnectionsProvider.notifier)
                                  .remove(_selectedPatientConnId!);
                            }
                            setState(() {
                              _selectedPatient = null;
                              _selectedPatientConnId = null;
                            });
                          },
                        )
                      : _selectedCaregiver != null
                      ? _CaregiverInfoCard(
                          key: ValueKey('cg_${_selectedCaregiver!.userUid}'),
                          caregiver: _selectedCaregiver!,
                          onDismiss: () =>
                              setState(() => _selectedCaregiver = null),
                        )
                      : _selectedSecretary != null
                      ? _SecretaryInfoCard(
                          key: ValueKey('sec_${_selectedSecretary!.uid}'),
                          secretary: _selectedSecretary!,
                          connectionId: _selectedSecretaryConnId,
                          onDismiss: () => setState(() {
                            _selectedSecretary = null;
                            _selectedSecretaryConnId = null;
                          }),
                          onRemove: () {
                            if (_selectedSecretaryConnId != null) {
                              ref
                                  .read(acceptedConnectionsProvider.notifier)
                                  .remove(_selectedSecretaryConnId!);
                            }
                            setState(() {
                              _selectedSecretary = null;
                              _selectedSecretaryConnId = null;
                            });
                          },
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
                const SizedBox(height: 12),
                BottomNavbar(
                  selectedIndex: -1,
                  onHomeTap: () => context.go('/home'),
                  onJournalTap: () => context.go('/journal'),
                  onNotificationsTap: () => context.go('/notifications'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Secretary Info Card
//  Shown at the bottom when a secretary node is tapped in the circle view.
// ─────────────────────────────────────────────────────────────────────────────

class _SecretaryInfoCard extends ConsumerWidget {
  final UserModel secretary;
  final String? connectionId;
  final VoidCallback onDismiss;
  final VoidCallback onRemove;

  const _SecretaryInfoCard({
    super.key,
    required this.secretary,
    required this.connectionId,
    required this.onDismiss,
    required this.onRemove,
  });

  static const _violet1 = Color(0xFF7C3AED);
  static const _violet2 = Color(0xFF6D28D9);

  String get _displayName =>
      secretary.displayName ?? secretary.email ?? 'Secretary';

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final conv = await repo.createOrFetchConversation(secretary.uid);
      if (!context.mounted) return;
      context.push('/chat/${conv.conversationId}', extra: conv);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open conversation')),
      );
    }
  }

  Future<void> _startCall(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;
    final callState = ref.read(callControllerProvider);
    if (callState.hasActiveCall) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Already in a call')));
      return;
    }
    await ref
        .read(callControllerProvider.notifier)
        .startCall(
          calleeUid: secretary.uid,
          callerUid: currentUser.uid,
          callerName: currentUser.displayName ?? currentUser.email ?? 'Me',
          calleeName: _displayName,
          callerPhotoUrl: currentUser.photoUrl,
          calleePhotoUrl: secretary.photoUrl,
        );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(
          otherName: _displayName,
          otherPhotoUrl: secretary.photoUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textDark = isDark
        ? Palette.darkOnSurfaceColor
        : const Color(0xFF1A1A2E);
    final textMid = isDark
        ? Palette.darkOnSurfaceVariantColor
        : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _violet1.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gradient header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _violet1.withValues(alpha: 0.10),
                  _violet1.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_violet1, _violet2],
                    ),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: _violet1.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.manage_accounts_rounded,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                // Name + role badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        secretary.displayName ?? secretary.email ?? 'Secretary',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, size: 13, color: _violet1),
                          const SizedBox(width: 4),
                          Text(
                            'Secretary',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _violet1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Dismiss button
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Palette.darkSurfaceContainerColor.withValues(
                              alpha: 0.6,
                            )
                          : Colors.white.withValues(alpha: 0.70),
                      border: Border.all(
                        color: isDark
                            ? Palette.darkOutlineColor
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Icon(Icons.close_rounded, size: 18, color: textMid),
                  ),
                ),
              ],
            ),
          ),
          // ── Action buttons ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                _CaregiverActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Message',
                  color: _violet1,
                  isDark: isDark,
                  onTap: () => _openChat(context, ref),
                ),
                const SizedBox(width: 10),
                _CaregiverActionButton(
                  icon: Icons.call_outlined,
                  label: 'Call',
                  color: _violet1,
                  isDark: isDark,
                  onTap: () => _startCall(context, ref),
                ),
                const SizedBox(width: 10),
                _CaregiverActionButton(
                  icon: Icons.link_off_rounded,
                  label: 'Remove',
                  color: Colors.redAccent,
                  isDark: isDark,
                  onTap: onRemove,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Caregiver Info Card
//  Shown at the bottom when a caregiver node is tapped in the circle view.
// ─────────────────────────────────────────────────────────────────────────────

class _CaregiverInfoCard extends ConsumerWidget {
  final UserConnectionSummary caregiver;
  final VoidCallback onDismiss;

  const _CaregiverInfoCard({
    super.key,
    required this.caregiver,
    required this.onDismiss,
  });

  static const _care1 = Color(0xFF0EA5E9);
  static const _care2 = Color(0xFF0284C7);
  static const _doc1 = Color(0xFFD97706);
  static const _doc2 = Color(0xFFB45309);
  static const _sec1 = Color(0xFF7C3AED);
  static const _sec2 = Color(0xFF6D28D9);

  bool get _isDoctor => caregiver.role == 'doctor';
  bool get _isSecretary => caregiver.role == 'secretary';
  Color get _accent1 => _isDoctor
      ? _doc1
      : _isSecretary
      ? _sec1
      : _care1;
  Color get _accent2 => _isDoctor
      ? _doc2
      : _isSecretary
      ? _sec2
      : _care2;
  IconData get _icon => _isDoctor
      ? Icons.medical_services_rounded
      : _isSecretary
      ? Icons.manage_accounts_rounded
      : Icons.favorite_rounded;
  String get _roleLabel => _isDoctor
      ? 'Physician'
      : _isSecretary
      ? 'Secretary'
      : 'Family Caregiver';
  IconData get _roleBadgeIcon => _isDoctor
      ? Icons.local_hospital_rounded
      : _isSecretary
      ? Icons.badge_rounded
      : Icons.favorite_border_rounded;

  String get _displayName => caregiver.displayName;

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final conv = await repo.createOrFetchConversation(caregiver.userUid);
      if (!context.mounted) return;
      context.push('/chat/${conv.conversationId}', extra: conv);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open conversation')),
      );
    }
  }

  Future<void> _startCall(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;
    final callState = ref.read(callControllerProvider);
    if (callState.hasActiveCall) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Already in a call')));
      return;
    }
    await ref
        .read(callControllerProvider.notifier)
        .startCall(
          calleeUid: caregiver.userUid,
          callerUid: currentUser.uid,
          callerName: currentUser.displayName ?? currentUser.email ?? 'Me',
          calleeName: _displayName,
          callerPhotoUrl: currentUser.photoUrl,
          calleePhotoUrl: null,
        );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            CallScreen(otherName: _displayName, otherPhotoUrl: null),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textDark = isDark
        ? Palette.darkOnSurfaceColor
        : const Color(0xFF1A1A2E);
    final textMid = isDark
        ? Palette.darkOnSurfaceVariantColor
        : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _accent1.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gradient header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _accent1.withValues(alpha: 0.10),
                  _accent1.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_accent1, _accent2],
                    ),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: _accent1.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(_icon, size: 26, color: Colors.white),
                ),
                const SizedBox(width: 14),
                // Name + role badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caregiver.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(_roleBadgeIcon, size: 13, color: _accent1),
                          const SizedBox(width: 4),
                          Text(
                            _roleLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _accent1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Dismiss button
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Palette.darkSurfaceContainerColor.withValues(
                              alpha: 0.6,
                            )
                          : Colors.white.withValues(alpha: 0.70),
                      border: Border.all(
                        color: isDark
                            ? Palette.darkOutlineColor
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Icon(Icons.close_rounded, size: 18, color: textMid),
                  ),
                ),
              ],
            ),
          ),

          // ── Action buttons ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                _CaregiverActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Message',
                  color: _accent1,
                  isDark: isDark,
                  onTap: () => _openChat(context, ref),
                ),
                const SizedBox(width: 10),
                _CaregiverActionButton(
                  icon: Icons.call_outlined,
                  label: 'Call',
                  color: _accent1,
                  isDark: isDark,
                  onTap: () => _startCall(context, ref),
                ),
                if (_isDoctor) ...[
                  const SizedBox(width: 10),
                  _CaregiverActionButton(
                    icon: Icons.calendar_month_outlined,
                    label: 'Calendar',
                    color: _accent1,
                    isDark: isDark,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PublicDoctorCalendarScreen(
                          doctorUid: caregiver.userUid,
                          doctorName: caregiver.displayName,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable action button for caregiver card
// ─────────────────────────────────────────────────────────────────────────────

class _CaregiverActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _CaregiverActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Secretary Patients Sheet
//  Shown when a secretary taps "Patients" on their connected doctor's card.
// ─────────────────────────────────────────────────────────────────────────────

class _SecretaryPatientsSheet extends ConsumerWidget {
  final String doctorUid;
  final String doctorName;
  final ScrollController scrollController;

  const _SecretaryPatientsSheet({
    required this.doctorUid,
    required this.doctorName,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(secretaryDoctorPatientsProvider(doctorUid));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textDark = isDark
        ? Palette.darkOnSurfaceColor
        : const Color(0xFF1A1A2E);
    final textMid = isDark
        ? Palette.darkOnSurfaceVariantColor
        : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 14, bottom: 20),
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
          // Title
          Text(
            "$doctorName's Patients",
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a patient to view their journal or records.',
            style: GoogleFonts.inter(fontSize: 13, color: textMid),
          ),
          const SizedBox(height: 16),
          // Patient list
          patientsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(color: Palette.greenColor),
              ),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Could not load patients.',
                  style: GoogleFonts.inter(color: textMid),
                ),
              ),
            ),
            data: (patients) {
              if (patients.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No patients connected to this doctor.',
                      style: GoogleFonts.inter(color: textMid),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < patients.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _SecretaryPatientTile(patient: patients[i], isDark: isDark),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Individual patient row inside the secretary patients sheet ───────────────

class _SecretaryPatientTile extends StatelessWidget {
  final UserModel patient;
  final bool isDark;

  const _SecretaryPatientTile({required this.patient, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final name = patient.displayName ?? 'Patient';
    final textDark = isDark
        ? Palette.darkOnSurfaceColor
        : const Color(0xFF1A1A2E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Palette.darkInputSurfaceColor : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Palette.darkOutlineColor : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: Palette.greenColor.withValues(alpha: 0.15),
            child: const Icon(
              Icons.person_rounded,
              color: Palette.greenColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Journal button
          _SheetActionButton(
            icon: Icons.book_rounded,
            label: 'Journal',
            color: Palette.greenColor,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PatientJournalScreen(
                    patientUid: patient.uid,
                    patientName: name,
                    viewerRole: PatientJournalViewerRole.secretary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Records button
          _SheetActionButton(
            icon: Icons.folder_rounded,
            label: 'Records',
            color: const Color(0xFF7C3AED),
            onTap: () {
              Navigator.of(context).pop();
              final encodedName = Uri.encodeComponent(name);
              context.push(
                '/documents?patientUid=${patient.uid}&patientName=$encodedName',
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Small icon+label button used in the secretary patients sheet ─────────────

class _SheetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Secretary Details Card
//  Inline card shown when a patient taps a secretary sub-orbit node.
//  Styled identically to ConnectionDetailsCard (doctor/caregiver card).
// ─────────────────────────────────────────────────────────────────────────────

class _SecretaryDetailsCard extends StatelessWidget {
  final String displayName;
  final VoidCallback onDismiss;

  const _SecretaryDetailsCard({
    super.key,
    required this.displayName,
    required this.onDismiss,
  });

  static const _violet1 = Color(0xFF7C3AED);
  static const _violet2 = Color(0xFF6D28D9);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textDark = isDark
        ? Palette.darkOnSurfaceColor
        : const Color(0xFF1A1A2E);
    final textMid = isDark
        ? Palette.darkOnSurfaceVariantColor
        : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _violet1.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gradient header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _violet1.withValues(alpha: 0.10),
                  _violet1.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_violet1, _violet2],
                    ),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: _violet1.withValues(alpha: 0.32),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.manage_accounts_rounded,
                    size: 27,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                // Name + role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.badge_rounded, size: 13, color: _violet1),
                          const SizedBox(width: 4),
                          Text(
                            'Secretary',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _violet1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Dismiss ✕
                GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Palette.darkOnSurfaceVariantColor
                          : const Color(0xFFF3F4F6),
                    ),
                    child: Icon(Icons.close_rounded, size: 18, color: textMid),
                  ),
                ),
              ],
            ),
          ),
          // ── Body ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Works on behalf of your doctor to help manage your appointments and medical records.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: textMid,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                // ── Action buttons ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _CaregiverActionButton(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Message',
                        color: _violet1,
                        isDark: isDark,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CaregiverActionButton(
                        icon: Icons.call_rounded,
                        label: 'Call',
                        color: _violet1,
                        isDark: isDark,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CaregiverActionButton(
                        icon: Icons.calendar_month_outlined,
                        label: 'Schedule',
                        color: _violet1,
                        isDark: isDark,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
