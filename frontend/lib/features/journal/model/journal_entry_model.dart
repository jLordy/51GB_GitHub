/// Mirror of the backend JournalEntryResponse Pydantic model.
/// One document in the Firestore journal_entries collection.
class JournalEntryModel {
  const JournalEntryModel({
    required this.entryId,
    required this.userUid,
    required this.questionSetType,
    required this.illnessType,
    required this.answers,
    required this.submittedAt,
    this.updatedAt,
    this.editCount = 0,
  });

  final String entryId;
  final String userUid;
  final String questionSetType;
  final String illnessType;
  final Map<String, dynamic> answers;
  final DateTime submittedAt;
  final DateTime? updatedAt;
  final int editCount;

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryModel(
      entryId: json['entry_id'] as String,
      userUid: json['user_uid'] as String,
      questionSetType: json['question_set_type'] as String? ?? 'daily',
      illnessType: json['illness_type'] as String? ?? '',
      answers:
          (json['answers'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      submittedAt: DateTime.parse(json['submitted_at'] as String).toLocal(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
      editCount: (json['edit_count'] as int?) ?? 0,
    );
  }

  // ── Derived display helpers ─────────────────────────────────────────────

  /// Short illness type display name (English).
  String get illnessDisplayName {
    switch (illnessType.toLowerCase()) {
      case 'ckd':
        return 'Kidney Health';
      case 'diabetes':
        return 'Diabetes Check';
      case 'oncology':
        return 'Oncology Log';
      default:
        return illnessType.isEmpty ? 'Daily Log' : illnessType;
    }
  }

  /// Build a readable plain-text preview of the answers for the card body.
  /// Shows up to [maxLines] key-value pairs, formatted from snake_case keys.
  String buildPreview({int maxLines = 10}) {
    if (answers.isEmpty) {
      return 'No answer data recorded for this entry.';
    }
    final buffer = StringBuffer();
    int count = 0;
    for (final MapEntry<String, dynamic> e in answers.entries) {
      if (count >= maxLines) break;
      final String label = e.key
          .replaceAll('_', ' ')
          .split(' ')
          .map(
            (String w) =>
                w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}',
          )
          .join(' ');
      final String value = _formatValue(e.value);
      buffer.writeln('$label: $value');
      count++;
    }
    return buffer.toString().trim();
  }

  static String _formatValue(dynamic v) {
    if (v == null) return '—';
    if (v is Map) {
      // e.g., {"systolic": 120, "diastolic": 80}
      return v.entries
          .map((MapEntry<dynamic, dynamic> e) => '${e.key} ${e.value}')
          .join(' / ');
    }
    if (v is List) {
      return v.map((dynamic x) => _humanise(x.toString())).join(', ');
    }
    return _humanise(v.toString());
  }

  /// Converts a snake_case or underscore-separated string into a readable
  /// sentence-case string (e.g., "shortness_of_breath" → "Shortness of breath").
  static String _humanise(String raw) {
    final words = raw.replaceAll('_', ' ').trim().split(' ');
    if (words.isEmpty) return raw;
    return words.first.isEmpty
        ? raw
        : '${words.first[0].toUpperCase()}${words.first.substring(1)}'
              '${words.length > 1 ? ' ${words.skip(1).join(' ')}' : ''}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntryModel && other.entryId == entryId;

  @override
  int get hashCode => entryId.hashCode;

  @override
  String toString() =>
      'JournalEntryModel(entryId: $entryId, illnessType: $illnessType, submittedAt: $submittedAt)';
}

// ── Edit history ───────────────────────────────────────────────────────────────

/// A single snapshot of a journal entry's answers taken immediately before an
/// edit was saved. Mirrors [EditHistoryEntry] on the backend.
class EditHistoryEntry {
  const EditHistoryEntry({
    required this.editNumber,
    required this.editedAt,
    required this.previousAnswers,
    this.editedByUid,
    this.editedByName,
  });

  /// 1-based counter — the Nth edit applied to the parent entry.
  final int editNumber;

  /// UTC timestamp when the edit was committed (converted to local for display).
  final DateTime editedAt;

  /// A copy of the entry's `answers` map as it existed *before* this edit.
  final Map<String, dynamic> previousAnswers;

  /// UID of the user who made this edit.
  final String? editedByUid;

  /// Display name of the user who made this edit.
  final String? editedByName;

  factory EditHistoryEntry.fromJson(Map<String, dynamic> json) {
    return EditHistoryEntry(
      editNumber: (json['edit_number'] as int?) ?? 0,
      editedAt: DateTime.parse(json['edited_at'] as String).toLocal(),
      previousAnswers:
          (json['previous_answers'] as Map<String, dynamic>?) ??
          <String, dynamic>{},
      editedByUid: json['edited_by_uid'] as String?,
      editedByName: json['editor_name'] as String?,
    );
  }

  @override
  String toString() =>
      'EditHistoryEntry(editNumber: $editNumber, editedAt: $editedAt, editedByName: $editedByName)';
}