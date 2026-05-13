import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/connections/data/connection_repository.dart';
import 'package:frontend/features/connections/model/connection_model.dart';
import 'package:frontend/features/connections/model/patient_profile_model.dart';
import 'package:frontend/features/connections/model/user_connection_summary.dart';
import 'package:frontend/features/notifications/controller/notification_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// ─── Accepted connections ─────────────────────────────────────────────────────

final acceptedConnectionsProvider =
    StateNotifierProvider<
      AcceptedConnectionsController,
      AsyncValue<List<ConnectionModel>>
    >(
      (ref) =>
          AcceptedConnectionsController(ref.read(connectionRepositoryProvider)),
    );

class AcceptedConnectionsController
    extends StateNotifier<AsyncValue<List<ConnectionModel>>> {
  AcceptedConnectionsController(this._repo)
    : super(const AsyncValue.loading()) {
    load();
  }

  final ConnectionRepository _repo;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.fetchAccepted);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.fetchAccepted);
  }

  Future<void> remove(String connectionId) async {
    await _repo.removeConnection(connectionId);
    // Reload the list after removal.
    await refresh();
  }
}

// ─── Pending incoming connections ────────────────────────────────────────────

final pendingConnectionsProvider =
    StateNotifierProvider<
      PendingConnectionsController,
      AsyncValue<List<ConnectionModel>>
    >(
      (ref) => PendingConnectionsController(
        ref.read(connectionRepositoryProvider),
        ref,
      ),
    );

class PendingConnectionsController
    extends StateNotifier<AsyncValue<List<ConnectionModel>>> {
  PendingConnectionsController(this._repo, this._ref)
    : super(const AsyncValue.loading()) {
    load();
  }

  final ConnectionRepository _repo;
  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.fetchPendingIncoming);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.fetchPendingIncoming);
  }

  /// Accept a connection and refresh both accepted + pending lists.
  Future<void> accept(String connectionId) async {
    await _repo.acceptConnection(connectionId);
    _ref
        .read(notificationControllerProvider.notifier)
        .resolveByConnectionId(connectionId, 'accepted');
    await Future.wait([
      refresh(),
      _ref.read(acceptedConnectionsProvider.notifier).refresh(),
    ]);
  }

  /// Decline a connection and refresh the pending list.
  Future<void> decline(String connectionId) async {
    await _repo.declineConnection(connectionId);
    _ref
        .read(notificationControllerProvider.notifier)
        .resolveByConnectionId(connectionId, 'declined');
    await refresh();
  }
}

// ─── Browsable users (doctors + caregivers) for the connection picker ────────

final browseUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  return ref.read(connectionRepositoryProvider).browseDoctorsAndCaregivers();
});

// ─── All users for the new-message picker ────────────────────────────────────

/// Returns every active user (all roles), excluding the current user.
/// The list is deduplicated by UID and sorted alphabetically by display name.
final acceptedConnectionUsersProvider = FutureProvider<List<UserModel>>((
  ref,
) async {
  final currentUser = ref.read(currentUserProvider);
  final repo = ref.read(connectionRepositoryProvider);

  final results = await Future.wait([
    repo.browseDoctorsAndCaregivers(),
    repo.browsePatients(),
    repo.browseSecretaries(),
  ]);

  final myUid = currentUser?.uid;
  final seen = <String>{};
  final users = <UserModel>[];
  for (final list in results) {
    for (final u in list) {
      if (u.uid != myUid && seen.add(u.uid)) {
        users.add(u);
      }
    }
  }

  users.sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));
  return users;
});

// ─── Browsable patients for the doctor/caregiver connection screen ────────────

final browsePatientsProvider = FutureProvider<List<UserModel>>((ref) async {
  return ref.read(connectionRepositoryProvider).browsePatients();
});

// ─── Browsable secretaries for the connection request resolver ────────────────

final browseSecretariesProvider = FutureProvider<List<UserModel>>((ref) async {
  return ref.read(connectionRepositoryProvider).browseSecretaries();
});

// ─── Patient clinical profiles (age + diagnosis) for care-provider view ──────

/// Fetches health profiles for all accepted-connection patients.
///
/// Uses GET /api/patients/by-uid/{uid} per connected patient so that
/// self-registered patients (whose assigned_doctor_uid is null) are
/// still resolved correctly.
final patientProfilesProvider =
    FutureProvider<Map<String, PatientProfileModel>>((ref) async {
      final connections =
          ref.watch(acceptedConnectionsProvider).value ?? const [];
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null || connections.isEmpty) return {};

      final myUid = currentUser.uid;
      final repo = ref.read(connectionRepositoryProvider);

      final patientUids = connections
          .map((c) => c.otherUid(myUid))
          .toSet()
          .toList();

      final results = await Future.wait(
        patientUids.map(repo.fetchPatientProfileByUid),
      );

      return {
        for (var i = 0; i < patientUids.length; i++)
          if (results[i] != null) patientUids[i]: results[i]!,
      };
    });

// ─── Send request action ─────────────────────────────────────────────────────

/// Convenience function — sends a connection request and refreshes accepted list.
Future<void> sendConnectionRequest(WidgetRef ref, String recipientUid) async {
  await ref.read(connectionRepositoryProvider).sendRequest(recipientUid);
  await ref.read(acceptedConnectionsProvider.notifier).refresh();
}

/// Returns the patients connected to [doctorUid], accessible by the current
/// secretary. The backend enforces the secretary ↔ doctor connection.
final secretaryDoctorPatientsProvider =
    FutureProvider.family<List<UserModel>, String>((ref, doctorUid) async {
      return ref
          .read(connectionRepositoryProvider)
          .fetchPatientsForDoctorAsSecretary(doctorUid);
    });

/// Returns the UID of the doctor that the current secretary is connected to.
/// Cross-references accepted connections with [browseUsersProvider] to find
/// the one accepted peer with role == 'doctor'.
/// Returns null if the user is not a secretary or has no connected doctor.
final secretaryConnectedDoctorProvider = FutureProvider<String?>((ref) async {
  final currentUser = ref.read(currentUserProvider);
  if (currentUser == null || currentUser.role != 'secretary') return null;

  final connections = ref.watch(acceptedConnectionsProvider).value ?? const [];
  if (connections.isEmpty) return null;

  final myUid = currentUser.uid;

  // browseUsersProvider returns all doctors + caregivers with role info.
  final users = await ref.watch(browseUsersProvider.future);
  final doctorUids = {
    for (final u in users)
      if (u.role == 'doctor') u.uid,
  };

  for (final c in connections) {
    final otherUid = c.otherUid(myUid);
    if (doctorUids.contains(otherUid)) return otherUid;
  }
  return null;
});

// ─── Caregivers for a specific patient (doctor cross-role visibility) ─────────

/// Fetches the caregivers who share an accepted connection with [patientUid].
/// The calling doctor must also be connected to that patient (enforced backend).
/// Returns an empty list when there are no caregivers or the call fails.
final patientCaregiversProvider =
    FutureProvider.family<List<UserConnectionSummary>, String>((
      ref,
      patientUid,
    ) async {
      return ref
          .read(connectionRepositoryProvider)
          .fetchCaregiversForUser(patientUid);
    });

// ─── Doctors for a specific patient (caregiver cross-role visibility) ──────────────────

/// Fetches the doctors who share an accepted connection with [patientUid].
/// The calling caregiver must also be connected to that patient (enforced backend).
/// Returns an empty list when there are no doctors or the call fails.
final patientDoctorsProvider =
    FutureProvider.family<List<UserConnectionSummary>, String>((
      ref,
      patientUid,
    ) async {
      return ref
          .read(connectionRepositoryProvider)
          .fetchDoctorsForUser(patientUid);
    });

// ─── Doctors for a given secretary (public calendar navigation) ───────────────

/// Fetches the doctors connected to [secretaryUid].
/// No connection check — any authenticated user can call this to navigate to
/// a secretary's doctor calendar (e.g. tapping the calendar icon on a post).
final secretaryDoctorsProvider = FutureProvider.family<List<UserModel>, String>(
  (ref, secretaryUid) async {
    return ref
        .read(connectionRepositoryProvider)
        .fetchDoctorsForSecretary(secretaryUid);
  },
);

// ─── Secretaries for a specific doctor (patient cross-role visibility) ────────

/// Fetches the secretaries connected to [doctorUid].
/// The calling patient must be connected to that doctor (enforced backend).
/// Returns an empty list when there are no secretaries or the call fails.
final doctorSecretariesProvider =
    FutureProvider.family<List<UserConnectionSummary>, String>((
      ref,
      doctorUid,
    ) async {
      return ref
          .read(connectionRepositoryProvider)
          .fetchSecretariesForUser(doctorUid);
    });

// ─── Doctor-secretaries for a specific patient (caregiver cross-role visibility) ─

/// Fetches the secretaries connected to the doctors of [patientUid].
/// The calling caregiver must be connected to that patient (enforced backend).
/// Returns an empty list when there are no secretaries or the call fails.
final patientDoctorSecretariesProvider =
    FutureProvider.family<List<UserConnectionSummary>, String>((
      ref,
      patientUid,
    ) async {
      return ref
          .read(connectionRepositoryProvider)
          .fetchDoctorSecretariesForPatient(patientUid);
    });
