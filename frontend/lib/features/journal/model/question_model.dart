
class QuestionOption {
  final String value;
  final String label;

  const QuestionOption({required this.value, required this.label});

  factory QuestionOption.fromJson(Map<String, dynamic> json) => QuestionOption(
    value: json['value'] as String,
    label: json['label'] as String,
  );
}

class ValidationRule {
  final double? min;
  final double? max;
  final double? step;
  final String? unit;

  const ValidationRule({this.min, this.max, this.step, this.unit});

  factory ValidationRule.fromJson(Map<String, dynamic> json) => ValidationRule(
    min: (json['min'] as num?)?.toDouble(),
    max: (json['max'] as num?)?.toDouble(),
    step: (json['step'] as num?)?.toDouble(),
    unit: json['unit'] as String?,
  );
}

class GateConfig {
  final String triggerValue;
  final List<String> reveals;

  const GateConfig({required this.triggerValue, required this.reveals});

  factory GateConfig.fromJson(Map<String, dynamic> json) => GateConfig(
    triggerValue: json['trigger_value'] as String,
    reveals: List<String>.from(json['reveals'] as List),
  );
}

class Question {
  final String id;
  final String label;
  final String uiComponent;
  final bool isRequired;
  final String? hintText;
  final List<QuestionOption>? options;
  final ValidationRule? validation;
  final GateConfig? gate;
  final String? parentGateId;
  final String? gateTriggerValue;

  const Question({
    required this.id,
    required this.label,
    required this.uiComponent,
    required this.isRequired,
    this.hintText,
    this.options,
    this.validation,
    this.gate,
    this.parentGateId,
    this.gateTriggerValue,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'] as String,
    label: json['label'] as String,
    uiComponent: json['ui_component'] as String,
    isRequired: json['is_required'] as bool? ?? true,
    hintText: json['hint_text'] as String?,
    options: (json['options'] as List<dynamic>?)
        ?.map((e) => QuestionOption.fromJson(e as Map<String, dynamic>))
        .toList(),
    validation: json['validation'] != null
        ? ValidationRule.fromJson(json['validation'] as Map<String, dynamic>)
        : null,
    gate: json['gate'] != null
        ? GateConfig.fromJson(json['gate'] as Map<String, dynamic>)
        : null,
    parentGateId: json['parent_gate_id'] as String?,
    gateTriggerValue: json['gate_trigger_value'] as String?,
  );
}

class JournalQuestionsResponse {
  final String questionSetType;
  final String illnessType;
  final List<Question> questions;
  final String version;

  const JournalQuestionsResponse({
    required this.questionSetType,
    required this.illnessType,
    required this.questions,
    required this.version,
  });

  factory JournalQuestionsResponse.fromJson(Map<String, dynamic> json) =>
      JournalQuestionsResponse(
        questionSetType: json['question_set_type'] as String? ?? 'daily',
        illnessType: json['illness_type'] as String? ?? '',
        questions: (json['questions'] as List<dynamic>)
            .map((e) => Question.fromJson(e as Map<String, dynamic>))
            .toList(),
        version: json['version'] as String? ?? '1.0.0',
      );
}