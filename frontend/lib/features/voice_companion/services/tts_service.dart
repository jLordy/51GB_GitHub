import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  VoidCallback? _onCompleteHandler;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    final languages = await _tts.getLanguages as List?;
    // Prefer Filipino if the device has the language pack; else en-PH; else en-US.
    const preferred = ['fil-PH', 'fil', 'en-PH', 'en-US'];
    var chosen = 'en-US';
    if (languages != null) {
      bool matches(String code, Object l) {
        final s = l.toString().toLowerCase().replaceAll('_', '-');
        final c = code.toLowerCase();
        return s == c || s.startsWith('$c-') || s.contains(c);
      }

      for (final lang in preferred) {
        if (languages.any((l) => matches(lang, l))) {
          chosen = lang == 'fil' ? 'fil-PH' : lang;
          break;
        }
      }
    }
    await _tts.setLanguage(chosen);
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      final cb = _onCompleteHandler;
      _onCompleteHandler = null;
      cb?.call();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      final cb = _onCompleteHandler;
      _onCompleteHandler = null;
      cb?.call();
    });
  }

  Future<void> speak(String text, {VoidCallback? onComplete}) async {
    _onCompleteHandler = onComplete;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    _onCompleteHandler = null;
    _isSpeaking = false;
    await _tts.stop();
  }

  /// Phase 2 stub: feed Ollama token stream to TTS in sentence chunks.
  Future<void> speakStream(Stream<String> tokenStream) async {
    // TODO(Phase 2): buffer tokens → split on sentence boundaries → speak chunks
  }

  void dispose() {
    _onCompleteHandler = null;
    _tts.stop();
  }
}
