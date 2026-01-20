
import 'package:flutter/material.dart';
import 'widgets/achievement_chart.dart';

class PlanScreen extends StatelessWidget {
  final List<Map<String, dynamic>> plan;
  final Map<String, dynamic> progress;
  final Function(Map<String, dynamic>) onRunSelect;

  const PlanScreen({
    super.key, 
    required this.plan, 
    required this.progress,
    required this.onRunSelect
  });

  @override
  Widget build(BuildContext context) {
    if (plan.isEmpty) return const Center(child: Text("Generate a Plan first", style: TextStyle(color: Colors.white24)));
    
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 100),
      itemCount: plan.length + 1, // +1 for Header
      itemBuilder: (ctx, idx) {
        if (idx == 0) return _buildPlanHeader();
        
        final week = plan[idx-1];
        // 이번 주인지 판단 (일단 1주차를 이번 주로 가정하거나, 로직 추가 가능)
        bool isCurrentWeek = idx == 1; 

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isCurrentWeek ? const Color(0xFF00FFF0).withOpacity(0.3) : Colors.white.withOpacity(0.05)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: isCurrentWeek, // 1주차만 펼치기
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              iconColor: const Color(0xFF00FFF0),
              collapsedIconColor: Colors.white24,
              title: Text("WEEK ${week['week']}", style: TextStyle(color: isCurrentWeek ? Colors.white : Colors.white70, fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'monospace')),
              subtitle: Text(week['focus'] ?? "Foundation", style: TextStyle(color: isCurrentWeek ? const Color(0xFF00FFF0) : Colors.white24, fontSize: 12)),
              children: (week['runs'] as List).map<Widget>((r) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: (r['completed']==true) ? const Color(0xFF00FFF0).withOpacity(0.2) : Colors.white10, shape: BoxShape.circle),
                    child: Icon(Icons.directions_run, color: (r['completed']==true) ? const Color(0xFF00FFF0) : Colors.white24, size: 16),
                  ),
                  title: Text(r['type'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(r['desc'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                     child: Text("${r['dist']}km", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () {
                       onRunSelect(r);
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFF00FFF0), content: Text("Target Loaded: ${r['type']}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))));
                  },
              )).toList()
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanHeader() {
    // 차트 데이터 계산 (임시: 1주차 목표 합계 vs 완료 기록 합계)
    // 실제로는 progress['weeklyDist'] 같은 걸 써야 하지만, 여기선 가볍게 구현
    double planned = 0.0;
    if (plan.isNotEmpty) {
       for(var r in plan[0]['runs']) planned += (r['dist'] as double);
    }
    double actual = 0.0; 
    // 실제 기록은 progress['completedRuns']에서 날짜 비교해서 가져와야 함.
    // 일단 UI 테스트를 위해 0.0 (또는 데모값)
    if (progress['completedWeeklyDist'] != null) actual = progress['completedWeeklyDist'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10), // 간격 줄임 (차트 때문)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("MY PLAN", style: TextStyle(color: Color(0xFF00FFF0), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text("TRAINING\nSCHEDULE", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.1)),
          
          // Achievement Chart Added Here!
          AchievementChart(plannedDist: planned, actualDist: actual),
          
          const SizedBox(height: 10),
          Row(
            children: [
               _buildMiniStat("VDOT", progress['currentVDOT']?.toStringAsFixed(1) ?? "N/A"),
               const SizedBox(width: 20),
               _buildMiniStat("MISSED", "${progress['missedDays']} Days"),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
