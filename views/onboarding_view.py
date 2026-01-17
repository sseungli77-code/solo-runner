import flet as ft
from logic.science_engine import calculate_vdot, get_bmi

class OnboardingView(ft.Column):
    def __init__(self, on_complete):
        super().__init__()
        self.on_complete = on_complete
        self.horizontal_alignment = ft.CrossAxisAlignment.CENTER
        self.spacing = 20
        self.scroll = ft.ScrollMode.AUTO
        
        self.age = ft.TextField(label="나이", keyboard_type=ft.KeyboardType.NUMBER, width=300)
        self.height = ft.TextField(label="키 (cm)", keyboard_type=ft.KeyboardType.NUMBER, width=300)
        self.weight = ft.TextField(label="몸무게 (kg)", keyboard_type=ft.KeyboardType.NUMBER, width=300)
        
        self.level_radio = ft.RadioGroup(
            content=ft.Column([
                ft.Radio(value="beginner", label="런닝이 처음이에요 (초급)"),
                ft.Radio(value="experienced", label="기록이 있어요 (중/고급)"),
            ]),
            on_change=self.handle_level_change
        )
        
        self.record_container = ft.Column(visible=False, controls=[
            ft.Text("최근 달리기 기록을 알려주세요."),
            ft.Row([
                ft.TextField(label="평균 페이스 (분)", hint_text="5", width=100),
                ft.TextField(label="초", hint_text="30", width=100),
                ft.Text("/km", size=16)
            ], alignment=ft.MainAxisAlignment.CENTER),
            ft.TextField(label="가장 길게 뛴 거리 (km)", hint_text="10", width=300),
        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER)
        
        self.controls = [
            ft.Text("SoloRunner 시작하기", size=32, weight=ft.FontWeight.BOLD),
            ft.Text("당신에게 딱 맞는 논문 기반 코칭을 시작합니다.", color=ft.colors.GREY),
            self.age, self.height, self.weight,
            ft.Divider(),
            ft.Text("나의 런닝 수준", size=18, weight=ft.FontWeight.BOLD),
            self.level_radio,
            self.record_container,
            ft.ElevatedButton("코칭 시작하기", on_click=self.submit, width=300, height=50)
        ]

    def handle_level_change(self, e):
        self.record_container.visible = (e.control.value == "experienced")
        self.update()

    def submit(self, e):
        if not self.age.value or not self.height.value or not self.weight.value:
            return
            
        profile = {
            "age": int(self.age.value),
            "height": float(self.height.value),
            "weight": float(self.weight.value),
            "level": self.level_radio.value,
        }
        
        if profile["level"] == "experienced":
            pace_min = float(self.record_container.controls[1].controls[0].value or 0)
            pace_sec = float(self.record_container.controls[1].controls[1].value or 0)
            best_dist = float(self.record_container.controls[2].value or 0)
            
            total_sec = (pace_min * 60) + pace_sec
            profile["vdot"] = calculate_vdot(best_dist * 1000, total_sec * best_dist)
        else:
            profile["bmi"] = get_bmi(profile["height"], profile["weight"])
            
        self.on_complete(profile)
