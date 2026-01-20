
import 'dart:math';

class PlanService {
  // BMI 및 사용자 정보에 따른 플랜 생성 로직
  List<Map<String, dynamic>> generatePlan({
    required String level,
    required double heightCm,
    required double weightKg,
    required double record10k,
    required int weeklyMinutes,
  }) {
    double bmi = weightKg / pow(heightCm / 100, 2);
    double vdot = _calculateVDOT(record10k);
    
    // 1. BMI Modifier (강도 조절)
    double volumeMod = 1.0;
    String intensityLabel = "Standard";
    
    if (bmi >= 35) {
      volumeMod = 0.4;
      intensityLabel = "Very Gentle (Safety First)";
    } else if (bmi >= 30) {
      volumeMod = 0.6; // 60% of volume
      intensityLabel = "Low Impact";
    } else if (bmi >= 25) {
      volumeMod = 0.8; // 80%
      intensityLabel = "Moderate";
    }

    // 2. VDOT Adjustment per BMI (High BMI = Slower VDOT)
    if (bmi >= 30) vdot -= 3;
    if (bmi >= 25) vdot -= 1;

    List<Map<String, dynamic>> plan = [];
    int totalWeeks = level == 'beginner' ? 12 : (level == 'intermediate' ? 16 : 24);
    
    // 기본 거리 (초보자 기준)
    double baseEasyDist = 3.0;
    double baseLongDist = 5.0;
    
    if (level == 'intermediate') { baseEasyDist = 5.0; baseLongDist = 10.0; }
    if (level == 'advanced') { baseEasyDist = 8.0; baseLongDist = 15.0; }

    // 3. Time Constraint Logic (시간 제한 적용)
    // VDOT 기반 예상 Easy Pace (분/km) 추정
    double estimatedPace = _estimateEasyPace(vdot); 
    
    // 예상 주간 총 거리 (대략적) = (화:Easy + 목:Tempo + 토:Long) * 주차 진행률 평균(1.2)
    double estWeeklyDist = (baseEasyDist + baseEasyDist + baseLongDist) * volumeMod * 1.2;
    double estTotalMinutes = estWeeklyDist * estimatedPace;

    // 시간이 부족하면 거리를 줄임 (비율 적용)
    if (estTotalMinutes > weeklyMinutes) {
       double timeRatio = weeklyMinutes / estTotalMinutes;
       // 너무 줄어들지 않게 최소 50%는 유지, 최대 100%
       timeRatio = max(0.5, timeRatio);
       
       volumeMod *= timeRatio; 
       intensityLabel += " (Time Limited)";
    }

    for (int week = 1; week <= totalWeeks; week++) {
      // 주차별 점진적 과부하 (10%씩 증가)
      double progression = 1.0 + (week * 0.05); 
      
      double easyDist = baseEasyDist * volumeMod * progression;
      double longDist = baseLongDist * volumeMod * progression;
      
      // BMI 30 이상은 초반 4주간 "Walk/Run"
      String runType = "Easy Run";
      if (bmi >= 30 && week <= 4) {
        runType = "Walk/Run (1min/1min)";
      }

      List<Map<String, dynamic>> runs = [];
      
      // 화요일 (Easy)
      runs.add({
        'day': 'Tue',
        'type': runType,
        'dist': double.parse(easyDist.toStringAsFixed(1)),
        'desc': 'Comfortable Pace ($intensityLabel)',
        'completed': false
      });

      // 목요일 (Tempo or Easy)
      if (week % 3 == 0) {
         runs.add({
          'day': 'Thu',
          'type': 'Tempo Run',
          'dist': double.parse((easyDist * 1.2).toStringAsFixed(1)),
          'desc': 'Push Harder',
          'completed': false
        });
      } else {
         runs.add({
          'day': 'Thu',
          'type': runType,
          'dist': double.parse(easyDist.toStringAsFixed(1)),
          'desc': 'Recovery Pace',
          'completed': false
        });
      }

      // 토요일 (Long)
      runs.add({
        'day': 'Sat',
        'type': 'Long Run',
        'dist': double.parse(longDist.toStringAsFixed(1)),
        'desc': 'Endurance Building',
        'completed': false
      });

      plan.add({'week': week, 'focus': 'Phase 1: Base', 'runs': runs});
    }
    
    return plan;
  }

  double _calculateVDOT(double min10k) {
    if (min10k <= 0) return 30.0;
    return 85.0 - (min10k * 0.8);
  }

  // VDOT를 대략적인 Easy Pace (min/km)로 변환
  double _estimateEasyPace(double vdot) {
      // VDOT 30 ~= 7.5 min/km, VDOT 60 ~= 4.6 min/km
      // 선형 근사: Pace = 10.5 - (0.1 * VDOT) (대략적)
      double pace = 10.5 - (0.1 * vdot);
      return max(4.0, pace); // 아무리 빨라도 4분/km 이하로 잡히진 않게 (Safety)
  }
}
