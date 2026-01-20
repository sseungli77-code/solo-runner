
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class GpsService {
  StreamSubscription<Position>? _positionStream;
  Position? _lastPosition;
  
  // 콜백 함수: 거리가 업데이트될 때마다 호출됨 (거리증가량, 현재페이스)
  Function(double, double)? onDistanceUpdate; 

  GpsService({this.onDistanceUpdate});

  Future<bool> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  void startTracking() async {
    if (!await checkPermission()) return;

    // 1. 설정값 변경: 제한 해제 (Navigation Grade)
    LocationSettings locationSettings;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0, // 0m: 즉시 갱신
        forceLocationManager: true, // 구형 기기 강제 갱신
        intervalDuration: const Duration(seconds: 1), // 1초마다 강제 갱신
        // 2. 백그라운드 사수 (포그라운드 서비스 알림)
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Solo Runner",
          notificationText: "Tracking your run...",
          enableWakeLock: true,
        )
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness, // iOS에 '운동 중' 신분 밝힘
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    }

    _lastPosition = null;

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      // 3. 데이터 거르기 (정확도 필터: 오차 30m 이상은 버림)
      if (position.accuracy > 30.0) return; 

      if (_lastPosition != null) {
        double distMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude, _lastPosition!.longitude, 
          position.latitude, position.longitude
        );
        
        // 시간 차이 (초)
        int timeDelta = position.timestamp!.difference(_lastPosition!.timestamp!).inSeconds;
        if (timeDelta <= 0) timeDelta = 1; // 0초 방지

        // 속도 계산 (m/s)
        double speed = distMeters / timeDelta;

        // '우사인 볼트 필터': 12.5m/s (약 45km/h) 이상이면 튀는 값으로 간주
        if (speed < 12.5) {
           double distKm = distMeters / 1000.0;
           if (onDistanceUpdate != null) {
              onDistanceUpdate!(distKm, 0.0); 
           }
           _lastPosition = position; // 유효한 데이터일 때만 갱신
        }
      } else {
        _lastPosition = position; // 첫 위치
      }
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _lastPosition = null;
  }
}
