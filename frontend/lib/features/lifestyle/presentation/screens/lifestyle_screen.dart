import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/lifestyle/controller/lifestyle_controller.dart';
import 'package:frontend/features/lifestyle/model/lifestyle_tip.dart';
import 'package:frontend/features/lifestyle/model/meal_plan.dart';
import 'package:frontend/features/dashboard/presentation/widgets/glassmorphic_container.dart';
import 'package:frontend/theme/palette.dart';
import 'package:go_router/go_router.dart';

// Macronutrient bar colours — palette-independent, WCAG AA on both themes.
const _kCarbColor = Color(0xFFE8A838);
const _kProteinColor = Color(0xFF4ECDC4);
const _kFatColor = Color(0xFFB57BEE);

const _kCategoryColors = <String, Color>{
  'Exercise': Color(0xFF4ECDC4),
  'Nutrition': Color(0xFF6BCB77),
  'Hydration': Color(0xFF4D96FF),
  'Sleep': Color(0xFFB57BEE),
  'Stress': Color(0xFFFF6B6B),
};

class LifestyleScreen extends ConsumerWidget {
  const LifestyleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lifestyleControllerProvider);
    final appTheme = ref.watch(themeNotifierProvider);
    final cs = appTheme.colorScheme;
    final bg = appTheme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -50,
            child: _Orb(color: Palette.greenColor.withValues(alpha: 0.14), size: 260),
          ),
          Positioned(
            top: 200,
            left: -70,
            child: _Orb(color: const Color(0xFF4ECDC4).withValues(alpha: 0.08), size: 200),
          ),
          Positioned(
            bottom: 100,
            right: -40,
            child: _Orb(color: const Color(0xFFB57BEE).withValues(alpha: 0.07), size: 180),
          ),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: cs.primary,
              backgroundColor: cs.surfaceContainerHighest,
              onRefresh: () =>
                  ref.read(lifestyleControllerProvider.notifier).refresh(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAppBar(context, cs),
                  if (state.isLoading && !state.hasData)
                    SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      ),
                    )
                  else if (state.error != null && !state.hasData)
                    SliverFillRemaining(
                      child: _ErrorState(message: state.error!),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ConditionBanner(state: state),
                            const SizedBox(height: 28),
                            _SectionHeader(
                              label: 'Your Meal Plans',
                              subtitle: 'Tailored to your health profile',
                            ),
                            const SizedBox(height: 14),
                            _MealPlanRow(plans: state.mealPlans),
                            const SizedBox(height: 28),
                            _SectionHeader(
                              label: 'Daily Lifestyle Tips',
                              subtitle: 'Evidence-based actions for today',
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      sliver: SliverList.builder(
                        itemCount: state.tips.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TipCard(tip: state.tips[i]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, ColorScheme cs) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      pinned: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: cs.onSurface),
        onPressed: () => context.go('/home'),
      ),
      title: const Text(
        'AGAPAY',
        style: TextStyle(
          fontFamily: 'TanSongbird',
          fontSize: 20,
          color: Palette.greenColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Decorative background orb ─────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.subtitle});

  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── Condition banner ──────────────────────────────────────────────────────────

class _ConditionBanner extends StatelessWidget {
  const _ConditionBanner({required this.state});

  final LifestyleState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ctx = state.healthContext;
    final conditionName = ctx.isEmpty ? 'General Wellness' : ctx.displayName;

    return GlassmorphicContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.health_and_safety_outlined,
                color: cs.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Health Profile',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  conditionName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (ctx.energyLevel != null) _EnergyChip(level: ctx.energyLevel!),
        ],
      ),
    );
  }
}

class _EnergyChip extends StatelessWidget {
  const _EnergyChip({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (level.toLowerCase()) {
      'high' => const Color(0xFF6BCB77),
      'low' => const Color(0xFFFF6B6B),
      _ => cs.onSurfaceVariant,
    };
    final icon = switch (level.toLowerCase()) {
      'high' => Icons.bolt_rounded,
      'low' => Icons.battery_1_bar_rounded,
      _ => Icons.battery_3_bar_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            level[0].toUpperCase() + level.substring(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meal plan horizontal row ───────────────────────────────────────────────────

class _MealPlanRow extends StatelessWidget {
  const _MealPlanRow({required this.plans});

  final List<MealPlan> plans;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 290,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: plans.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _MealPlanCard(plan: plans[i]),
      ),
    );
  }
}

class _MealPlanCard extends StatelessWidget {
  const _MealPlanCard({required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = plan.macronutrients;

    return GlassmorphicContainer(
      width: 270,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${m.caloriesKcal} kcal / day',
            style: TextStyle(
              fontSize: 12,
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _MacroBar(macros: m),
          const SizedBox(height: 6),
          _MacroLegend(macros: m),
          const SizedBox(height: 14),
          Text(
            'Recipes',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: plan.recipes.take(3).length,
              itemBuilder: (_, i) => _RecipeRow(recipe: plan.recipes[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({required this.macros});

  final Macronutrients macros;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            Flexible(
              flex: (macros.carbFraction * 100).round(),
              child: Container(color: _kCarbColor),
            ),
            Flexible(
              flex: (macros.proteinFraction * 100).round(),
              child: Container(color: _kProteinColor),
            ),
            Flexible(
              flex: (macros.fatFraction * 100).round(),
              child: Container(color: _kFatColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroLegend extends StatelessWidget {
  const _MacroLegend({required this.macros});

  final Macronutrients macros;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _LegendDot(color: _kCarbColor, label: 'Carbs ${macros.carbsGrams}g'),
        _LegendDot(color: _kProteinColor, label: 'Protein ${macros.proteinGrams}g'),
        _LegendDot(color: _kFatColor, label: 'Fat ${macros.fatGrams}g'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.restaurant_menu_rounded,
                size: 12, color: cs.primary),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  recipe.prepTime,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lifestyle tip card ────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});

  final LifestyleTip tip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _kCategoryColors[tip.category] ?? cs.primary;
    final icon = _categoryIcon(tip.category);

    return GlassmorphicContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tip.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tip.actionableAdvice,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface,
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

  static IconData _categoryIcon(String category) {
    return switch (category) {
      'Exercise' => Icons.directions_run_rounded,
      'Nutrition' => Icons.restaurant_outlined,
      'Hydration' => Icons.water_drop_outlined,
      'Sleep' => Icons.nightlight_outlined,
      'Stress' => Icons.self_improvement_outlined,
      _ => Icons.tips_and_updates_outlined,
    };
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 52, color: cs.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
