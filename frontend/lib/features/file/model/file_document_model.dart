/// Mirror of the backend FileDocumentResponse Pydantic model.
class FileDocumentModel {
  const FileDocumentModel({
    required this.id,
    required this.patientUid,
    required this.folderId,
    required this.name,
    required this.fileUrl,
    required this.fileType,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedByUid,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String patientUid;
  final String folderId;
  final String name;
  final String fileUrl;
  final String fileType; // "image" | "pdf" | "document"
  final String mimeType;
  final int sizeBytes;
  final String uploadedByUid;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FileDocumentModel.fromJson(Map<String, dynamic> json) {
    return FileDocumentModel(
      id: json['id'] as String,
      patientUid: json['patient_uid'] as String,
      folderId: json['folder_id'] as String,
      name: json['name'] as String,
      fileUrl: json['file_url'] as String,
      fileType: json['file_type'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: json['size_bytes'] as int? ?? 0,
      uploadedByUid: json['uploaded_by_uid'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  bool get isImage => fileType == 'image';
  bool get isPdf => fileType == 'pdf';
  bool get isDocument => fileType == 'document';

  /// Human-readable file size (KB or MB).
  String get formattedSize {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
