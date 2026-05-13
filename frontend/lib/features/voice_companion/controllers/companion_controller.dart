import 'package:flutter_riverpod/legacy.dart';

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
  (ref) => CompanionController(),
);

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class CompanionController extends StateNotifier<CompanionControllerState> {
  CompanionController() : super(const CompanionControllerState());

  final SpeechService _speech = SpeechService();
  final TtsService _tts = TtsService();
  bool _disposed = false;
  int _messageCounter = 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await _tts.init();
    await _speech.init();
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

    Future.delayed(const Duration(milliseconds: 500), () {
      if (_disposed) return;
      _speak(generateResponse(transcript));
    });
  }

  // ── User interactions ──────────────────────────────────────────────────────

  void orbTapped() {
    if (_disposed) return;
    if (state.orbState == CompanionState.speaking) {
      _tts.stop();
      _startListening();
    } else if (state.orbState == CompanionState.listening) {
      _speech.stopListening();
      state = state.copyWith(orbState: CompanionState.idle, liveTranscript: '');
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

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_disposed) return;
      final response = generateResponse(trimmed);
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

  // ── Fake AI response ───────────────────────────────────────────────────────
  //
  // Contract (Phase 2 swap):
  //   Input:  user utterance — empty string triggers greeting
  //   Output: Taglish response, max 2 sentences
  //   To upgrade: replace only this method body with an Ollama HTTP call.
  //   Signature must remain: String generateResponse(String input)

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
    if (_containsAny(lower, ['stress', 'stressed', 'overwhelmed', 'pressure', 'pressure'])) {
      return 'Pag sobra na ang stress, okay lang mag-pahinga sandali. Nandito lang ako.';
    }
    if (_containsAny(lower, ['love', 'mahal', 'miss', 'nami-miss'])) {
      return 'Ang ganda ng pakiramdam na mahal at napapahalagahan. Ikwento mo pa sa akin!';
    }

    // Temporary universal acknowledgement until backend API replaces this.
    return 'Naiintindihan kita! Okay ka lang ba?';
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}
