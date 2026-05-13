/// Mirror of the backend StorageSummaryResponse Pydantic model.
class StorageSummaryModel {
  const StorageSummaryModel({
    required this.patientUid,
    required this.totalBytes,
    required this.maxBytes,
    required this.fileCount,
    required this.usagePercentage,
  });

  final String patientUid;
  final int totalBytes;
  final int maxBytes;
  final int fileCount;
  final double usagePercentage;

  factory StorageSummaryModel.fromJson(Map<String, dynamic> json) {
    return StorageSummaryModel(
      patientUid: json['patient_uid'] as String,
      totalBytes: json['total_bytes'] as int? ?? 0,
      maxBytes: json['max_bytes'] as int? ?? 524288000,
      fileCount: json['file_count'] as int? ?? 0,
      usagePercentage: (json['usage_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Human-readable used / total (e.g. "12.4 MB / 500 MB").
  String get usageLabel {
    final usedMb = totalBytes / (1024 * 1024);
    final maxMb = maxBytes / (1024 * 1024);
    return '${usedMb.toStringAsFixed(1)} MB / ${maxMb.toStringAsFixed(0)} MB';
  }
}
