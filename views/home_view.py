import flet as ft
from logic.acwr import calculate_acwr
from logic.routine_generator import generate_routine

class HomeView(ft.Column):
    def __init__(self):
        super().__init__()
        self.spacing = 10
        self.horizontal_alignment = ft.CrossAxisAlignment.CENTER

    def did_mount(self):
        # 1. ACWR 계산 (Mock)
        recent_load = 120
        chronic_avg = 100
        acwr_val, status = calculate_acwr(recent_load, chronic_avg)
        
        # 2. 루틴 생성 (Mock condition: '상')
        routine_data = generate_routine(acwr_val, '상')
        
        # 3. 데이터 공유 (RunView 등에서 사용)
        self.page.data = {"current_routine": routine_data}
        
        # 4. UI 업데이트
        steps = routine_data['steps']
        duration_min = int(routine_data['total_duration'] / 60)
        
        # 루틴 타입 판단 (간단히 첫 번째 러닝 스텝 기준)
        routine_title = "강도 높은 인터벌" if routine_data['audio_program'] == 'detail' else "회복 위주 조깅"
        
        self.controls = [
            ft.Text("오늘의 추천 훈련", size=24, weight=ft.FontWeight.BOLD),
            ft.Container(
                content=ft.Column([
                    ft.Text(routine_title, size=20, color=ft.Colors.CYAN_200),
                    ft.Text(f"{duration_min}분 세션 - {len(steps)}단계 구성", size=16),
                    ft.Text(f"코칭 모드: {'상세(Detail)' if routine_data['audio_program'] == 'detail' else '간소화(Minimal)'}", 
                            size=14, color=ft.Colors.SECONDARY),
                ]),
                padding=20, border_radius=15, bgcolor=ft.Colors.SURFACE, margin=ft.margin.only(top=10, bottom=20)
            ),
            ft.Row([
                ft.Icon(ft.Icons.ANALYTICS, color=ft.Colors.AMBER_400),
                ft.Text(f"ACWR 지수: {acwr_val} ({status})", size=18, weight=ft.FontWeight.W_500),
            ], alignment=ft.MainAxisAlignment.CENTER),
            ft.Text("현재 상태: 훈련 가능 (Ready)", size=16, color=ft.Colors.GREEN_400),
            ft.Divider(),
            ft.Text("최근 컨디션 기반 추천", size=18, weight=ft.FontWeight.W_600),
        ]
        self.update()
