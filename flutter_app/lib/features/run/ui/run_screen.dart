
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../logic/gps_service.dart';

class RunScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onSaveRun; // 러닝 데이터 저장 요청

  const RunScreen({super.key, required this.onSaveRun});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  final GpsService _gpsService = GpsService();
  bool _isRunning = false;
  double _distKm = 0.0;
  String _pace = "-'--\"";
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    // GPS callback 설정
    _gpsService.onDistanceUpdate = (distInc, currentPace) {
       if (mounted && _isRunning) {
         setState(() {
           _distKm += distInc;
           // 페이스 계산
           if (_distKm > 0) {
              double totalMinutes = _seconds / 60.0;
              double paceVal = totalMinutes / _distKm;
              int pMin = paceVal.floor();
              int pSec = ((paceVal - pMin) * 60).round();
              _pace = "$pMin'${pSec.toString().padLeft(2,'0')}\"";
           }
         });
       }
    };
  }
  
  Future<void> _initializeMap() async {
    // 네이버 맵 SDK 초기화
    await NaverMapSdk.instance.initialize(); 
  }
  
  void _toggleRun() async {
    if (_isRunning) {
        // PAUSE/STOP
        _timer?.cancel();
        _gpsService.stopTracking();
        setState(() => _isRunning = false);
        
        widget.onSaveRun({
            'dist': _distKm,
            'time': _seconds,
            'pace': _pace,
            'date': DateTime.now().toIso8601String(),
        });
    } else {
        // START
        bool granted = await _gpsService.checkPermission();
        if (!granted) return; 

        // 알림 권한 요청 (Android 13+)
        if (await Permission.notification.isDenied) {
             await Permission.notification.request();
        }

        // 타이머 중복 실행 방지
        _timer?.cancel();

        setState(() { _isRunning = true; _seconds = 0; _distKm = 0.0; _pace = "-'--\""; });
        
        // 타이머 시작 (1초마다 시간 증가)
        _timer = Timer.periodic(const Duration(seconds: 1), (t) { 
           if (mounted) setState(() => _seconds++); 
        });
        
        // GPS 추적 시작
        _gpsService.startTracking();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gpsService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String timeStr = "${(_seconds~/60).toString().padLeft(2,'0')}:${(_seconds%60).toString().padLeft(2,'0')}";
    
    return Stack(
      children: [
        // Real Naver Map
        Positioned.fill(
          child: NaverMap(
            options: const NaverMapViewOptions(
              indoorEnable: true,
              locationButtonEnable: true, // 현위치 버튼
              consumeSymbolTapEvents: false,
              mapType: NMapType.navi, // 네비게이션 스타일 (어두움)
              nightModeEnable: true, // 강제 다크 모드
            ),
            onMapReady: (controller) {
              print("Naver Map Ready");
            },
          ),
        ),
        
        // Gradient Overlay
        Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withOpacity(0.7), Colors.transparent, Colors.black.withOpacity(0.8)], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.0, 0.4, 0.8])))),
        
        // Top Info
        Positioned(
          top: 60, left: 0, right: 0,
          child: Column(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _isRunning ? const Color(0xFFFF0055) : const Color(0xFF00FFF0), borderRadius: BorderRadius.circular(20)), child: Text(_isRunning ? "RUNNING" : "READY", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2))),
              const SizedBox(height: 20),
              Text(timeStr, style: const TextStyle(fontSize: 80, fontWeight: FontWeight.normal, color: Colors.white, fontFamily: 'monospace', letterSpacing: -2)),
              const Text("DURATION", style: TextStyle(color: Colors.white30, fontSize: 12, letterSpacing: 2)),
          ])
        ),
        
        // Bottom Stats
        Positioned(
          bottom: 40, left: 24, right: 24,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF1E1E2C).withOpacity(0.8), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)]),
            child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _buildNeonStatItem("DISTANCE", "${_distKm.toStringAsFixed(2)}", "km"),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _buildNeonStatItem("AVG PACE", _pace, "/km"),
                ]),
                const SizedBox(height: 30),
                GestureDetector(onTap: _toggleRun, child: Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: _isRunning ? const Color(0xFFFF0055) : const Color(0xFF00FFF0), boxShadow: [BoxShadow(color: (_isRunning ? const Color(0xFFFF0055) : const Color(0xFF00FFF0)).withOpacity(0.4), blurRadius: 15, spreadRadius: 2)]), child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 36))),
            ])
          )
        )
      ],
    );
  }
  
  Widget _buildNeonStatItem(String label, String value, String unit) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
             Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
             const SizedBox(width: 4),
             Text(unit, style: const TextStyle(color: Color(0xFF00FFF0), fontSize: 12, fontWeight: FontWeight.bold)),
        ])
    ]);
  }
}
