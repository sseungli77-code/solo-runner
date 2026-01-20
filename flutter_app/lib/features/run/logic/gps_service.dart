
import 'package:geolocator/geolocator.dart';
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

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, 
      distanceFilter: 5 // 5미터 이동 시 갱신
    );

    _lastPosition = null;

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      if (_lastPosition != null) {
        double distMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude, _lastPosition!.longitude, 
          position.latitude, position.longitude
        );

        // 튀는 값 필터링 (1초에 100m 이동 등)
        if (distMeters > 0 && distMeters < 100) {
          double distKm = distMeters / 1000.0;
          if (onDistanceUpdate != null) {
             // 페이스 계산은 호출하는 쪽(Timer)과 연동해야 하므로 여기선 거리만 넘김
             onDistanceUpdate!(distKm, 0.0); 
          }
        }
      }
      _lastPosition = position;
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _lastPosition = null;
  }
}
