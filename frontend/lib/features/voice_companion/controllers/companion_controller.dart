import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/companion_repository.dart';
import '../models/companion_state.dart';
import '../models/message_model.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class CompanionControllerState {
  final CompanionState orbState;
  final List<VoiceMessage> messages;
  final String liveTranscript;
  final bool isChatMode;
  final bool ttsEnabled;
  final bool isTyping;

  const CompanionControllerState({
    this.orbState = CompanionState.idle,
    this.messages = const [],
    this.liveTranscript = '',
    this.isChatMode = false,
    this.ttsEnabled = true,
    this.isTyping = false,
  });

  CompanionControllerState copyWith({
    CompanionState? orbState,
    List<VoiceMessage>? messages,
    String? liveTranscript,
    bool? isChatMode,
    bool? ttsEnabled,
    bool? isTyping,
  }) {
    return CompanionControllerState(
      orbState: orbState ?? this.orbState,
      messages: messages ?? this.messages,
      liveTranscript: liveTranscript ?? this.liveTranscript,
      isChatMode: isChatMode ?? this.isChatMode,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final companionControllerProvider =
    StateNotifierProvider.autoDispose<CompanionController, CompanionControllerState>(
  (ref) => CompanionController(ref.read(companionRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class CompanionController extends StateNotifier<CompanionControllerState> {
  CompanionController(this._repo) : super(const CompanionControllerState());

  final CompanionRepository _repo;
  final SpeechService _speech = SpeechService();
  final TtsService _tts = TtsService();
  bool _disposed = false;
  bool _useApi = false;
  int _messageCounter = 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await _tts.init();
    await _speech.init();

    // Health check — if Ollama is reachable, use real AI for this session.
    // Runs in the background; greeting always uses the local fallback for speed.
    _repo.checkHealth().then((ok) {
      _useApi = ok;
      debugPrint(
        '[COMPANION] session: health_done use_api=$_useApi '
        '(Ollama path ${_useApi ? "enabled" : "disabled — local fallback"})',
      );
    });

    // Opening greeting is always local — no API call, avoids latency before user says anything.
    _speak(generateResponse(''));
  }

  @override
  void dispose() {
    _disposed = true;
    _tts.dispose();
    _speech.dispose();
    super.dispose();
  }

  // ── Voice flow ────────────────────────────────────────────────────────────

  void _speak(String text) {
    if (_disposed) return;
    final aiMessage = VoiceMessage(
      id: 'msg_${_messageCounter++}',
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      orbState: CompanionState.speaking,
      messages: [...state.messages, aiMessage],
      liveTranscript: '',
      isTyping: false,
    );
    _tts.speak(text, onComplete: _onTtsDone);
  }

  void _onTtsDone() {
    if (_disposed) return;
    _startListening();
  }

  void _startListening() {
    if (_disposed) return;
    state = state.copyWith(
      orbState: CompanionState.listening,
      liveTranscript: '',
    );
    _speech.startListening(
      onResult: _onSpeechResult,
      onDone: _onSpeechDone,
    );
  }

  void _onSpeechResult(String partial) {
    if (_disposed) return;
    state = state.copyWith(liveTranscript: partial);
  }

  void _onSpeechDone(String finalText) {
    if (_disposed) return;
    final transcript = finalText.trim();
    if (transcript.isEmpty) {
      _startListening();
      return;
    }

    final userMessage = VoiceMessage(
      id: 'msg_${_messageCounter++}',
      text: transcript,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      orbState: CompanionState.processing,
      messages: [...state.messages, userMessage],
      liveTranscript: '',
    );

    Future.delayed(const Duration(seconds: 3), () async {
      if (_disposed) return;
      final reply = await generateResponseAsync(transcript);
      if (_disposed) return;
      _speak(reply);
    });
  }

  // ── User interactions ──────────────────────────────────────────────────────

  void orbTapped() {
    if (_disposed) return;
    if (state.orbState == CompanionState.speaking) {
      _tts.stop();
      _startListening();
    } else if (state.orbState == CompanionState.listening) {
      // stopListening fires _onSpeechDone via callback — orb-tap is the submit
      _speech.stopListening();
    }
  }

  void sendChatMessage(String text) {
    if (_disposed || text.trim().isEmpty) return;
    final trimmed = text.trim();
    final userMessage = VoiceMessage(
      id: 'msg_${_messageCounter++}',
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
    );

    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (_disposed) return;
      final response = await generateResponseAsync(trimmed);
      if (_disposed) return;
      final aiMessage = VoiceMessage(
        id: 'msg_${_messageCounter++}',
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isTyping: false,
        orbState: state.ttsEnabled ? CompanionState.speaking : state.orbState,
      );
      if (state.ttsEnabled) {
        _tts.speak(response, onComplete: () {
          if (_disposed) return;
          if (state.isChatMode) {
            state = state.copyWith(orbState: CompanionState.idle);
          }
        });
      }
    });
  }

  void toggleTts() {
    if (_disposed) return;
    if (!state.ttsEnabled) {
      state = state.copyWith(ttsEnabled: true);
    } else {
      _tts.stop();
      state = state.copyWith(ttsEnabled: false, orbState: CompanionState.idle);
    }
  }

  void toggleMode() {
    if (_disposed) return;
    if (state.isChatMode) {
      // Returning to voice — restart listen loop
      state = state.copyWith(isChatMode: false);
      _tts.stop();
      _startListening();
    } else {
      // Going to chat — stop everything
      _tts.stop();
      _speech.stopListening();
      state = state.copyWith(
        isChatMode: true,
        orbState: CompanionState.idle,
        liveTranscript: '',
      );
    }
  }

  // ── Async AI response (real API with local fallback) ───────────────────────

  /// Tries the backend API first; silently falls back to [generateResponse]
  /// if the API is unavailable or returns null.
  Future<String> generateResponseAsync(String input) async {
    debugPrint(
      '[COMPANION] generateResponseAsync: use_api=$_useApi input_len=${input.length}',
    );
    if (_useApi) {
      try {
        final reply = await _repo.getAiReply(input);
        if (reply != null && reply.isNotEmpty) {
          debugPrint(
            '[COMPANION] generateResponseAsync: source=api reply_len=${reply.length}',
          );
          return reply;
        }
        debugPrint(
          '[COMPANION] generateResponseAsync: api returned null/empty → fallback',
        );
      } catch (e) {
        debugPrint('[COMPANION] generateResponseAsync error: $e');
      }
    } else {
      debugPrint(
        '[COMPANION] generateResponseAsync: skipping api (use_api=false) → fallback',
      );
    }
    final local = generateResponse(input);
    debugPrint(
      '[COMPANION] generateResponseAsync: source=local reply_len=${local.length}',
    );
    return local;
  }

  // ── Local fallback AI response ─────────────────────────────────────────────
  //
  // Used when: backend unreachable, Ollama down, or _useApi == false.
  // Greeting (empty input) always goes here even when API is available.

  String generateResponse(String input) {
    if (input.trim().isEmpty) {
      return 'Hi! Kamusta ka? Nandito ako para makausap ka.';
    }

    final lower = input.toLowerCase();

    if (_containsAny(lower, ['sad', 'malungkot', 'lungkot', 'umiyak', 'lumbay'])) {
      return 'Nandito lang ako ha, okay lang maging malungkot minsan. Gusto mo bang mag-usap?';
    }
    if (_containsAny(lower, ['masaya', 'happy', 'saya', 'nagagalak', 'excited'])) {
      return 'Ayos yan! Sabihin mo sa akin kung bakit ka masaya!';
    }
    if (_containsAny(lower, ['tulong', 'help', 'kailangan', 'assist', 'tulungan'])) {
      return 'Heto na ako! Anong kailangan mo?';
    }
    if (_containsAny(lower, ['pagod', 'tired', 'exhausted', 'haggard', 'antok'])) {
      return 'Mukhang pagod ka ngayon. Okay ka lang ba?';
    }
    if (_containsAny(lower, ['takot', 'scared', 'anxious', 'balisa', 'natatakot', 'worry', 'nag-aalala'])) {
      return 'Normal lang maging balisa minsan. Nandito ako para sa\'yo.';
    }
    if (_containsAny(lower, ['sakit', 'masakit', 'hurt', 'pain', 'sick', 'may sakit'])) {
      return 'Naiintindihan kita. Importante na mag-ingat sa kalusugan mo. Okay ka ba?';
    }
    if (_containsAny(lower, ['stress', 'stressed', 'overwhelmed', 'pressure'])) {
      return 'Pag sobra na ang stress, okay lang mag-pahinga sandali. Nandito lang ako.';
    }
    if (_containsAny(lower, ['love', 'mahal', 'miss', 'nami-miss'])) {
      return 'Ang ganda ng pakiramdam na mahal at napapahalagahan. Ikwento mo pa sa akin!';
    }

    // ── Health-specific responses ──────────────────────────────────────────
    if (_containsAny(lower, ['bp', 'blood pressure', 'presyon', 'hypertension', 'mataas ang dugo', 'mababa ang dugo'])) {
      return 'Kumusta ang iyong blood pressure ngayon? Importante mag-monitor ng regular, lalo na kung may history ka.';
    }
    if (_containsAny(lower, ['ubo', 'cough', 'sipon', 'cold', 'baradong ilong', 'nagsisingasing'])) {
      return 'Nag-aalala ako sa\'yo. Nagpapahinga ka ba ng maayos at umiinom ng maraming tubig?';
    }
    if (_containsAny(lower, ['lagnat', 'fever', 'mainit ang katawan', 'nilalagnat', 'temperature'])) {
      return 'Lagnat ka? Mag-ingat — uminom ng tubig, magpahinga, at kung hindi bumaba kumonsulta sa doktor.';
    }
    if (_containsAny(lower, ['puso', 'heart', 'palpitation', 'kabog ng dibdib', 'cardiac', 'tibok'])) {
      return 'Ang kalusugan ng puso ay napakahalaga. Naka-consult ka na ba sa iyong doktor tungkol dito?';
    }
    if (_containsAny(lower, ['diabetes', 'asukal', 'sugar', 'glucose', 'diabetic', 'blood sugar'])) {
      return 'Importante ang pag-monitor ng blood sugar araw-araw. Kumain ka na ba ngayon at nag-check ka na ng glucose mo?';
    }
    if (_containsAny(lower, ['checkup', 'check up', 'doktor', 'doctor', 'hospital', 'klinika', 'ospital', 'konsulta'])) {
      return 'Magandang ideya ang mag-checkup regularly. May appointment ka na ba o kailangan mo ng tulong?';
    }
    if (_containsAny(lower, ['tulog', 'sleep', 'hindi makatulog', 'insomnia', 'gising', 'hindi nakatulog'])) {
      return 'Ang pahinga ay kasing halaga ng gamot. Ilang oras ka natutulog ngayon? Okay ka lang ba?';
    }
    if (_containsAny(lower, ['gamot', 'medicine', 'medication', 'tablet', 'vitamins', 'vitaminas', 'inumin'])) {
      return 'Huwag kalimutang uminom ng gamot sa tamang oras. Kumpleto ka ba sa gamot mo ngayon?';
    }
    if (_containsAny(lower, ['kumain', 'kain', 'eat', 'gutom', 'hungry', 'pagkain', 'food', 'diet'])) {
      return 'Mahalaga ang tamang pagkain para sa kalusugan. Kumain ka na ba ng maayos ngayon?';
    }
    if (_containsAny(lower, ['ehersisyo', 'exercise', 'gym', 'lakad', 'walk', 'jogging', 'aktibo'])) {
      return 'Maganda yan! Regular na ehersisyo ay nakatutulong sa kalusugan ng puso at isip. Gaano ka kadalas?';
    }
    if (_containsAny(lower, ['alak', 'alcohol', 'sigarilyo', 'smoke', 'cigarette', 'yosi'])) {
      return 'Naiintindihan kita. Kung kaya, subukan mong bawasan — malaking bagay yan para sa iyong kalusugan.';
    }

    return 'Naiintindihan kita! Okay ka lang ba?';
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}
