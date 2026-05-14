import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:frontend/features/journal/controller/journal_controller.dart';
import 'package:frontend/features/journal/model/journal_entry_model.dart';
import 'package:frontend/features/lifestyle/data/recommendation_repository.dart';
import 'package:frontend/features/lifestyle/model/health_context.dart';
import 'package:frontend/features/lifestyle/model/lifestyle_tip.dart';
import 'package:frontend/features/lifestyle/model/meal_plan.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class LifestyleState {
  const LifestyleState({
    this.isLoading = false,
    this.healthContext = const HealthContext(illnessType: ''),
    this.mealPlans = const [],
    this.tips = const [],
    this.error,
  });

  final bool isLoading;
  final HealthContext healthContext;
  final List<MealPlan> mealPlans;
  final List<LifestyleTip> tips;
  final String? error;

  bool get hasData => mealPlans.isNotEmpty || tips.isNotEmpty;

  LifestyleState copyWith({
    bool? isLoading,
    HealthContext? healthContext,
    List<MealPlan>? mealPlans,
    List<LifestyleTip>? tips,
    String? error,
  }) {
    return LifestyleState(
      isLoading: isLoading ?? this.isLoading,
      healthContext: healthContext ?? this.healthContext,
      mealPlans: mealPlans ?? this.mealPlans,
      tips: tips ?? this.tips,
      error: error,
    );
  }
}

// ── Controller ────────────────────────────────────────────────────────────────

class LifestyleController extends StateNotifier<LifestyleState> {
  LifestyleController(this._ref) : super(const LifestyleState()) {
    _init();
  }

  final Ref _ref;

  void _init() {
    // Seed from whatever entries are already cached.
    final current = _ref.read(journalEntriesProvider).asData?.value ?? [];
    _refresh(current);

    // Re-run whenever journal entries change (e.g. after a new entry is logged).
    _ref.listen<AsyncValue<List<JournalEntryModel>>>(
      journalEntriesProvider,
      (_, next) {
        final entries = next.asData?.value ?? [];
        _refresh(entries);
      },
    );
  }

  Future<void> _refresh(List<JournalEntryModel> entries) async {
    final ctx = HealthContext.fromEntries(entries);
    state = state.copyWith(isLoading: true, healthContext: ctx);

    try {
      final data = await _ref
          .read(recommendationRepositoryProvider)
          .fetchRecommendations(ctx);
      state = state.copyWith(
        isLoading: false,
        mealPlans: data.mealPlans,
        tips: data.tips,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load recommendations.',
      );
    }
  }

  /// Force a manual refresh (e.g. pull-to-refresh).
  Future<void> refresh() async {
    final entries = _ref.read(journalEntriesProvider).asData?.value ?? [];
    await _refresh(entries);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final lifestyleControllerProvider =
    StateNotifierProvider<LifestyleController, LifestyleState>((ref) {
  return LifestyleController(ref);
});
