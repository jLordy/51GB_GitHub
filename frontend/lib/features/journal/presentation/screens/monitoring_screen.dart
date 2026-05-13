import 'package:frontend/features/journal/controller/journal_controller.dart';
import 'package:frontend/features/journal/data/journal_repository.dart';
import 'package:frontend/features/journal/model/journal_entry_model.dart';
import 'package:frontend/features/journal/model/question_model.dart';
import 'package:frontend/features/journal/presentation/widgets/monitoring_intro_page.dart';
import 'package:frontend/features/journal/presentation/widgets/monitoring_no_profile_page.dart';
import 'package:frontend/features/journal/presentation/widgets/monitoring_question_page.dart';
import 'package:frontend/features/journal/presentation/widgets/monitoring_summary_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _Phase { intro, loading, question, summary, submitting, noProfile }

class MonitoringScreen extends ConsumerStatefulWidget {
  const MonitoringScreen({
    super.key,
    this.existingEntry,
    this.patientUid,
    this.patientName,
    this.readOnly = false,
  });

  /// When non-null the screen opens directly in view/edit mode for this entry.
  final JournalEntryModel? existingEntry;

  /// When non-null the screen operates in caregiver mode — questions and
  /// submissions target the patient identified by this uid rather than the
  /// current user.
  final String? patientUid;

  /// Display name of the patient (caregiver mode). Passed to the intro page to
  /// show 2nd-person text like "Tell us how [name] is feeling right now."
  final String? patientName;

  /// When true the summary is shown in view-only mode: no submit button,
  /// no edit icons on questions, and the notes field is non-editable.
  final bool readOnly;

  @override
  ConsumerState<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends ConsumerState<MonitoringScreen> {
  _Phase _phase = _Phase.intro;
  List<Question> _questions = [];
  int _currentIndex = 0;
  bool _backToSummary = false;
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _textControllers = {};
  final TextEditingController _notesCtrl = TextEditingController();
  String? _errorMsg;

  // Edit history (only populated when viewing/editing an existing entry)
  List<EditHistoryEntry> _editHistory = [];
  bool _historyLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startEdit());
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  TextEditingController _ctrl(String key, {String seed = ''}) =>
      _textControllers.putIfAbsent(
        key,
        () => TextEditingController(text: seed),
      );

  bool _matchesGateTrigger(dynamic parentAnswer, String? triggerValue) {
    if (triggerValue == null) return false;
    if (parentAnswer is List) {
      return parentAnswer.map((e) => e.toString()).contains(triggerValue);
    }
    return parentAnswer?.toString() == triggerValue;
  }

  List<Question> _visibleQuestions() {
    final byId = {for (final q in _questions) q.id: q};
    final visibilityCache = <String, bool>{};

    bool isVisible(Question q) {
      final cached = visibilityCache[q.id];
      if (cached != null) return cached;
      if (q.parentGateId == null) {
        visibilityCache[q.id] = true;
        return true;
      }

      final parent = byId[q.parentGateId!];
      if (parent == null || !isVisible(parent)) {
        visibilityCache[q.id] = false;
        return false;
      }

      final parentAnswer = _answers[q.parentGateId!];
      final visible = _matchesGateTrigger(parentAnswer, q.gateTriggerValue);
      visibilityCache[q.id] = visible;
      return visible;
    }

    return _questions.where(isVisible).toList();
  }

  void _clampCurrentIndexToVisible() {
    final visible = _visibleQuestions();
    if (visible.isEmpty) {
      _currentIndex = 0;
      return;
    }
    if (_currentIndex >= visible.length) {
      _currentIndex = visible.length - 1;
    }
    if (_currentIndex < 0) {
      _currentIndex = 0;
    }
  }

  void _onAnswerChanged(String key, dynamic value) {
    setState(() {
      _answers[key] = value;
      _clampCurrentIndexToVisible();
    });
  }

  void _onSummaryBack() {
    if (widget.existingEntry != null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _phase = _Phase.question;
        _currentIndex = _questions.length - 1;
      });
    }
  }

  // â”€â”€ State transitions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Opens the screen directly in summary (view/edit) mode for an existing entry.
  Future<void> _startEdit() async {
    setState(() {
      _phase = _Phase.loading;
      _errorMsg = null;
    });
    try {
      final repo = ref.read(journalRepositoryProvider);
      final resp = widget.patientUid != null
          ? await repo.fetchPatientQuestions(widget.patientUid!)
          : await repo.fetchQuestions();
      final entry = widget.existingEntry!;

      // Pre-fill all saved answers into the mutable map.
      _answers.addAll(Map<String, dynamic>.from(entry.answers));

      // Pull additional_notes out of the answers map into its own controller.
      final notes = entry.answers['additional_notes'];
      if (notes != null) {
        _notesCtrl.text = notes.toString();
        _answers.remove('additional_notes');
      }

      setState(() {
        _questions = resp.questions;
        _currentIndex = 0;
        _phase = _Phase.summary;
      });

      // Load edit history in the background â€” non-blocking
      _loadEditHistory(entry.entryId);
    } catch (e) {
      String msg = 'Could not load entry. Please try again.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        }
      }
      setState(() {
        _phase = _Phase.intro;
        _errorMsg = msg;
      });
    }
  }

  Future<void> _loadEditHistory(String entryId) async {
    if (!mounted) return;
    setState(() => _historyLoading = true);
    try {
      final repo = ref.read(journalRepositoryProvider);
      final history = widget.patientUid != null
          ? await repo.getPatientEntryHistory(widget.patientUid!, entryId)
          : await repo.fetchEntryHistory(entryId);
      if (mounted) setState(() => _editHistory = history);
    } catch (_) {
      // silently ignore â€” history is a non-critical enhancement
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _start() async {
    setState(() {
      _phase = _Phase.loading;
      _errorMsg = null;
    });
    try {
      final repo = ref.read(journalRepositoryProvider);
      final resp = widget.patientUid != null
          ? await repo.fetchPatientQuestions(widget.patientUid!)
          : await repo.fetchQuestions();
      setState(() {
        _questions = resp.questions;
        _currentIndex = 0;
        _phase = _Phase.question;
      });
    } catch (e) {
      String msg = 'Could not load questions. Please try again.';
      bool isNoProfile = false;
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        } else if (e.response?.statusCode != null) {
          msg = 'Server error ${e.response!.statusCode}. Please try again.';
        }
        final lowerMsg = msg.toLowerCase();
        if (lowerMsg.contains('patient profile not found') ||
            lowerMsg.contains('complete onboarding')) {
          isNoProfile = true;
        }
      }
      setState(() {
        _phase = isNoProfile ? _Phase.noProfile : _Phase.intro;
        _errorMsg = isNoProfile ? null : msg;
      });
    }
  }

  void _next() {
    final visible = _visibleQuestions();

    if (_backToSummary) {
      setState(() {
        _backToSummary = false;
        _phase = _Phase.summary;
      });
      return;
    }

    if (_currentIndex < visible.length - 1) {
      setState(() => _currentIndex++);
    } else {
      setState(() => _phase = _Phase.summary);
    }
  }

  void _prev() {
    final visible = _visibleQuestions();

    if (_backToSummary) {
      setState(() {
        _backToSummary = false;
        _phase = _Phase.summary;
      });
      return;
    }

    if (visible.isEmpty) {
      setState(() => _phase = _Phase.intro);
      return;
    }

    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    } else {
      setState(() => _phase = _Phase.intro);
    }
  }

  void _editFromSummary(int index) {
    setState(() {
      _backToSummary = true;
      _currentIndex = index;
      _phase = _Phase.question;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _phase = _Phase.submitting;
      _errorMsg = null;
    });
    try {
      final notesText = _notesCtrl.text.trim();
      if (notesText.isNotEmpty) {
        _answers['additional_notes'] = notesText;
      }
      final repo = ref.read(journalRepositoryProvider);
      if (widget.existingEntry != null) {
        if (widget.patientUid != null) {
          await repo.updatePatientEntry(
            patientUid: widget.patientUid!,
            entryId: widget.existingEntry!.entryId,
            answers: Map<String, dynamic>.from(_answers),
          );
        } else {
          await repo.updateEntry(
            entryId: widget.existingEntry!.entryId,
            answers: Map<String, dynamic>.from(_answers),
          );
        }
      } else {
        if (widget.patientUid != null) {
          await repo.createEntryForPatient(
            patientUid: widget.patientUid!,
            questionSetType: 'daily',
            answers: Map<String, dynamic>.from(_answers),
          );
        } else {
          await repo.submitEntry(
            questionSetType: 'daily',
            answers: Map<String, dynamic>.from(_answers),
          );
        }
      }
      if (mounted) {
        if (widget.patientUid != null) {
          ref.invalidate(patientJournalEntriesProvider(widget.patientUid!));
        } else {
          ref.invalidate(journalEntriesProvider);
        }
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _phase = _Phase.summary;
        _errorMsg = 'Failed to save. Please try again.';
      });
    }
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final visibleQuestions = _visibleQuestions();
    final currentIndexForView = visibleQuestions.isEmpty
        ? 0
        : (_currentIndex >= visibleQuestions.length
              ? visibleQuestions.length - 1
              : _currentIndex);

    return switch (_phase) {
      _Phase.intro => MonitoringIntroPage(
        onStart: _start,
        errorMsg: _errorMsg,
        patientName: widget.patientName,
      ),
      _Phase.loading => _buildLoading(context),
      _Phase.question => MonitoringQuestionPage(
        questions: visibleQuestions,
        currentIndex: currentIndexForView,
        backToSummary: _backToSummary,
        answers: _answers,
        getController: _ctrl,
        onAnswerChanged: _onAnswerChanged,
        onPrev: _prev,
        onNext: _next,
        onClose: () => Navigator.of(context).pop(),
      ),
      _Phase.summary => MonitoringSummaryPage(
        questions: visibleQuestions,
        answers: _answers,
        notesCtrl: _notesCtrl,
        isEditMode: widget.existingEntry != null,
        editCount: widget.existingEntry?.editCount ?? 0,
        historyLoading: _historyLoading,
        editHistory: _editHistory,
        errorMsg: _errorMsg,
        readOnly: widget.readOnly,
        onSubmit: _submit,
        onBack: _onSummaryBack,
        onEditQuestion: _editFromSummary,
      ),
      _Phase.submitting => _buildSubmitting(context),
      _Phase.noProfile => const MonitoringNoProfilePage(),
    };
  }

  Widget _buildLoading(BuildContext context) {
    final scheme = ColorScheme.of(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(child: CircularProgressIndicator(color: scheme.primary)),
    );
  }

  Widget _buildSubmitting(BuildContext context) {
    final scheme = ColorScheme.of(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              widget.existingEntry != null
                  ? 'Updating your journal...'
                  : 'Saving your journal...',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
