
import 'package:flutter/material.dart';

class AchievementChart extends StatelessWidget {
  final double plannedDist; // 계획된 주간 총 거리
  final double actualDist;  // 실제 뛴 거리

  const AchievementChart({
    super.key, 
    required this.plannedDist, 
    required this.actualDist
  });

  @override
  Widget build(BuildContext context) {
    if (plannedDist <= 0) return const SizedBox.shrink();

    // 진행률 계산 (최대 1.0, 초과는 별도 표시)
    double progress = (actualDist / plannedDist).clamp(0.0, 1.0);
    bool isOverAchieved = actualDist > plannedDist;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("WEEKLY GOAL", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              Text("${(progress * 100).toInt()}%", style: TextStyle(color: isOverAchieved ? const Color(0xFFFF0055) : const Color(0xFF00FFF0), fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          
          // Progress Bar
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: isOverAchieved 
                        ? [const Color(0xFFFF0055), const Color(0xFFFF5500)] 
                        : [const Color(0xFF00FFF0), const Color(0xFF00CCBB)]),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                         BoxShadow(
                           color: (isOverAchieved ? const Color(0xFFFF0055) : const Color(0xFF00FFF0)).withOpacity(0.5),
                           blurRadius: 10, offset: const Offset(0, 2)
                         )
                      ]
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${actualDist.toStringAsFixed(1)} km", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text("/ ${plannedDist.toStringAsFixed(1)} km", style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}
