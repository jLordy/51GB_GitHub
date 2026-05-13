/// Mirror of the backend ReportResponse Pydantic model.
/// One document in the Firestore reports collection.
class ReportModel {
  const ReportModel({
    required this.reportId,
    required this.patientUid,
    required this.generatedByUid,
    required this.generatedByRole,
    required this.startDate,
    required this.endDate,
    required this.period,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.editCount = 0,
  });

  final String reportId;
  final String patientUid;
  final String generatedByUid;
  final String generatedByRole;
  final DateTime startDate;
  final DateTime endDate;
  final String period;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int editCount;

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    return ReportModel(
      reportId: json['report_id'] as String,
      patientUid: json['patient_uid'] as String,
      generatedByUid: json['generated_by_uid'] as String,
      generatedByRole: json['generated_by_role'] as String,
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      period: (json['period'] as String?) ?? 'custom',
      content: (json['content'] as String?) ?? '',
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      editCount: (json['edit_count'] as int?) ?? 0,
    );
  }

  ReportModel copyWith({String? content}) {
    return ReportModel(
      reportId: reportId,
      patientUid: patientUid,
      generatedByUid: generatedByUid,
      generatedByRole: generatedByRole,
      startDate: startDate,
      endDate: endDate,
      period: period,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      editCount: editCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportModel && other.reportId == reportId;

  @override
  int get hashCode => reportId.hashCode;
}
