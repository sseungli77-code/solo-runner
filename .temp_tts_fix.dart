  void _initTTS() async {
    _tts = FlutterTts();
    
    // 강제로 한국어 설정
    await _tts.setLanguage("ko-KR");
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(0.95);
    await _tts.setVolume(1.0);
    
    // 디버깅: 사용 가능한 언어 확인
    try {
      var languages = await _tts.getLanguages;
      print("📢 Available TTS languages: $languages");
      
      var currentLang = await _tts.getDefaultVoice;
      print("📢 Current TTS voice: $currentLang");
      
      // 한국어 다시 설정
      bool langSet = await _tts.setLanguage("ko-KR");
      print("📢 Korean language set: $langSet");
      
      // 테스트
      await _tts.speak("안녕하세요. 솔로 러너입니다.");
    } catch (e) {
      print("❌ TTS init error: $e");
    }
  }
