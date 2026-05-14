import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/lifestyle/model/health_context.dart';
import 'package:frontend/features/lifestyle/model/lifestyle_tip.dart';
import 'package:frontend/features/lifestyle/model/meal_plan.dart';

final recommendationRepositoryProvider =
    Provider<RecommendationRepository>((ref) {
  return RecommendationRepository(ref.read(apiClientProvider));
});

class RecommendationData {
  const RecommendationData({
    required this.mealPlans,
    required this.tips,
  });

  final List<MealPlan> mealPlans;
  final List<LifestyleTip> tips;
}

class RecommendationRepository {
  RecommendationRepository(this._api);

  final dynamic _api; // ApiClient

  /// Offline-first: returns the local catalog immediately, then attempts a
  /// background sync from the backend to surface any updated recommendations.
  Future<RecommendationData> fetchRecommendations(HealthContext ctx) async {
    try {
      final res = await _api
          .get(
            '/api/lifestyle/recommendations',
            queryParameters: {'condition': ctx.illnessType},
            requiresAuth: true,
          )
          .timeout(const Duration(seconds: 5));

      final body = res.data as Map<String, dynamic>;
      final plans = (body['meal_plans'] as List? ?? [])
          .map((e) => MealPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      final tips = (body['tips'] as List? ?? [])
          .map((e) => LifestyleTip.fromJson(e as Map<String, dynamic>))
          .toList();

      if (plans.isNotEmpty && tips.isNotEmpty) {
        return RecommendationData(mealPlans: plans, tips: tips);
      }
    } on DioException {
      // Backend unavailable — fall through to local catalog
    } catch (_) {
      // Any other error — fall through to local catalog
    }

    return _localData(ctx.illnessType);
  }

  // ── Local catalog ────────────────────────────────────────────────────────────
  // Keyed by illness_type string. Acts as the offline NoSQL store.

  RecommendationData _localData(String illnessType) {
    final key = _normaliseKey(illnessType);
    return RecommendationData(
      mealPlans: _mealPlans[key] ?? _mealPlans['general']!,
      tips: _tips[key] ?? _tips['general']!,
    );
  }

  static String _normaliseKey(String raw) {
    final k = raw.toLowerCase();
    if (k == 'oncology') return 'cancer';
    if (k == 'heart disease') return 'heart_disease';
    if (k == 'hbp' || k == 'high blood pressure') return 'hypertension';
    return k;
  }

  static final _mealPlans = <String, List<MealPlan>>{
    // ── Diabetes ──────────────────────────────────────────────────────────────
    'diabetes': [
      MealPlan(
        id: 'dm_01',
        targetCondition: 'diabetes',
        name: 'Low-GI Filipino Plate',
        macronutrients: const Macronutrients(
          carbsGrams: 130,
          proteinGrams: 85,
          fatGrams: 45,
          caloriesKcal: 1265,
        ),
        recipes: const [
          Recipe(
            name: 'Ampalaya con Carne',
            description: 'Bitter melon stir-fried with lean beef — a proven '
                'blood-sugar moderator.',
            ingredients: [
              'Ampalaya (bitter melon)',
              'Lean beef strips',
              'Egg',
              'Onion & garlic',
              'Low-sodium soy sauce',
            ],
            prepTime: '20 min',
          ),
          Recipe(
            name: 'Sinigang na Salmon',
            description:
                'Tamarind-soured salmon soup rich in omega-3 and low in glycemic load.',
            ingredients: [
              'Salmon fillet',
              'Kangkong (water spinach)',
              'Labanos (radish)',
              'Tamarind broth',
              'Tomato & onion',
            ],
            prepTime: '30 min',
          ),
          Recipe(
            name: 'Brown Rice & Sautéed Kangkong',
            description:
                'High-fibre brown rice paired with garlic-sautéed kangkong slows glucose absorption.',
            ingredients: [
              'Brown rice (¾ cup cooked)',
              'Kangkong',
              'Garlic',
              'Olive oil',
            ],
            prepTime: '15 min',
          ),
        ],
      ),
      MealPlan(
        id: 'dm_02',
        targetCondition: 'diabetes',
        name: 'Diabetic Breakfast Set',
        macronutrients: const Macronutrients(
          carbsGrams: 55,
          proteinGrams: 28,
          fatGrams: 14,
          caloriesKcal: 458,
        ),
        recipes: const [
          Recipe(
            name: 'Egg White Tortang Talong',
            description:
                'Grilled eggplant omelette using egg whites — low fat, high protein.',
            ingredients: [
              'Eggplant (talong)',
              'Egg whites (3)',
              'Onion',
              'Tomato',
            ],
            prepTime: '15 min',
          ),
          Recipe(
            name: 'Oatmeal with Banana & Chia',
            description:
                'Rolled oats with sliced banana and chia seeds — steady energy release.',
            ingredients: [
              'Rolled oats (½ cup)',
              'Banana (½)',
              'Chia seeds (1 tbsp)',
              'Unsweetened almond milk',
            ],
            prepTime: '10 min',
          ),
        ],
      ),
    ],

    // ── CKD ──────────────────────────────────────────────────────────────────
    'ckd': [
      MealPlan(
        id: 'ckd_01',
        targetCondition: 'ckd',
        name: 'Kidney-Safe Filipino Plate',
        macronutrients: const Macronutrients(
          carbsGrams: 200,
          proteinGrams: 45,
          fatGrams: 40,
          caloriesKcal: 1320,
        ),
        recipes: const [
          Recipe(
            name: 'Boiled Sayote with Garlic',
            description:
                'Low-potassium, low-phosphorus sayote (chayote) — kidney-friendly comfort food.',
            ingredients: ['Sayote (chayote)', 'Garlic', 'Olive oil', 'Salt (minimal)'],
            prepTime: '15 min',
          ),
          Recipe(
            name: 'Steamed Tilapia with Ginger',
            description:
                'Tilapia is a moderate-protein, low-phosphorus fish suitable for CKD stage 3-4.',
            ingredients: ['Tilapia fillet', 'Ginger strips', 'Calamansi', 'Spring onion'],
            prepTime: '20 min',
          ),
          Recipe(
            name: 'White Rice with Clear Broth',
            description:
                'Plain white rice (lower potassium than brown) with lightly salted vegetable broth.',
            ingredients: [
              'White rice (¾ cup cooked)',
              'Low-sodium vegetable broth',
              'Leeks',
            ],
            prepTime: '10 min',
          ),
        ],
      ),
      MealPlan(
        id: 'ckd_02',
        targetCondition: 'ckd',
        name: 'Low-Phosphorus Snack Set',
        macronutrients: const Macronutrients(
          carbsGrams: 90,
          proteinGrams: 12,
          fatGrams: 8,
          caloriesKcal: 480,
        ),
        recipes: const [
          Recipe(
            name: 'Rice Crackers with Cucumber',
            description: 'Low-phosphorus snack — cucumber slices on plain rice crackers.',
            ingredients: ['Rice crackers (unsalted)', 'Cucumber', 'Calamansi juice'],
            prepTime: '5 min',
          ),
          Recipe(
            name: 'Apple Slices with Cream Cheese',
            description:
                'Apples are low in potassium. Cream cheese adds calories without excess protein.',
            ingredients: ['Apple', 'Cream cheese (1 tbsp)', 'Cinnamon (pinch)'],
            prepTime: '5 min',
          ),
        ],
      ),
    ],

    // ── Hypertension ─────────────────────────────────────────────────────────
    'hypertension': [
      MealPlan(
        id: 'htn_01',
        targetCondition: 'hypertension',
        name: 'DASH-Inspired Filipino Plate',
        macronutrients: const Macronutrients(
          carbsGrams: 150,
          proteinGrams: 70,
          fatGrams: 35,
          caloriesKcal: 1195,
        ),
        recipes: const [
          Recipe(
            name: 'Low-Salt Sinigang na Hipon',
            description:
                'Shrimp sinigang prepared without patis (fish sauce) — same sour flavour, dramatically less sodium.',
            ingredients: [
              'Shrimp',
              'Kangkong',
              'Tamarind (fresh)',
              'Tomato & onion',
              'Radish',
            ],
            prepTime: '25 min',
          ),
          Recipe(
            name: 'Baked Bangus with Tomato',
            description:
                'Oven-baked milkfish avoids added oil. Tomato and onion stuffing adds potassium — a natural BP moderator.',
            ingredients: ['Bangus (milkfish)', 'Tomato', 'Onion', 'Garlic', 'Calamansi'],
            prepTime: '35 min',
          ),
          Recipe(
            name: 'Steamed Rice & Mixed Greens',
            description: 'Half-cup rice with steamed pechay and carrots — fibre-rich, low sodium.',
            ingredients: ['Rice (½ cup cooked)', 'Pechay', 'Carrots', 'Garlic (lightly sautéed)'],
            prepTime: '15 min',
          ),
        ],
      ),
    ],

    // ── Heart Disease ─────────────────────────────────────────────────────────
    'heart_disease': [
      MealPlan(
        id: 'hd_01',
        targetCondition: 'heart_disease',
        name: 'Cardiac-Friendly Filipino Plate',
        macronutrients: const Macronutrients(
          carbsGrams: 140,
          proteinGrams: 80,
          fatGrams: 30,
          caloriesKcal: 1150,
        ),
        recipes: const [
          Recipe(
            name: 'Baked Salmon with Calamansi',
            description:
                'Salmon is rich in omega-3 fatty acids — reduces triglycerides and supports heart rhythm.',
            ingredients: ['Salmon fillet', 'Calamansi', 'Garlic', 'Olive oil', 'Pepper'],
            prepTime: '25 min',
          ),
          Recipe(
            name: 'Chopsuey (Mixed Vegetable Stir-Fry)',
            description:
                'A colourful mix of vegetables with minimal oil — antioxidants support vascular health.',
            ingredients: [
              'Cauliflower',
              'Carrots',
              'Snow peas',
              'Bell pepper',
              'Cabbage',
              'Low-sodium oyster sauce',
            ],
            prepTime: '20 min',
          ),
          Recipe(
            name: 'Brown Rice with Miso Soup',
            description:
                'Brown rice fibre lowers LDL cholesterol. Low-sodium miso provides beneficial fermented compounds.',
            ingredients: ['Brown rice (¾ cup)', 'Low-sodium miso paste', 'Tofu', 'Spring onion'],
            prepTime: '20 min',
          ),
        ],
      ),
    ],

    // ── Stroke ────────────────────────────────────────────────────────────────
    'stroke': [
      MealPlan(
        id: 'str_01',
        targetCondition: 'stroke',
        name: 'Stroke Recovery Soft Diet',
        macronutrients: const Macronutrients(
          carbsGrams: 160,
          proteinGrams: 75,
          fatGrams: 35,
          caloriesKcal: 1255,
        ),
        recipes: const [
          Recipe(
            name: 'Soft Arroz Caldo',
            description:
                'Soft-textured rice porridge with chicken — easy to swallow, high in calories for recovery.',
            ingredients: ['Glutinous rice', 'Chicken (shredded)', 'Ginger', 'Garlic', 'Fish sauce (light)'],
            prepTime: '40 min',
          ),
          Recipe(
            name: 'Mashed Kamote (Sweet Potato)',
            description:
                'Rich in potassium and antioxidants. Soft texture accommodates swallowing difficulties.',
            ingredients: ['Purple kamote (sweet potato)', 'Coconut milk (light)', 'Honey (1 tsp)'],
            prepTime: '20 min',
          ),
          Recipe(
            name: 'Smooth Mongo Soup',
            description:
                'Blended mung bean soup — high in protein and folate, promotes vascular repair.',
            ingredients: ['Mung beans', 'Malunggay (moringa)', 'Garlic', 'Onion', 'Fish broth'],
            prepTime: '35 min',
          ),
        ],
      ),
    ],

    // ── Cancer / Oncology ─────────────────────────────────────────────────────
    'cancer': [
      MealPlan(
        id: 'onc_01',
        targetCondition: 'cancer',
        name: 'High-Protein Recovery Meals',
        macronutrients: const Macronutrients(
          carbsGrams: 160,
          proteinGrams: 100,
          fatGrams: 55,
          caloriesKcal: 1555,
        ),
        recipes: const [
          Recipe(
            name: 'Lugaw with Tofu & Malunggay',
            description:
                'Soft rice porridge enriched with silken tofu and moringa — high protein, easy on the stomach.',
            ingredients: ['Rice', 'Silken tofu', 'Malunggay leaves', 'Ginger', 'Garlic'],
            prepTime: '30 min',
          ),
          Recipe(
            name: 'Chicken Tinola',
            description:
                'Ginger-broth chicken soup with papaya and malunggay — anti-inflammatory and nutrient-dense.',
            ingredients: ['Chicken (bone-in)', 'Green papaya', 'Malunggay', 'Ginger', 'Fish sauce'],
            prepTime: '35 min',
          ),
          Recipe(
            name: 'Avocado & Banana Smoothie',
            description:
                'Calorie-dense, nutrient-rich smoothie for patients with reduced appetite.',
            ingredients: ['Avocado (½)', 'Banana', 'Whole milk or full-fat coconut milk', 'Honey'],
            prepTime: '5 min',
          ),
        ],
      ),
    ],

    // ── Asthma ────────────────────────────────────────────────────────────────
    'asthma': [
      MealPlan(
        id: 'ast_01',
        targetCondition: 'asthma',
        name: 'Anti-Inflammatory Filipino Meals',
        macronutrients: const Macronutrients(
          carbsGrams: 155,
          proteinGrams: 72,
          fatGrams: 42,
          caloriesKcal: 1290,
        ),
        recipes: const [
          Recipe(
            name: 'Ginger-Turmeric Tinola',
            description:
                'Added turmeric to the classic tinola — both ginger and turmeric are natural bronchodilators.',
            ingredients: ['Chicken', 'Green papaya', 'Malunggay', 'Ginger', 'Turmeric (½ tsp)'],
            prepTime: '35 min',
          ),
          Recipe(
            name: 'Warm Garlic Sardines on Toast',
            description:
                'Sardines are rich in omega-3 which reduces airway inflammation. Whole-grain toast adds fibre.',
            ingredients: ['Canned sardines (in water)', 'Whole-grain bread', 'Garlic', 'Tomato'],
            prepTime: '10 min',
          ),
          Recipe(
            name: 'Steamed Broccoli & Brown Rice',
            description:
                'Vitamin C in broccoli helps counter oxidative stress in the airways.',
            ingredients: ['Broccoli', 'Brown rice', 'Lemon juice', 'Olive oil'],
            prepTime: '20 min',
          ),
        ],
      ),
    ],

    // ── Tuberculosis ──────────────────────────────────────────────────────────
    'tuberculosis': [
      MealPlan(
        id: 'tb_01',
        targetCondition: 'tuberculosis',
        name: 'High-Protein TB Support Diet',
        macronutrients: const Macronutrients(
          carbsGrams: 175,
          proteinGrams: 95,
          fatGrams: 48,
          caloriesKcal: 1504,
        ),
        recipes: const [
          Recipe(
            name: 'Chicken Egg & Vegetable Soup',
            description:
                'High-protein soup supporting tissue repair during TB treatment.',
            ingredients: ['Chicken breast', 'Eggs (2)', 'Carrots', 'Potatoes', 'Low-sodium broth'],
            prepTime: '30 min',
          ),
          Recipe(
            name: 'Adobong Isda (Fish Adobo)',
            description:
                'Fish adobo in vinegar sauce — high protein, anti-bacterial properties from vinegar and garlic.',
            ingredients: ['Bangus or tilapia', 'Vinegar', 'Garlic', 'Bay leaves', 'Black pepper'],
            prepTime: '25 min',
          ),
          Recipe(
            name: 'Legume & Pechay Stir-Fry',
            description:
                'Chickpeas or black beans with pechay — plant protein + iron supports haemoglobin during recovery.',
            ingredients: ['Chickpeas (canned)', 'Pechay', 'Garlic', 'Olive oil', 'Calamansi'],
            prepTime: '15 min',
          ),
        ],
      ),
    ],

    // ── Arthritis ─────────────────────────────────────────────────────────────
    'arthritis': [
      MealPlan(
        id: 'art_01',
        targetCondition: 'arthritis',
        name: 'Joint-Friendly Anti-Inflammatory Diet',
        macronutrients: const Macronutrients(
          carbsGrams: 145,
          proteinGrams: 70,
          fatGrams: 45,
          caloriesKcal: 1265,
        ),
        recipes: const [
          Recipe(
            name: 'Turmeric Ginger Fish Fillet',
            description:
                'Turmeric (curcumin) and ginger are clinically studied anti-inflammatory agents.',
            ingredients: ['White fish fillet', 'Turmeric', 'Ginger', 'Coconut milk', 'Calamansi'],
            prepTime: '25 min',
          ),
          Recipe(
            name: 'Pinakbet with Healthy Fats',
            description:
                'Traditional mixed vegetable dish with bagoong replaced by low-sodium shrimp paste — loaded with antioxidants.',
            ingredients: ['Squash', 'Ampalaya', 'Eggplant', 'Okra', 'Low-sodium bagoong'],
            prepTime: '30 min',
          ),
          Recipe(
            name: 'Berry & Walnut Oatmeal',
            description:
                'Walnuts contain ALA omega-3; berries have anthocyanins — both reduce joint inflammation.',
            ingredients: ['Rolled oats', 'Mixed berries', 'Walnuts (1 tbsp)', 'Honey (1 tsp)'],
            prepTime: '10 min',
          ),
        ],
      ),
    ],

    // ── Mental Health ─────────────────────────────────────────────────────────
    'mental_health': [
      MealPlan(
        id: 'mh_01',
        targetCondition: 'mental_health',
        name: 'Mood-Supporting Filipino Meals',
        macronutrients: const Macronutrients(
          carbsGrams: 165,
          proteinGrams: 75,
          fatGrams: 50,
          caloriesKcal: 1410,
        ),
        recipes: const [
          Recipe(
            name: 'Serotonin-Boosting Banana Oat Bowl',
            description:
                'Bananas provide tryptophan (serotonin precursor); oats sustain blood sugar stability.',
            ingredients: ['Rolled oats', 'Banana', 'Dark chocolate chips (½ tbsp)', 'Almond milk'],
            prepTime: '10 min',
          ),
          Recipe(
            name: 'Salmon Tinola',
            description:
                'Omega-3-rich salmon in tinola broth — DHA supports neurological and mood function.',
            ingredients: ['Salmon fillet', 'Green papaya', 'Malunggay', 'Ginger'],
            prepTime: '30 min',
          ),
          Recipe(
            name: 'Dark Leafy Salad with Calamansi Dressing',
            description:
                'Folate from leafy greens supports dopamine synthesis — critical for mood regulation.',
            ingredients: ['Mixed greens', 'Calamansi juice', 'Olive oil', 'Sesame seeds', 'Cucumber'],
            prepTime: '10 min',
          ),
        ],
      ),
    ],

    // ── General Wellness ──────────────────────────────────────────────────────
    'general': [
      MealPlan(
        id: 'gen_01',
        targetCondition: 'general',
        name: 'Balanced Filipino Wellness Plate',
        macronutrients: const Macronutrients(
          carbsGrams: 175,
          proteinGrams: 75,
          fatGrams: 50,
          caloriesKcal: 1450,
        ),
        recipes: const [
          Recipe(
            name: 'Mixed Vegetable Nilaga',
            description:
                'Traditional boiled stew rich in vitamins — a complete, nourishing Filipino comfort meal.',
            ingredients: ['Beef (lean)', 'Potatoes', 'Corn', 'Pechay', 'Onion'],
            prepTime: '45 min',
          ),
          Recipe(
            name: 'Grilled Chicken with Atchara',
            description:
                'Lean grilled protein paired with pickled papaya — probiotics support gut health.',
            ingredients: ['Chicken breast', 'Garlic marinade', 'Atchara (pickled papaya)', 'Calamansi'],
            prepTime: '30 min',
          ),
          Recipe(
            name: 'Buko Fruit Salad',
            description:
                'Fresh buko (young coconut) with mixed fruits — natural electrolytes and vitamin C.',
            ingredients: ['Young coconut (buko)', 'Papaya', 'Mango', 'Calamansi juice', 'Honey'],
            prepTime: '15 min',
          ),
        ],
      ),
    ],
  };

  static final _tips = <String, List<LifestyleTip>>{
    // ── Diabetes ──────────────────────────────────────────────────────────────
    'diabetes': const [
      LifestyleTip(
        id: 'dm_tip_1',
        category: 'Exercise',
        actionableAdvice:
            'Walk briskly for 10–15 minutes after each main meal. Post-meal movement is the single most effective way to lower post-prandial blood sugar without medication.',
      ),
      LifestyleTip(
        id: 'dm_tip_2',
        category: 'Nutrition',
        actionableAdvice:
            'Replace white rice with brown rice or use ¾ of your usual portion. Pair carbohydrates with protein or fat to slow glucose absorption — e.g., add a boiled egg to your meal.',
      ),
      LifestyleTip(
        id: 'dm_tip_3',
        category: 'Hydration',
        actionableAdvice:
            'Drink water instead of juice, softdrinks, or sweetened coffee. Even "natural" fruit juice spikes blood sugar rapidly. Aim for 8–10 glasses of plain water daily.',
      ),
      LifestyleTip(
        id: 'dm_tip_4',
        category: 'Sleep',
        actionableAdvice:
            'Maintain a consistent sleep schedule — same bedtime and wake-up time daily. Poor or irregular sleep directly impairs insulin sensitivity within 2–3 days.',
      ),
      LifestyleTip(
        id: 'dm_tip_5',
        category: 'Stress',
        actionableAdvice:
            'Practice 5 minutes of diaphragmatic breathing before meals. Cortisol (the stress hormone) raises blood glucose — managing stress is an underrated part of diabetes control.',
      ),
    ],

    // ── CKD ──────────────────────────────────────────────────────────────────
    'ckd': const [
      LifestyleTip(
        id: 'ckd_tip_1',
        category: 'Hydration',
        actionableAdvice:
            'Follow your nephrologist\'s prescribed fluid allowance — do not exceed it, even if thirsty. Overhydration stresses damaged kidneys as much as dehydration does.',
      ),
      LifestyleTip(
        id: 'ckd_tip_2',
        category: 'Nutrition',
        actionableAdvice:
            'Avoid high-potassium foods: bananas, tomatoes, oranges, and potatoes. Leach vegetables by peeling, cutting small, soaking in water for 2 hours, then boiling — discards 30–50% of potassium.',
      ),
      LifestyleTip(
        id: 'ckd_tip_3',
        category: 'Exercise',
        actionableAdvice:
            'Low-impact walking for 20–30 minutes, 4 days a week improves cardiovascular health without straining the kidneys. Avoid heavy resistance training until cleared by your doctor.',
      ),
      LifestyleTip(
        id: 'ckd_tip_4',
        category: 'Sleep',
        actionableAdvice:
            'Elevate your legs slightly using a pillow while sleeping. This reduces ankle swelling — a common symptom in CKD — by improving venous return.',
      ),
      LifestyleTip(
        id: 'ckd_tip_5',
        category: 'Stress',
        actionableAdvice:
            'High psychological stress accelerates CKD progression through elevated blood pressure. Consider joining a kidney patient support group or mindfulness program.',
      ),
    ],

    // ── Hypertension ─────────────────────────────────────────────────────────
    'hypertension': const [
      LifestyleTip(
        id: 'htn_tip_1',
        category: 'Nutrition',
        actionableAdvice:
            'Target less than 1,500 mg of sodium per day. One teaspoon of patis (fish sauce) contains ~1,200 mg of sodium — replace it with fresh calamansi, herbs, and garlic for flavour.',
      ),
      LifestyleTip(
        id: 'htn_tip_2',
        category: 'Exercise',
        actionableAdvice:
            'Brisk walking 30 minutes daily lowers systolic BP by 4–9 mmHg — comparable to a low-dose antihypertensive medication. Make it non-negotiable.',
      ),
      LifestyleTip(
        id: 'htn_tip_3',
        category: 'Stress',
        actionableAdvice:
            'Blood pressure spikes acutely during arguments and anxiety. Practise the 4-7-8 breathing technique: inhale 4 s, hold 7 s, exhale 8 s. Do this before stressful situations.',
      ),
      LifestyleTip(
        id: 'htn_tip_4',
        category: 'Sleep',
        actionableAdvice:
            'Sleep 7–8 hours nightly. Persistent sleep deprivation (< 6 hrs) raises systolic BP by 5–10 mmHg in clinical studies. Avoid caffeine after 2 PM.',
      ),
      LifestyleTip(
        id: 'htn_tip_5',
        category: 'Hydration',
        actionableAdvice:
            'Stay hydrated — dehydration thickens the blood and raises pressure. Limit alcohol to 1 drink per day for women and 2 for men (ideally none if BP is poorly controlled).',
      ),
    ],

    // ── Heart Disease ─────────────────────────────────────────────────────────
    'heart_disease': const [
      LifestyleTip(
        id: 'hd_tip_1',
        category: 'Exercise',
        actionableAdvice:
            'Aim for 30 minutes of moderate cardio (walking, light cycling) 5 days a week. Start at 10-minute intervals if exercise feels tiring. Never exercise through chest pain — stop immediately.',
      ),
      LifestyleTip(
        id: 'hd_tip_2',
        category: 'Nutrition',
        actionableAdvice:
            'Replace coconut oil and mantika with olive or canola oil. Limit red meat to twice weekly. Increase fatty fish (bangus, salmon, sardines) — 2 servings per week reduces cardiac mortality by 36%.',
      ),
      LifestyleTip(
        id: 'hd_tip_3',
        category: 'Stress',
        actionableAdvice:
            'Anger and acute emotional stress are documented triggers for cardiac events. Practice progressive muscle relaxation daily: tense then release each muscle group from feet to face.',
      ),
      LifestyleTip(
        id: 'hd_tip_4',
        category: 'Sleep',
        actionableAdvice:
            'Aim for 7–9 hours of quality sleep. Obstructive sleep apnoea (snoring + pauses) is a major hidden risk factor for heart disease — discuss screening with your cardiologist.',
      ),
      LifestyleTip(
        id: 'hd_tip_5',
        category: 'Hydration',
        actionableAdvice:
            'Limit caffeine to one cup of coffee daily. Caffeine transiently raises heart rate and BP — significant for patients on beta-blockers or with arrhythmia.',
      ),
    ],

    // ── Stroke ────────────────────────────────────────────────────────────────
    'stroke': const [
      LifestyleTip(
        id: 'str_tip_1',
        category: 'Exercise',
        actionableAdvice:
            'Short, structured rehabilitation exercises are more effective than rest. Even 5 minutes of range-of-motion exercises for the affected limb 3× daily supports neuroplasticity.',
      ),
      LifestyleTip(
        id: 'str_tip_2',
        category: 'Nutrition',
        actionableAdvice:
            'Soft or pureed foods reduce aspiration risk if swallowing is affected. Request a swallowing assessment (speech-language pathologist) before resuming solid foods.',
      ),
      LifestyleTip(
        id: 'str_tip_3',
        category: 'Sleep',
        actionableAdvice:
            'Sleep is when the brain consolidates motor relearning. Prioritise 8–9 hours — disrupted sleep after stroke slows recovery speed significantly.',
      ),
      LifestyleTip(
        id: 'str_tip_4',
        category: 'Stress',
        actionableAdvice:
            'Post-stroke depression affects 1 in 3 survivors and slows rehabilitation. Talk openly with your care team — treatment (counselling or medication) dramatically improves functional recovery.',
      ),
      LifestyleTip(
        id: 'str_tip_5',
        category: 'Hydration',
        actionableAdvice:
            'Dehydration increases blood viscosity and clotting risk — a significant second-stroke risk factor. Sip fluids consistently throughout the day, even if thirst is reduced.',
      ),
    ],

    // ── Cancer ────────────────────────────────────────────────────────────────
    'cancer': const [
      LifestyleTip(
        id: 'onc_tip_1',
        category: 'Nutrition',
        actionableAdvice:
            'Eat 5–6 small meals daily rather than 3 large ones — reduces nausea and maintains caloric intake during treatment. High protein (1.2–1.5 g/kg body weight) preserves muscle mass.',
      ),
      LifestyleTip(
        id: 'onc_tip_2',
        category: 'Sleep',
        actionableAdvice:
            'Rest is part of treatment. Cancer-related fatigue is physiologically different from tiredness — rest is not laziness. Protect 8–10 hours per night and allow daytime naps if needed.',
      ),
      LifestyleTip(
        id: 'onc_tip_3',
        category: 'Hydration',
        actionableAdvice:
            'Chemotherapy increases the risk of dehydration and kidney stress. Sip cool fluids (water, broth, coconut water) throughout the day — at least 8–10 glasses unless medically restricted.',
      ),
      LifestyleTip(
        id: 'onc_tip_4',
        category: 'Stress',
        actionableAdvice:
            'Evidence-based mind-body practices (guided imagery, journaling, music therapy) measurably reduce cortisol, improve quality of life, and may improve treatment outcomes.',
      ),
      LifestyleTip(
        id: 'onc_tip_5',
        category: 'Exercise',
        actionableAdvice:
            'Gentle yoga or supervised walking during treatment reduces fatigue by up to 40% and improves mood. Begin with 10 minutes and adjust based on energy levels each day.',
      ),
    ],

    // ── Asthma ────────────────────────────────────────────────────────────────
    'asthma': const [
      LifestyleTip(
        id: 'ast_tip_1',
        category: 'Exercise',
        actionableAdvice:
            'Swimming is the best exercise for asthma — warm, humidified air minimises bronchospasm. Walking in a cool, dry environment also works. Always carry your reliever inhaler.',
      ),
      LifestyleTip(
        id: 'ast_tip_2',
        category: 'Nutrition',
        actionableAdvice:
            'Vitamin D deficiency is linked to increased asthma severity. Include eggs, fortified milk, and small amounts of sun exposure. Avoid preservatives (sulfites) found in dried fruits and processed meats.',
      ),
      LifestyleTip(
        id: 'ast_tip_3',
        category: 'Hydration',
        actionableAdvice:
            'Drink warm fluids — warm water, ginger tea, or warm broth — to help keep airways moist and reduce mucus viscosity. Avoid cold drinks which can trigger bronchospasm.',
      ),
      LifestyleTip(
        id: 'ast_tip_4',
        category: 'Stress',
        actionableAdvice:
            'Emotional stress is a documented asthma trigger. Diaphragmatic breathing exercises (belly breathing, not chest breathing) strengthen respiratory muscles and reduce anxiety-induced attacks.',
      ),
      LifestyleTip(
        id: 'ast_tip_5',
        category: 'Sleep',
        actionableAdvice:
            'Asthma is often worse at night (nocturnal asthma). Elevate the head of your bed by 15–20 cm and keep the bedroom free of dust, mould, and pet dander.',
      ),
    ],

    // ── Tuberculosis ──────────────────────────────────────────────────────────
    'tuberculosis': const [
      LifestyleTip(
        id: 'tb_tip_1',
        category: 'Nutrition',
        actionableAdvice:
            'Never skip meals during TB treatment — adequate nutrition is as important as medication adherence. High-protein meals (eggs, fish, legumes) rebuild the lung tissue damaged by infection.',
      ),
      LifestyleTip(
        id: 'tb_tip_2',
        category: 'Exercise',
        actionableAdvice:
            'Short, daily outdoor walks in fresh air support lung recovery. Avoid intense exercise until you are past the infectious phase — your doctor will advise when this is safe.',
      ),
      LifestyleTip(
        id: 'tb_tip_3',
        category: 'Sleep',
        actionableAdvice:
            'Night sweats disturb sleep and accelerate weight loss — both worsen prognosis. Use light, breathable bedding and keep the room ventilated. Report persistent night sweats to your care team.',
      ),
      LifestyleTip(
        id: 'tb_tip_4',
        category: 'Hydration',
        actionableAdvice:
            'Some TB medications (rifampicin) stress the liver. Staying well-hydrated helps flush metabolites. Avoid alcohol entirely during treatment — it dramatically increases drug toxicity risk.',
      ),
      LifestyleTip(
        id: 'tb_tip_5',
        category: 'Stress',
        actionableAdvice:
            'TB carries social stigma that causes isolation and depression. Connecting with a TB support group or counsellor improves medication adherence and outcomes significantly.',
      ),
    ],

    // ── Arthritis ─────────────────────────────────────────────────────────────
    'arthritis': const [
      LifestyleTip(
        id: 'art_tip_1',
        category: 'Exercise',
        actionableAdvice:
            'Water aerobics and swimming reduce joint load while building muscle. Strengthening the muscles around painful joints — not resting them — is the evidence-based approach for long-term relief.',
      ),
      LifestyleTip(
        id: 'art_tip_2',
        category: 'Nutrition',
        actionableAdvice:
            'Add ½ teaspoon of turmeric to daily cooking. Curcumin has clinical anti-inflammatory evidence comparable to low-dose NSAIDs — without gastrointestinal side effects.',
      ),
      LifestyleTip(
        id: 'art_tip_3',
        category: 'Sleep',
        actionableAdvice:
            'Apply a warm compress to stiff joints for 15 minutes before getting out of bed each morning. It reduces morning stiffness duration and makes movement easier from the start of the day.',
      ),
      LifestyleTip(
        id: 'art_tip_4',
        category: 'Stress',
        actionableAdvice:
            'Psychological stress elevates inflammatory cytokines, which directly worsen arthritis flare-ups. Identifying and reducing daily stress triggers is a modifiable disease-management strategy.',
      ),
      LifestyleTip(
        id: 'art_tip_5',
        category: 'Hydration',
        actionableAdvice:
            'Joint cartilage is 75% water. Adequate hydration (8–10 glasses) directly maintains cartilage lubrication. Avoid excess caffeine and alcohol — both increase inflammatory markers.',
      ),
    ],

    // ── Mental Health ─────────────────────────────────────────────────────────
    'mental_health': const [
      LifestyleTip(
        id: 'mh_tip_1',
        category: 'Sleep',
        actionableAdvice:
            'A consistent sleep-wake cycle is one of the most powerful mood stabilisers. Set a fixed alarm — even on weekends. Sleep deprivation mimics and worsens clinical depression and anxiety.',
      ),
      LifestyleTip(
        id: 'mh_tip_2',
        category: 'Exercise',
        actionableAdvice:
            '30 minutes of aerobic exercise 3× per week is as effective as antidepressants for mild-to-moderate depression in multiple RCTs. The effect builds over 3–4 weeks — consistency matters.',
      ),
      LifestyleTip(
        id: 'mh_tip_3',
        category: 'Nutrition',
        actionableAdvice:
            '95% of serotonin is produced in the gut. Eating fermented foods (yoghurt, kimchi, miso) and fibre-rich vegetables supports the gut-brain axis and improves mood over time.',
      ),
      LifestyleTip(
        id: 'mh_tip_4',
        category: 'Stress',
        actionableAdvice:
            'Limit social media to 30 minutes daily — research shows a dose-response relationship between social media use and depression severity. Schedule specific check-in times rather than continuous scrolling.',
      ),
      LifestyleTip(
        id: 'mh_tip_5',
        category: 'Hydration',
        actionableAdvice:
            'Even mild dehydration (1–2%) impairs mood, concentration, and increases perceived anxiety. Keep a water bottle visible as a visual reminder to drink throughout the day.',
      ),
    ],

    // ── General Wellness ──────────────────────────────────────────────────────
    'general': const [
      LifestyleTip(
        id: 'gen_tip_1',
        category: 'Exercise',
        actionableAdvice:
            'Aim for 150 minutes of moderate-intensity activity per week — 30 minutes, 5 days. Walking after dinner is one of the simplest, most evidence-backed longevity habits.',
      ),
      LifestyleTip(
        id: 'gen_tip_2',
        category: 'Nutrition',
        actionableAdvice:
            'Fill half your plate with vegetables at every meal. A variety of colours ensures broad micronutrient coverage — think green (kangkong), orange (carrots), and red (tomatoes) daily.',
      ),
      LifestyleTip(
        id: 'gen_tip_3',
        category: 'Hydration',
        actionableAdvice:
            'Drink 8 glasses of water daily. Start your morning with a glass before coffee. Proper hydration improves kidney function, skin health, and concentration — all in one habit.',
      ),
      LifestyleTip(
        id: 'gen_tip_4',
        category: 'Sleep',
        actionableAdvice:
            'Adults need 7–9 hours of sleep. Sleep is when cellular repair, memory consolidation, and immune calibration occur. Treat it as a health priority, not a luxury.',
      ),
      LifestyleTip(
        id: 'gen_tip_5',
        category: 'Stress',
        actionableAdvice:
            'Schedule one dedicated relaxation activity daily — even 10 minutes. Reading, prayer, music, or a slow walk all activate the parasympathetic nervous system and reduce cortisol.',
      ),
    ],
  };
}
