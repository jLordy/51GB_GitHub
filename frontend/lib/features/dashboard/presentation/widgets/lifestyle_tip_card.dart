import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/dashboard/presentation/widgets/glassmorphic_container.dart';
import 'package:frontend/theme/palette.dart';

// Maps primary illness_type to a (icon, title, body) tip tuple.
// Extend this map as new illness types are added to the seed data.
const _tipMap = <String, (IconData, String, String)>{
  'diabetes': (
    Icons.restaurant_outlined,
    'Low-GI Meal Tip',
    'Choose brown rice over white rice today. Pair it with ampalaya (bitter melon) — a Filipino vegetable with natural blood-sugar benefits.',
  ),
  'hypertension': (
    Icons.favorite_border,
    'Heart-Smart Tip',
    'Try oatmeal with banana for breakfast. Reduce asin sa ulam and use sibuyas and bawang for flavour instead.',
  ),
  'heart_disease': (
    Icons.monitor_heart_outlined,
    'Cardiac Tip',
    'A small serving of bangus (milkfish) provides omega-3 fats that support heart rhythm and reduce inflammation.',
  ),
  'ckd': (
    Icons.water_drop_outlined,
    'Kidney-Friendly Tip',
    'Stick to boiled or steamed foods with low phosphorus. Kangkong and sayote are great low-potassium vegetable choices.',
  ),
  'asthma': (
    Icons.air_outlined,
    'Breathing Tip',
    'Avoid cold drinks today. Warm ginger tea with honey soothes airways and may reduce morning wheeze.',
  ),
  'tuberculosis': (
    Icons.medical_services_outlined,
    'Nutrition Tip',
    'High-protein foods like eggs, fish, and legumes support tissue repair during TB treatment. Eat regularly.',
  ),
  'cancer': (
    Icons.spa_outlined,
    'Nourishment Tip',
    'Small, frequent meals help maintain energy levels. Include soft, easy-to-digest foods like lugaw or arroz caldo.',
  ),
  'stroke': (
    Icons.directions_walk_outlined,
    'Rehab Tip',
    'Short, gentle walks or range-of-motion exercises today support circulation and rehabilitation progress.',
  ),
  'arthritis': (
    Icons.self_improvement_outlined,
    'Joint Care Tip',
    'Warm compress on stiff joints before morning activity. Turmeric in your meals may help reduce inflammation.',
  ),
  'mental_health': (
    Icons.nightlight_outlined,
    'Wellness Tip',
    'Aim for 7–8 hours of sleep tonight. A consistent sleep schedule is one of the most powerful mood stabilisers.',
  ),
};

const _defaultTip = (
  Icons.eco_outlined,
  'Daily Wellness',
  'Drink at least 8 glasses of water today. A balanced Filipino meal of rice, protein, and vegetables keeps energy stable.',
);

/// Displays a contextual daily tip based on the patient's illness type.
///
/// In production, replace the hardcoded illness lookup with a watch on a
/// patientProfileProvider that exposes `List<String> illnessTypes`.
class LifestyleTipCard extends ConsumerWidget {
  const LifestyleTipCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // TODO: replace with ref.watch(patientProfileProvider).illnessTypes.first
    // For now derives from currentUserProvider once illness_type is surfaced there.
    const String illnessType = 'diabetes';
    final (icon, title, body) = _tipMap[illnessType] ?? _defaultTip;

    return GlassmorphicContainer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Tip category icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Palette.greenColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: Palette.greenColor, size: 22),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
