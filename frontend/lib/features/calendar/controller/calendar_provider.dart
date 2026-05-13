import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/calendar/data/calendar_repository.dart';
import 'package:frontend/features/calendar/model/appointment_model.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final selectedCalendarDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final focusedCalendarDateProvider = StateProvider<DateTime>((ref) {
  return ref.watch(selectedCalendarDateProvider);
});

/// Public doctor schedule provider — shows only clinic/special (no patient data).
/// Arg: a record ({String uid, DateTime date}).
final publicDoctorScheduleProvider = FutureProvider.autoDispose
    .family<List<AppointmentModel>, ({String uid, DateTime date})>((
      ref,
      arg,
    ) async {
      return ref
          .read(calendarRepositoryProvider)
          .fetchPublicDoctorSchedule(doctorUid: arg.uid, date: arg.date);
    });

// ─── Month-range providers (for calendar day markers) ────────────────────────

/// Arg: a record ({DateTime start, DateTime end}) — typically first..last day of visible month.
final doctorMonthAppointmentsProvider = FutureProvider.autoDispose
    .family<List<AppointmentModel>, ({DateTime start, DateTime end})>((
      ref,
      arg,
    ) async {
      return ref
          .read(calendarRepositoryProvider)
          .fetchDoctorAppointmentsByRange(start: arg.start, end: arg.end);
    });

final patientMonthAppointmentsProvider = FutureProvider.autoDispose
    .family<List<AppointmentModel>, ({DateTime start, DateTime end})>((
      ref,
      arg,
    ) async {
      return ref
          .read(calendarRepositoryProvider)
          .fetchPatientAppointmentsByRange(start: arg.start, end: arg.end);
    });

final caregiverMonthAppointmentsProvider = FutureProvider.autoDispose
    .family<List<AppointmentModel>, ({DateTime start, DateTime end})>((
      ref,
      arg,
    ) async {
      return ref
          .read(calendarRepositoryProvider)
          .fetchCaregiverAppointmentsByRange(start: arg.start, end: arg.end);
    });

final secretaryMonthAppointmentsProvider = FutureProvider.autoDispose
    .family<List<AppointmentModel>, ({DateTime start, DateTime end})>((
      ref,
      arg,
    ) async {
      return ref
          .read(calendarRepositoryProvider)
          .fetchSecretaryAppointmentsByRange(start: arg.start, end: arg.end);
    });

/// Arg: a record ({String uid, DateTime start, DateTime end}).
final publicDoctorMonthScheduleProvider = FutureProvider.autoDispose
    .family<
      List<AppointmentModel>,
      ({String uid, DateTime start, DateTime end})
    >((ref, arg) async {
      return ref
          .read(calendarRepositoryProvider)
          .fetchPublicDoctorScheduleByRange(
            doctorUid: arg.uid,
            start: arg.start,
            end: arg.end,
          );
    });

final appointmentsBySelectedDateProvider =
    FutureProvider.autoDispose<List<AppointmentModel>>((ref) async {
      final selected = ref.watch(selectedCalendarDateProvider);
      return ref
          .read(calendarRepositoryProvider)
          .fetchDoctorAppointmentsByDate(date: selected);
    });

final caregiverAppointmentsBySelectedDateProvider =
    FutureProvider.autoDispose<List<AppointmentModel>>((ref) async {
      final selected = ref.watch(selectedCalendarDateProvider);
      return ref
          .read(calendarRepositoryProvider)
          .fetchCaregiverAppointmentsByDate(date: selected);
    });

final secretaryAppointmentsBySelectedDateProvider =
    FutureProvider.autoDispose<List<AppointmentModel>>((ref) async {
      final selected = ref.watch(selectedCalendarDateProvider);
      return ref
          .read(calendarRepositoryProvider)
          .fetchSecretaryAppointmentsByDate(date: selected);
    });

final connectedCalendarDoctorsProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) async {
      return ref
          .read(calendarRepositoryProvider)
          .fetchConnectedDoctorsForSecretary();
    });

final patientsForDoctorProvider = FutureProvider.autoDispose
    .family<List<UserModel>, String>((ref, doctorUid) async {
      if (doctorUid.isEmpty) return const <UserModel>[];
      return ref
          .read(calendarRepositoryProvider)
          .fetchPatientsForDoctorAsSecretary(doctorUid);
    });

/// Aggregates patients from all doctors connected to the current secretary.
final secretaryPatientsProvider = FutureProvider.autoDispose<List<UserModel>>((
  ref,
) async {
  final doctors = await ref.watch(connectedCalendarDoctorsProvider.future);
  if (doctors.isEmpty) return const <UserModel>[];
  final patientLists = await Future.wait(
    doctors.map((d) => ref.watch(patientsForDoctorProvider(d.uid).future)),
  );
  final seen = <String>{};
  final allPatients = patientLists
      .expand((list) => list)
      .where((p) => seen.add(p.uid))
      .toList();
  allPatients.sort(
    (a, b) => (a.displayName ?? a.email ?? '').compareTo(
      b.displayName ?? b.email ?? '',
    ),
  );
  return allPatients;
});

final patientAppointmentsBySelectedDateProvider =
    FutureProvider.autoDispose<List<AppointmentModel>>((ref) async {
      final selected = ref.watch(selectedCalendarDateProvider);
      return ref
          .read(calendarRepositoryProvider)
          .fetchPatientAppointmentsByDate(date: selected);
    });

final connectedCalendarPatientsProvider = FutureProvider<List<UserModel>>((
  ref,
) async {
  final currentUser = ref.watch(currentUserProvider);
  final connections = ref.watch(acceptedConnectionsProvider).value ?? const [];
  final patients = await ref.watch(browsePatientsProvider.future);

  final myUid = currentUser?.uid;
  if (myUid == null) return const <UserModel>[];

  final patientMap = {for (final patient in patients) patient.uid: patient};
  final connectedPatients = connections
      .map((connection) => connection.otherUid(myUid))
      .where((uid) => patientMap.containsKey(uid))
      .map((uid) => patientMap[uid]!)
      .toSet()
      .toList();

  connectedPatients.sort(
    (a, b) => (a.displayName ?? a.email ?? '').compareTo(
      b.displayName ?? b.email ?? '',
    ),
  );

  return connectedPatients;
});

class CalendarMutationController extends StateNotifier<AsyncValue<void>> {
  CalendarMutationController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> createAppointment({
    String? patientUid,
    required DateTime appointmentDate,
    required String startTime,
    String? endTime,
    AppointmentType type = AppointmentType.patient,
    String? clinicName,
    String? clinicPlace,
    String? reason,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(calendarRepositoryProvider)
          .createAppointment(
            patientUid: patientUid,
            appointmentDate: appointmentDate,
            startTime: startTime,
            endTime: endTime,
            type: type,
            clinicName: clinicName,
            clinicPlace: clinicPlace,
            reason: reason,
            notes: notes,
          );
      _ref.invalidate(appointmentsBySelectedDateProvider);
    });
  }

  Future<void> createAppointmentAsSecretary({
    required String doctorUid,
    String? patientUid,
    required DateTime appointmentDate,
    required String startTime,
    String? endTime,
    AppointmentType type = AppointmentType.patient,
    String? clinicName,
    String? clinicPlace,
    String? reason,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(calendarRepositoryProvider)
          .createAppointmentAsSecretary(
            doctorUid: doctorUid,
            patientUid: patientUid,
            appointmentDate: appointmentDate,
            startTime: startTime,
            endTime: endTime,
            type: type,
            clinicName: clinicName,
            clinicPlace: clinicPlace,
            reason: reason,
            notes: notes,
          );
      _ref.invalidate(secretaryAppointmentsBySelectedDateProvider);
    });
  }

  Future<void> updateStatus({
    required String appointmentId,
    required AppointmentStatus status,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(calendarRepositoryProvider)
          .updateAppointmentStatus(
            appointmentId: appointmentId,
            status: status,
          );
      _ref.invalidate(appointmentsBySelectedDateProvider);
    });
  }

  Future<void> updateStatusAsSecretary({
    required String appointmentId,
    required AppointmentStatus status,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(calendarRepositoryProvider)
          .updateAppointmentStatusAsSecretary(
            appointmentId: appointmentId,
            status: status,
          );
      _ref.invalidate(secretaryAppointmentsBySelectedDateProvider);
    });
  }

  Future<void> deleteAppointment(String appointmentId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(calendarRepositoryProvider)
          .deleteAppointment(appointmentId);
      _ref.invalidate(appointmentsBySelectedDateProvider);
      _ref.invalidate(doctorMonthAppointmentsProvider);
    });
  }

  Future<void> deleteAppointmentAsSecretary(String appointmentId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(calendarRepositoryProvider)
          .deleteAppointmentAsSecretary(appointmentId);
      _ref.invalidate(secretaryAppointmentsBySelectedDateProvider);
      _ref.invalidate(secretaryMonthAppointmentsProvider);
    });
  }

  Future<void> updateAppointment({
    required String appointmentId,
    String? patientUid,
    required DateTime appointmentDate,
    required String startTime,
    String? endTime,
    AppointmentType type = AppointmentType.patient,
    String? clinicName,
    String? clinicPlace,
    String? reason,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(calendarRepositoryProvider)
          .updateAppointment(
            appointmentId: appointmentId,
            patientUid: patientUid,
            appointmentDate: appointmentDate,
            startTime: startTime,
            endTime: endTime,
            type: type,
            clinicName: clinicName,
            clinicPlace: clinicPlace,
            reason: reason,
            notes: notes,
          );
      _ref.invalidate(appointmentsBySelectedDateProvider);
      _ref.invalidate(doctorMonthAppointmentsProvider);
    });
  }

  Future<void> updateAppointmentAsSecretary({
    required String appointmentId,
    String? patientUid,
    required DateTime appointmentDate,
    required String startTime,
    String? endTime,
    AppointmentType type = AppointmentType.patient,
    String? clinicName,
    String? clinicPlace,
    String? reason,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(calendarRepositoryProvider)
          .updateAppointmentAsSecretary(
            appointmentId: appointmentId,
            patientUid: patientUid,
            appointmentDate: appointmentDate,
            startTime: startTime,
            endTime: endTime,
            type: type,
            clinicName: clinicName,
            clinicPlace: clinicPlace,
            reason: reason,
            notes: notes,
          );
      _ref.invalidate(secretaryAppointmentsBySelectedDateProvider);
      _ref.invalidate(secretaryMonthAppointmentsProvider);
    });
  }

  void clearState() {
    state = const AsyncValue.data(null);
  }
}

final calendarMutationControllerProvider =
    StateNotifierProvider<CalendarMutationController, AsyncValue<void>>((ref) {
      return CalendarMutationController(ref);
    });
