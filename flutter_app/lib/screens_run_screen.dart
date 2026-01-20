
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:math';

class RunScreen extends StatefulWidget {
  final VoidCallback onRunFinished;
  
  const RunScreen({super.key, required this.onRunFinished});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  // --- 상태 변수 ---
  bool _isRunning = false;
  String _gpsStatus = "GPS 대기 중...";
  double _distKm = 0.0;
  String _pace = "-'--\"";
  Timer? _timer;
  int _seconds = 0;
  StreamSubscription<Position>? _positionStream;
  bool _isVoiceOn = true;
  
  final FlutterTts _tts = FlutterTts();
  NaverMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _initTTS();
    _checkPermission();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  void _initTTS() async {
    await _tts.setLanguage("ko-KR");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  void _checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  // --- UI Build ---
  @override
  Widget build(BuildContext context) {
    String timeStr = "${(_seconds~/60).toString().padLeft(2,'0')}:${(_seconds%60).toString().padLeft(2,'0')}";
    
    return Stack(
      children: [
        NaverMap(
          options: const NaverMapViewOptions(
            locationButtonEnable: true,
            indoorEnable: true,
            consumeSymbolTapEvents: false,
            mapType: NMapType.basic,
            nightModeEnable: true,
          ),
          onMapReady: (controller) {
             _mapController = controller;
             print("🗺️ 네이버 지도 준비 완료");
          },
        ),
        
        // 상단 타이머
        Positioned(
          top: 0, left: 0, right: 0,
          height: 200,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isRunning ? "RUNNING" : "READY", 
                  style: const TextStyle(color: Color(0xFF00FFF0), fontWeight: FontWeight.bold, letterSpacing: 2)
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 70, 
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900, 
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 20)]
                  )
                ),
              ],
            ),
          ),
        ),

        // 하단 패널
        Positioned(
          bottom: 30, left: 20, right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1E).withOpacity(0.85),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat("거리", "${_distKm.toStringAsFixed(2)}", "km"),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _buildStat("페이스", _pace, "/km"),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                   onTap: _toggleRun,
                   child: Container(
                     width: 80, height: 80,
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       color: _isRunning ? const Color(0xFFFF3366) : const Color(0xFF00FFF0),
                     ),
                     child: Icon(
                       _isRunning ? Icons.pause : Icons.play_arrow,
                       color: const Color(0xFF0F0F1E), size: 40
                     ),
                   ),
                 ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
             Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
             Text(unit, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        )
      ],
    );
  }

  void _toggleRun() {
    if (_isRunning) {
      _stopRun();
    } else {
      _startRun();
    }
  }

  void _startRun() {
    setState(() {
      _isRunning = true;
      _seconds = 0;
      _distKm = 0.0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
      // 1분마다 보이스 코칭 (임시)
      if (_seconds % 60 == 0 && _isVoiceOn) {
         _tts.speak("현재 거리 ${_distKm.toStringAsFixed(2)} 킬로미터, 페이스 $_pace 입니다.");
      }
    });
    
    // GPS 로직 (간소화)
    _positionStream = Geolocator.getPositionStream().listen((Position position) {
      // 속도, 거리 계산 로직
      // ...
    });
  }

  void _stopRun() {
    _timer?.cancel();
    _positionStream?.cancel();
    setState(() {
      _isRunning = false;
    });
    
    // 종료 콜백 호출 (Main으로 데이터 전달)
    // widget.onRunFinished(_distKm, _seconds);
    
    // 임시: 그냥 다이얼로그 띄우기
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("러닝 종료"),
        content: Text("수고하셨습니다!\n기록: ${_distKm.toStringAsFixed(2)}km"),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인"))],
      )
    );
  }
}
