import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';

  void Function(String)? _onResultCallback;
  void Function(String)? _onDoneCallback;

  bool get isListening => _isListening;

  Future<bool> init() async {
    _isInitialized = await _stt.initialize(
      onError: (error) {
        if (!_isListening) return;
        _isListening = false;
        _lastWords = '';
        _onDoneCallback?.call('');
      },
      onStatus: (status) {
        // Orb-tap is the only submission trigger.
        // Status events (done, notListening) do NOT auto-submit — they caused
        // premature replies and double-listen bugs on Android.
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

    if (_isListening) return;

    _lastWords = '';
    _onResultCallback = onResult;
    _onDoneCallback = onDone;
    _isListening = true;

    await _stt.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;
        _onResultCallback?.call(result.recognizedWords);
      },
      listenFor: const Duration(seconds: 120),
      pauseFor: const Duration(seconds: 120),
      localeId: 'en_PH',
    );
  }

  /// Called when the user taps the orb. Fires [_onDoneCallback] with whatever
  /// was captured, then stops the STT engine.
  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    final text = _lastWords;
    _lastWords = '';
    final cb = _onDoneCallback;
    _onDoneCallback = null;
    _onResultCallback = null;
    cb?.call(text); // fires _onSpeechDone in controller
    await _stt.stop();
  }

  void dispose() {
    _onResultCallback = null;
    _onDoneCallback = null;
    _lastWords = '';
    _stt.cancel();
  }
}
