import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';

  void Function(String)? _onResultCallback;
  void Function(String)? _onDoneCallback;

  bool get isListening => _isListening;

  void _emitDoneIfListening() {
    if (!_isListening) return;
    _isListening = false;
    final text = _lastWords;
    _lastWords = '';
    _onDoneCallback?.call(text);
  }

  Future<bool> init() async {
    _isInitialized = await _stt.initialize(
      onError: (error) {
        _isListening = false;
        _lastWords = '';
        _onDoneCallback?.call('');
      },
      onStatus: (status) {
        // 'notListening' alone often fires immediately on Android with no speech —
        // ignore unless we already have transcribed text (end-of-utterance case).
        if (status == 'done') {
          _emitDoneIfListening();
        } else if (status == 'notListening' &&
            _lastWords.trim().isNotEmpty) {
          _emitDoneIfListening();
        }
      },
    );
    return _isInitialized;
  }

  Future<void> startListening({
    required void Function(String partial) onResult,
    required void Function(String finalText) onDone,
  }) async {
    if (!_isInitialized) {
      final granted = await init();
      if (!granted) {
        onDone('');
        return;
      }
    }

    _lastWords = '';
    _onResultCallback = onResult;
    _onDoneCallback = onDone;
    _isListening = true;

    await _stt.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;
        _onResultCallback?.call(result.recognizedWords);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_PH',
    );
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    _lastWords = '';
    _onDoneCallback = null;
    await _stt.stop();
  }

  void dispose() {
    _onResultCallback = null;
    _onDoneCallback = null;
    _lastWords = '';
    _stt.cancel();
  }
}
