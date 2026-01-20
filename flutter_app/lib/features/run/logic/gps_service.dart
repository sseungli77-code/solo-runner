
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

    // 1. 설정값 튜닝: 정확도는 높이되, 너무 민감하지 않게 (DistanceFilter 3m)
    LocationSettings locationSettings;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3, // 3m 이하 움직임 무시 (떨림 방지)
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 1), 
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Solo Runner",
          notificationText: "Tracking your run...",
          enableWakeLock: true,
        )
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 3,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      );
    }

    _lastPosition = null;

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      // 2. 가만히 있을 때 튀는 값 잡기 (정확도 필터 강화)
      if (position.accuracy > 20.0) return; 

      if (_lastPosition != null) {
        double distMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude, _lastPosition!.longitude, 
          position.latitude, position.longitude
        );
        
        // 3. 미세 떨림 보정 (노이즈 캔슬링)
        if (distMeters < 1.0) return;

        int timeDelta = position.timestamp!.difference(_lastPosition!.timestamp!).inSeconds;
        if (timeDelta <= 0) timeDelta = 1;

        double speed = distMeters / timeDelta; // m/s

        // 4. 속도 필터링 (0.5m/s 미만 잡음 처리)
        if (speed < 0.5) {
           // 정지 상태
        } else if (speed < 12.5) {
           // 유효한 이동
           double distKm = distMeters / 1000.0;
           if (onDistanceUpdate != null) {
              onDistanceUpdate!(distKm, speed); 
           }
           _lastPosition = position; // 유효할 때만 갱신
        }
      } else {
        _lastPosition = position;
      }
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _lastPosition = null;
  }
}
