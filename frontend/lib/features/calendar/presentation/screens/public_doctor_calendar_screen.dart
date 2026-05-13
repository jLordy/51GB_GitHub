import 'package:frontend/features/calendar/controller/calendar_provider.dart';
import 'package:frontend/features/calendar/model/appointment_model.dart';
import 'package:frontend/features/calendar/presentation/widgets/appointment_tile.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

class PublicDoctorCalendarScreen extends ConsumerStatefulWidget {
  const PublicDoctorCalendarScreen({
    super.key,
    required this.doctorUid,
    this.doctorName,
  });

  final String doctorUid;

  /// Optional display name shown in the AppBar title.
  final String? doctorName;

  @override
  ConsumerState<PublicDoctorCalendarScreen> createState() =>
      _PublicDoctorCalendarScreenState();
}

class _PublicDoctorCalendarScreenState
    extends ConsumerState<PublicDoctorCalendarScreen> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _focusedDay = _selectedDay;
  }

  void _onDaySelected(DateTime selected, DateTime focused) {
    setState(() {
      _selectedDay = DateTime(selected.year, selected.month, selected.day);
      _focusedDay = focused;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeNotifierProvider);
    final scheme = theme.colorScheme;
    final bg = theme.scaffoldBackgroundColor;

    final String title = widget.doctorName?.trim().isNotEmpty == true
        ? widget.doctorName!.trim()
        : 'Doctor Schedule';

    final scheduleAsync = ref.watch(
      publicDoctorScheduleProvider((uid: widget.doctorUid, date: _selectedDay)),
    );

    // ── Month-range markers ──────────────────────────────────────────────────
    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthEnd = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final monthAsync = ref.watch(
      publicDoctorMonthScheduleProvider((
        uid: widget.doctorUid,
        start: monthStart,
        end: monthEnd,
      )),
    );

    final Map<DateTime, List<AppointmentType>> eventMap = {};
    for (final apt in monthAsync.asData?.value ?? const <AppointmentModel>[]) {
      final key = DateTime(
        apt.appointmentDate.year,
        apt.appointmentDate.month,
        apt.appointmentDate.day,
      );
      eventMap.putIfAbsent(key, () => []).add(apt.type);
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BackButton(color: scheme.onSurface),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            Text(
              'Clinic Schedule',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Column(
          children: <Widget>[
            // ── Calendar ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: TableCalendar<AppointmentType>(
                key: ValueKey((
                  _focusedDay.year,
                  _focusedDay.month,
                  monthAsync.hasValue,
                )),
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: _onDaySelected,
                eventLoader: (day) {
                  final key = DateTime(day.year, day.month, day.day);
                  return eventMap[key] ?? const [];
                },
                onPageChanged: (focused) {
                  setState(() => _focusedDay = focused);
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
                    final hasSpecial = events.contains(AppointmentType.special);
                    return Positioned(
                      bottom: 1,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
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
            // ── Date header ──────────────────────────────────────────────────
            Row(
              children: <Widget>[
                Text(
                  'Schedule',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  _prettyDate(_selectedDay),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Schedule list ─────────────────────────────────────────────────
            Expanded(
              child: scheduleAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.calendar_today_outlined, color: scheme.error),
                      const SizedBox(height: 10),
                      Text(
                        'Failed to load schedule.',
                        style: TextStyle(color: scheme.error),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(
                          publicDoctorScheduleProvider((
                            uid: widget.doctorUid,
                            date: _selectedDay,
                          )),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (List<AppointmentModel> items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.event_available_rounded,
                            size: 48,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.40,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No clinic schedule for this date.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        AppointmentTile(appointment: items[index]),
                  );
                },
              ),
            ),
          ],
        ),
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
