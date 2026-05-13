/// Mirror of the backend FileFolderResponse Pydantic model.
class FileFolderModel {
  const FileFolderModel({
    required this.id,
    required this.patientUid,
    required this.name,
    required this.isDefault,
    required this.itemCount,
    required this.createdAt,
  });

  final String id;
  final String patientUid;
  final String name;
  final bool isDefault;
  final int itemCount;
  final DateTime createdAt;

  factory FileFolderModel.fromJson(Map<String, dynamic> json) {
    return FileFolderModel(
      id: json['id'] as String,
      patientUid: json['patient_uid'] as String,
      name: json['name'] as String,
      isDefault: json['is_default'] as bool? ?? false,
      itemCount: json['item_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
