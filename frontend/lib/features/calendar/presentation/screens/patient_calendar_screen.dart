import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/core/widgets/left_sidebar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/calendar/controller/calendar_provider.dart';
import 'package:frontend/features/calendar/model/appointment_model.dart';
import 'package:frontend/features/calendar/presentation/widgets/appointment_list.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

class PatientCalendarScreen extends ConsumerWidget {
  const PatientCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
    final scheme = theme.colorScheme;
    final authUser = ref.watch(authStateProvider).asData?.value;
    final selectedDay = ref.watch(selectedCalendarDateProvider);
    final focusedDay = ref.watch(focusedCalendarDateProvider);
    final appointmentsAsync = ref.watch(
      patientAppointmentsBySelectedDateProvider,
    );

    final bool isWide = MediaQuery.of(context).size.width >= 900;

    if (authUser == null || authUser.isAnonymous) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      drawer: isWide ? null : const LeftSidebar(),
      appBar: AppBar(
        title: Text(
          'Calendar',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: isWide
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(Icons.menu_rounded, color: scheme.onSurface),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
      ),
      bottomNavigationBar: isWide
          ? null
          : BottomNavbar(
              selectedIndex: -1,
              onHomeTap: () => context.go('/community'),
              onJournalTap: () => context.go('/journal'),
              onNotificationsTap: () => context.go('/notifications'),
            ),
      body: isWide
          ? Row(
              children: <Widget>[
                _PatientCalendarRail(theme: theme),
                Expanded(
                  child: _PatientCalendarContent(
                    selectedDay: selectedDay,
                    focusedDay: focusedDay,
                    appointmentsAsync: appointmentsAsync,
                  ),
                ),
              ],
            )
          : _PatientCalendarContent(
              selectedDay: selectedDay,
              focusedDay: focusedDay,
              appointmentsAsync: appointmentsAsync,
            ),
    );
  }
}

class _PatientCalendarContent extends ConsumerWidget {
  const _PatientCalendarContent({
    required this.selectedDay,
    required this.focusedDay,
    required this.appointmentsAsync,
  });

  final DateTime selectedDay;
  final DateTime focusedDay;
  final AsyncValue<List<AppointmentModel>> appointmentsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    // ── Month-range markers ──────────────────────────────────────────────────
    final monthStart = DateTime(focusedDay.year, focusedDay.month, 1);
    final monthEnd = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    final rangeArg = (start: monthStart, end: monthEnd);
    final monthAsync = ref.watch(patientMonthAppointmentsProvider(rangeArg));

    final Map<DateTime, List<AppointmentType>> eventMap = {};
    for (final apt in monthAsync.asData?.value ?? const <AppointmentModel>[]) {
      final key = DateTime(
        apt.appointmentDate.year,
        apt.appointmentDate.month,
        apt.appointmentDate.day,
      );
      eventMap.putIfAbsent(key, () => []).add(apt.type);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: TableCalendar<AppointmentType>(
              key: ValueKey((
                focusedDay.year,
                focusedDay.month,
                monthAsync.hasValue,
              )),
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: focusedDay,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              eventLoader: (day) {
                final key = DateTime(day.year, day.month, day.day);
                return eventMap[key] ?? const [];
              },
              onDaySelected: (selected, focused) {
                ref.read(selectedCalendarDateProvider.notifier).state =
                    DateTime(selected.year, selected.month, selected.day);
                ref.read(focusedCalendarDateProvider.notifier).state = focused;
                ref.invalidate(patientAppointmentsBySelectedDateProvider);
              },
              onPageChanged: (focused) {
                ref.read(focusedCalendarDateProvider.notifier).state = focused;
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.30),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 2,
              ),
              calendarBuilders: CalendarBuilders<AppointmentType>(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  final hasPatient = events.contains(AppointmentType.patient);
                  final hasSpecial = events.contains(AppointmentType.special);
                  return Positioned(
                    bottom: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (hasPatient) _appointmentDot(scheme.primary),
                        if (hasSpecial) _appointmentDot(Colors.orange),
                      ],
                    ),
                  );
                },
              ),
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Text(
                'My appointments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                _prettyDate(selectedDay),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AppointmentList(
              appointments: appointmentsAsync,
              showDoctorName: true,
              onRetry: () =>
                  ref.invalidate(patientAppointmentsBySelectedDateProvider),
            ),
          ),
        ],
      ),
    );
  }

  static String _prettyDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static Widget _appointmentDot(Color color) => Container(
    width: 6,
    height: 6,
    margin: const EdgeInsets.symmetric(horizontal: 1.5),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _PatientCalendarRail extends StatelessWidget {
  const _PatientCalendarRail({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      width: 92,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? scheme.surfaceContainerHighest,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: NavigationRail(
        selectedIndex: 1,
        labelType: NavigationRailLabelType.all,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/community');
              return;
            case 1:
              context.go('/calendar');
              return;
            case 2:
              context.go('/notifications');
              return;
          }
        },
        selectedIconTheme: const IconThemeData(color: Palette.greenColor),
        selectedLabelTextStyle: const TextStyle(color: Palette.greenColor),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
        destinations: const <NavigationRailDestination>[
          NavigationRailDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: Text('Home'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: Text('Calendar'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: Text('Alerts'),
          ),
        ],
      ),
    );
  }
}
