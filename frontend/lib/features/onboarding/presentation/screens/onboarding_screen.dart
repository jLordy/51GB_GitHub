import 'package:frontend/features/onboarding/data/onboarding_repository.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/onboarding/presentation/widgets/onboarding_nav_bar.dart';
import 'package:frontend/features/onboarding/presentation/widgets/onboarding_progress_bar.dart';
import 'package:frontend/features/onboarding/presentation/widgets/steps/allergies_step.dart';
import 'package:frontend/features/onboarding/presentation/widgets/steps/biological_sex_step.dart';
import 'package:frontend/features/onboarding/presentation/widgets/steps/date_of_birth_step.dart';
import 'package:frontend/features/onboarding/presentation/widgets/steps/ethnicity_step.dart';
import 'package:frontend/features/onboarding/presentation/widgets/steps/family_history_step.dart';
import 'package:frontend/features/onboarding/presentation/widgets/steps/full_name_step.dart';
import 'package:frontend/features/onboarding/presentation/widgets/steps/illness_type_step.dart';
import 'package:frontend/features/onboarding/presentation/widgets/steps/lifestyle_step.dart';
import 'package:frontend/features/onboarding/presentation/widgets/steps/social_step.dart';
import 'package:frontend/theme/palette.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _Step {
  illnessType,
  dateOfBirth,
  fullName,
  biologicalSex,
  ethnicity,
  allergies,
  lifestyle,
  socialDeterminants,
  familyHistory,
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.illnessType;

  // Basic profile
  final List<String> _illnessTypes = [];
  final _illnessOtherCtrl = TextEditingController();
  DateTime? _dob;
  final _nameCtrl = TextEditingController();

  // Demographics
  String? _biologicalSex;
  String? _ethnicity;

  // Tobacco and alcohol use
  double _tobaccoPackYears = 0;
  double _alcoholWeekly = 0;

  // Allergies
  bool? _hasAllergies;
  final List<String> _allergyMedications = [];
  final List<String> _allergyFood = [];
  final List<String> _allergyEnvironmental = [];
  final _allergyMedCtrl = TextEditingController();
  final _allergyFoodCtrl = TextEditingController();
  final _allergyEnvCtrl = TextEditingController();

  // SDOH
  String? _livingSituation;
  String? _supportSystemStrength;

  // Family history
  bool? _hasFamilyHistory;
  final List<String> _familyConditions = [];

  bool _submitting = false;
  String? _errorMsg;

  bool get _canNext => switch (_step) {
    _Step.illnessType =>
      _illnessTypes.isNotEmpty || _illnessOtherCtrl.text.trim().isNotEmpty,
    _Step.dateOfBirth => _dob != null,
    _Step.fullName => _nameCtrl.text.trim().isNotEmpty,
    _Step.biologicalSex => _biologicalSex != null,
    _Step.ethnicity => _ethnicity != null,
    _Step.allergies =>
      _hasAllergies != null &&
          (!_hasAllergies! ||
              (_allergyMedications.isNotEmpty ||
                  _allergyFood.isNotEmpty ||
                  _allergyEnvironmental.isNotEmpty)),
    _Step.lifestyle => true,
    _Step.socialDeterminants =>
      _livingSituation != null && _supportSystemStrength != null,
    _Step.familyHistory =>
      _hasFamilyHistory != null &&
          (!_hasFamilyHistory! || _familyConditions.isNotEmpty),
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _illnessOtherCtrl.dispose();
    _allergyMedCtrl.dispose();
    _allergyFoodCtrl.dispose();
    _allergyEnvCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      if (_step.index < _Step.values.length - 1) {
        _step = _Step.values[_step.index + 1];
      }
    });
  }

  void _prevStep() {
    setState(() {
      if (_step.index > 0) {
        _step = _Step.values[_step.index - 1];
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorMsg = null;
    });
    try {
      await ref
          .read(onboardingRepositoryProvider)
          .selfRegister(
            fullName: _nameCtrl.text.trim(),
            dateOfBirth: _dob!,
            illnessTypes: List.unmodifiable(_illnessTypes),
            illnessOther: _illnessOtherCtrl.text.trim().isEmpty
                ? null
                : _illnessOtherCtrl.text.trim(),
            biologicalSex: _biologicalSex!,
            ethnicity: _ethnicity!,
            hasAllergies: _hasAllergies!,
            allergyMedications: List.unmodifiable(_allergyMedications),
            allergyFood: List.unmodifiable(_allergyFood),
            allergyEnvironmental: List.unmodifiable(_allergyEnvironmental),
            tobaccoPackYears: _tobaccoPackYears,
            alcoholWeeklyFrequency: _alcoholWeekly,
            livingSituation: _livingSituation!,
            supportSystemStrength: _supportSystemStrength!,
            hasFamilyHistory: _hasFamilyHistory!,
            familyConditions: List.unmodifiable(_familyConditions),
          );
      if (mounted) {
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          ref.read(currentUserProvider.notifier).state = UserModel(
            uid: currentUser.uid,
            email: currentUser.email,
            role: currentUser.role,
            status: 'active',
            displayName: currentUser.displayName,
            photoUrl: currentUser.photoUrl,
          );
        }
        context.go('/journal');
      }
    } catch (e) {
      String msg = 'Could not save your profile. Please try again.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        }
      }
      setState(() {
        _submitting = false;
        _errorMsg = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = ref.watch(themeNotifierProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: OnboardingNavBar(
        canNext: _canNext,
        isFirst: _step == _Step.illnessType,
        isLast: _step == _Step.familyHistory,
        submitting: _submitting,
        onBack: _prevStep,
        onNext: _nextStep,
        onSubmit: _submit,
      ),
      body: SafeArea(
        child: Column(
          children: [
            OnboardingProgressBar(
              currentStep: _step.index + 1,
              totalSteps: _Step.values.length,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: _buildCurrentStep(),
              ),
            ),
            if (_errorMsg != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 4,
                ),
                child: Text(
                  _errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() => switch (_step) {
    _Step.illnessType => IllnessTypeStep(
      selected: _illnessTypes,
      onChanged: (v) => setState(() {
        if (v == 'none') {
          _illnessTypes
            ..clear()
            ..add('none');
        } else {
          _illnessTypes.remove('none');
          if (_illnessTypes.contains(v)) {
            _illnessTypes.remove(v);
          } else {
            _illnessTypes.add(v);
          }
        }
      }),
      otherController: _illnessOtherCtrl,
      onOtherChanged: () => setState(() {}),
    ),
    _Step.dateOfBirth => DateOfBirthStep(
      dob: _dob,
      onChanged: (v) => setState(() => _dob = v),
    ),
    _Step.fullName => FullNameStep(
      controller: _nameCtrl,
      onChanged: () => setState(() => _errorMsg = null),
    ),
    _Step.biologicalSex => BiologicalSexStep(
      selected: _biologicalSex,
      onChanged: (v) => setState(() => _biologicalSex = v),
    ),
    _Step.ethnicity => EthnicityStep(
      selected: _ethnicity,
      onChanged: (v) => setState(() => _ethnicity = v),
    ),
    _Step.allergies => AllergiesStep(
      hasAllergies: _hasAllergies,
      onHasAllergiesChanged: (v) => setState(() => _hasAllergies = v),
      allergyMedications: _allergyMedications,
      allergyFood: _allergyFood,
      allergyEnvironmental: _allergyEnvironmental,
      medController: _allergyMedCtrl,
      foodController: _allergyFoodCtrl,
      envController: _allergyEnvCtrl,
      onAddMed: (v) => setState(() => _allergyMedications.add(v)),
      onRemoveMed: (i) => setState(() => _allergyMedications.removeAt(i)),
      onAddFood: (v) => setState(() => _allergyFood.add(v)),
      onRemoveFood: (i) => setState(() => _allergyFood.removeAt(i)),
      onAddEnv: (v) => setState(() => _allergyEnvironmental.add(v)),
      onRemoveEnv: (i) => setState(() => _allergyEnvironmental.removeAt(i)),
    ),
    _Step.lifestyle => LifestyleStep(
      tobaccoPackYears: _tobaccoPackYears,
      alcoholWeekly: _alcoholWeekly,
      onTobaccoChanged: (v) => setState(() => _tobaccoPackYears = v),
      onAlcoholChanged: (v) => setState(() => _alcoholWeekly = v),
    ),
    _Step.socialDeterminants => SocialStep(
      livingSituation: _livingSituation,
      supportSystemStrength: _supportSystemStrength,
      onLivingChanged: (v) => setState(() => _livingSituation = v),
      onSupportChanged: (v) => setState(() => _supportSystemStrength = v),
    ),
    _Step.familyHistory => FamilyHistoryStep(
      hasFamilyHistory: _hasFamilyHistory,
      onHasFamilyHistoryChanged: (v) => setState(() {
        _hasFamilyHistory = v;
        if (!v) _familyConditions.clear();
      }),
      familyConditions: _familyConditions,
      onConditionToggled: (key) => setState(() {
        if (_familyConditions.contains(key)) {
          _familyConditions.remove(key);
        } else {
          _familyConditions.add(key);
        }
      }),
    ),
  };
}
