import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/core/widgets/left_sidebar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/features/connections/model/connection_model.dart';
import 'package:frontend/features/connections/model/patient_profile_model.dart';
import 'package:frontend/features/journal/controller/journal_controller.dart';
import 'package:frontend/theme/palette.dart';
import 'package:go_router/go_router.dart';

class PatientsScreen extends ConsumerWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeNotifierProvider);
    final cs = appTheme.colorScheme;
    final isDark = appTheme.brightness == Brightness.dark;
    final bg = isDark ? Palette.darkSurfaceColor : const Color(0xFFF5F9F7);

    final currentUser = ref.watch(currentUserProvider);
    final myUid = currentUser?.uid ?? '';

    final acceptedAsync = ref.watch(acceptedConnectionsProvider);
    final profiles = ref.watch(patientProfilesAsync);

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      drawer: const LeftSidebar(),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: Icon(Icons.menu_rounded, color: cs.onSurfaceVariant),
          ),
        ),
        title: Text(
          'My Patients',
          style: appTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none_outlined, color: cs.onSurfaceVariant),
            onPressed: () => context.go('/notifications'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outlineVariant),
        ),
      ),
      bottomNavigationBar: const BottomNavbar(selectedIndex: 1),
      body: acceptedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'Could not load patients.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        data: (connections) {
          if (connections.isEmpty) {
            return _EmptyState(cs: cs, isDark: isDark);
          }

          return RefreshIndicator(
            color: Palette.greenColor,
            onRefresh: () async {
              ref.invalidate(acceptedConnectionsProvider);
              ref.invalidate(patientProfilesProvider);
            },
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: connections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final conn = connections[index];
                final patientUid = conn.otherUid(myUid);
                final profile = profiles.value?[patientUid];
                return _PatientDetailCard(
                  conn: conn,
                  patientUid: patientUid,
                  profile: profile,
                  cs: cs,
                  isDark: isDark,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// Convenience accessor for the profiles map AsyncValue
final patientProfilesAsync = Provider<AsyncValue<Map<String, PatientProfileModel>>>((ref) {
  return ref.watch(patientProfilesProvider);
});

// ─────────────────────────────────────────────────────────────────────────────
// Patient detail card — basic info + latest journal vitals listed vertically
// ─────────────────────────────────────────────────────────────────────────────

class _PatientDetailCard extends ConsumerWidget {
  const _PatientDetailCard({
    required this.conn,
    required this.patientUid,
    required this.profile,
    required this.cs,
    required this.isDark,
  });

  final ConnectionModel conn;
  final String patientUid;
  final PatientProfileModel? profile;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final name = profile?.fullName ?? 'Unknown Patient';
    final initials = _initials(name);
    final age = profile?.age;
    final illness = profile?.illnessType ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Palette.darkSurfaceContainerColor
            : Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.50)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Palette.greenColor.withValues(alpha: 0.15),
                  child: Text(
                    initials,
                    style: tt.titleSmall?.copyWith(
                      color: Palette.greenColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (age != null) ...[
                            Text(
                              '$age yrs',
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                          if (illness.isNotEmpty)
                            _IllnessChip(illness: illness, isDark: isDark),
                        ],
                      ),
                    ],
                  ),
                ),
                // Chat shortcut
                GestureDetector(
                  onTap: () => context.go('/chat'),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Palette.greenColor.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 17,
                      color: Palette.greenColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.50)),

          // Latest vitals section
          _LatestVitals(
            patientUid: patientUid,
            illness: illness,
            cs: cs,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Latest vitals — fetches most recent journal entry, lists metrics vertically
// ─────────────────────────────────────────────────────────────────────────────

class _LatestVitals extends ConsumerWidget {
  const _LatestVitals({
    required this.patientUid,
    required this.illness,
    required this.cs,
    required this.isDark,
  });

  final String patientUid;
  final String illness;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final entriesAsync = ref.watch(patientJournalEntriesProvider(patientUid));

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: entriesAsync.when(
        loading: () => const SizedBox(
          height: 48,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => Text(
          'Could not load vitals',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'No journal entries yet',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          final latest = entries.first;
          final metrics = _extractMetrics(latest.answers, illness);
          final loggedDate = _formatDate(latest.updatedAt ?? latest.submittedAt);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section label + date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Latest Entry',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    loggedDate,
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Vertical metric rows
              ...metrics.map(
                (m) => _MetricRow(
                  icon: m.icon,
                  label: m.label,
                  value: m.value,
                  statusColor: m.statusColor,
                  cs: cs,
                  isDark: isDark,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static List<_Metric> _extractMetrics(Map<String, dynamic> answers, String illness) {
    final metrics = <_Metric>[];

    // ── Blood pressure ────────────────────────────────────────────────────────
    final bp = _findMap(answers, ['blood_pressure', 'bp', 'bp_reading']);
    if (bp != null) {
      final sys = bp['systolic'] ?? bp['sys'];
      final dia = bp['diastolic'] ?? bp['dia'];
      if (sys != null && dia != null) {
        final sysInt = (sys is num) ? sys.toInt() : int.tryParse(sys.toString()) ?? 0;
        final Color statusColor = sysInt >= 140
            ? const Color(0xFFD62828)
            : sysInt >= 120
            ? const Color(0xFFFF9800)
            : const Color(0xFF359361);
        metrics.add(_Metric(
          icon: Icons.favorite_outline_rounded,
          label: 'Blood Pressure',
          value: '$sys / $dia mmHg',
          statusColor: statusColor,
        ));
      }
    }

    // ── Blood glucose ─────────────────────────────────────────────────────────
    final glucose = _findNum(answers, [
      'blood_glucose',
      'fasting_glucose',
      'glucose_level',
      'blood_sugar',
    ]);
    if (glucose != null) {
      final Color statusColor = glucose > 180
          ? const Color(0xFFD62828)
          : glucose > 140
          ? const Color(0xFFFF9800)
          : const Color(0xFF359361);
      metrics.add(_Metric(
        icon: Icons.water_drop_outlined,
        label: 'Blood Glucose',
        value: '${glucose.toStringAsFixed(1)} mg/dL',
        statusColor: statusColor,
      ));
    }

    // ── Weight ────────────────────────────────────────────────────────────────
    final weightMap = _findMap(answers, ['weight', 'body_weight']);
    if (weightMap != null) {
      final val = weightMap['value'] ?? weightMap['weight'];
      final unit = weightMap['unit'] ?? 'kg';
      if (val != null) {
        metrics.add(_Metric(
          icon: Icons.monitor_weight_outlined,
          label: 'Weight',
          value: '$val $unit',
          statusColor: null,
        ));
      }
    } else {
      final weightNum = _findNum(answers, ['weight', 'body_weight']);
      if (weightNum != null) {
        metrics.add(_Metric(
          icon: Icons.monitor_weight_outlined,
          label: 'Weight',
          value: '${weightNum.toStringAsFixed(1)} kg',
          statusColor: null,
        ));
      }
    }

    // ── Creatinine (CKD) ──────────────────────────────────────────────────────
    if (illness.toLowerCase() == 'ckd') {
      final creatinine = _findNum(answers, [
        'creatinine',
        'creatinine_level',
        'serum_creatinine',
      ]);
      if (creatinine != null) {
        final Color statusColor = creatinine > 1.2
            ? const Color(0xFFD62828)
            : const Color(0xFF359361);
        metrics.add(_Metric(
          icon: Icons.science_outlined,
          label: 'Creatinine',
          value: '${creatinine.toStringAsFixed(2)} mg/dL',
          statusColor: statusColor,
        ));
      }
    }

    // ── HbA1c (Diabetes) ─────────────────────────────────────────────────────
    if (illness.toLowerCase() == 'diabetes') {
      final hba1c = _findNum(answers, ['hba1c', 'a1c', 'glycated_hemoglobin']);
      if (hba1c != null) {
        final Color statusColor = hba1c > 7.0
            ? const Color(0xFFD62828)
            : const Color(0xFF359361);
        metrics.add(_Metric(
          icon: Icons.bloodtype_outlined,
          label: 'HbA1c',
          value: '${hba1c.toStringAsFixed(1)}%',
          statusColor: statusColor,
        ));
      }
    }

    // ── Pain level ────────────────────────────────────────────────────────────
    final pain = _findNum(answers, ['pain_level', 'pain', 'pain_scale']);
    if (pain != null) {
      final Color statusColor = pain >= 7
          ? const Color(0xFFD62828)
          : pain >= 4
          ? const Color(0xFFFF9800)
          : const Color(0xFF359361);
      metrics.add(_Metric(
        icon: Icons.sentiment_dissatisfied_outlined,
        label: 'Pain Level',
        value: '${pain.toInt()} / 10',
        statusColor: statusColor,
      ));
    }

    // ── Mood ─────────────────────────────────────────────────────────────────
    final mood = _findString(answers, ['mood', 'mood_today', 'emotional_state']);
    if (mood != null) {
      metrics.add(_Metric(
        icon: Icons.sentiment_satisfied_outlined,
        label: 'Mood',
        value: _humanise(mood),
        statusColor: null,
      ));
    }

    // ── Fatigue ───────────────────────────────────────────────────────────────
    final fatigue = _findNum(answers, ['fatigue', 'fatigue_level', 'energy_level']);
    if (fatigue != null) {
      metrics.add(_Metric(
        icon: Icons.battery_2_bar_outlined,
        label: 'Fatigue',
        value: '${fatigue.toInt()} / 10',
        statusColor: null,
      ));
    }

    // ── If nothing was matched, show first 4 raw answers ─────────────────────
    if (metrics.isEmpty) {
      int shown = 0;
      for (final entry in answers.entries) {
        if (shown >= 4) break;
        final label = entry.key
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
        final value = _formatRaw(entry.value);
        if (value.isNotEmpty && value != 'null') {
          metrics.add(_Metric(
            icon: Icons.circle_outlined,
            label: label,
            value: value,
            statusColor: null,
          ));
          shown++;
        }
      }
    }

    return metrics;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic>? _findMap(Map<String, dynamic> answers, List<String> keys) {
    for (final k in keys) {
      if (answers.containsKey(k) && answers[k] is Map) {
        return Map<String, dynamic>.from(answers[k] as Map);
      }
    }
    return null;
  }

  static double? _findNum(Map<String, dynamic> answers, List<String> keys) {
    for (final k in keys) {
      if (answers.containsKey(k)) {
        final v = answers[k];
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v);
      }
    }
    return null;
  }

  static String? _findString(Map<String, dynamic> answers, List<String> keys) {
    for (final k in keys) {
      if (answers.containsKey(k)) {
        final v = answers[k];
        if (v is String && v.isNotEmpty) return v;
      }
    }
    return null;
  }

  static String _humanise(String raw) {
    final words = raw.replaceAll('_', ' ').trim().split(' ');
    if (words.isEmpty) return raw;
    return '${words.first[0].toUpperCase()}${words.first.substring(1)}'
        '${words.length > 1 ? ' ${words.skip(1).join(' ')}' : ''}';
  }

  static String _formatRaw(dynamic v) {
    if (v == null) return '';
    if (v is Map) {
      return v.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
    if (v is List) return v.map((x) => x.toString()).join(', ');
    return v.toString();
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric data class
// ─────────────────────────────────────────────────────────────────────────────

class _Metric {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.statusColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? statusColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric row — one health detail listed vertically
// ─────────────────────────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.statusColor,
    required this.cs,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? statusColor;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = statusColor ?? cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: statusColor ?? cs.onSurface,
            ),
          ),
          if (statusColor != null) ...[
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Illness chip
// ─────────────────────────────────────────────────────────────────────────────

class _IllnessChip extends StatelessWidget {
  const _IllnessChip({required this.illness, required this.isDark});

  final String illness;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (illness.toLowerCase()) {
      'ckd' => ('CKD', const Color(0xFF2196F3)),
      'diabetes' => ('Diabetes', const Color(0xFFFF9800)),
      'oncology' => ('Oncology', const Color(0xFF9C27B0)),
      _ => (
        illness.isNotEmpty
            ? '${illness[0].toUpperCase()}${illness.substring(1)}'
            : 'Other',
        const Color(0xFF607D8B),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs, required this.isDark});

  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 60,
              color: cs.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No patients yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Accept connection requests to start monitoring your patients.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => context.go('/connections'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Palette.greenColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Palette.greenColor.withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  'View Connections',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Palette.greenColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
