import flet as ft
import time
import threading
from logic.audio_engine import AudioEngine
from logic.gps_tracker import GPSTracker
from logic.acwr import calculate_acwr
from logic.routine_generator import generate_routine

class RunView(ft.Column):
    def __init__(self):
        super().__init__()
        self.horizontal_alignment = ft.CrossAxisAlignment.CENTER
        self.spacing = 20
        
        # Training Info
        self.training_title = ft.Text("추천 훈련 로딩 중...", size=20, color=ft.colors.CYAN_200, weight=ft.FontWeight.BOLD)
        self.training_desc = ft.Text("", size=16, color=ft.colors.GREY) # Changed OUTLINE to GREY
        
        self.timer_text = ft.Text("00:00", size=80, weight=ft.FontWeight.BOLD, color="primary") # Changed PRIMARY to "primary"
        self.is_running = False
        self.seconds = 0
        self.audio_engine = None
        
        # GPS Stats
        self.gpstracker = GPSTracker()
        self.dist_text = ft.Text("0.00 km", size=24, weight=ft.FontWeight.W_500)
        self.pace_text = ft.Text("0'00\"/km", size=24, weight=ft.FontWeight.W_500)
        
        # GPS Bridge (Hidden TextField to receive data from JS)
        self.gps_bridge = ft.TextField(
            label="gps_data_bridge",
            visible=False,
            on_change=self.handle_js_gps
        )
        
        self.play_button = ft.IconButton(
            icon=ft.icons.PLAY_CIRCLE_FILLED,
            icon_size=100,
            icon_color="primary", # Changed PRIMARY to "primary"
            on_click=self.toggle_timer
        )
        
        self.controls = [
            self.gps_bridge,
            ft.Container(
                content=ft.Column([
                    ft.Text("오늘의 훈련", size=14, color=ft.colors.GREY), # Changed OUTLINE to GREY
                    self.training_title,
                    self.training_desc,
                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                padding=10,
                margin=ft.margin.only(top=20)
            ),
            self.timer_text,
            ft.Row([
                ft.Column([ft.Text("Distance", size=14, color=ft.colors.GREY), self.dist_text], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                ft.VerticalDivider(),
                ft.Column([ft.Text("Pace", size=14, color=ft.colors.GREY), self.pace_text], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
            ], alignment=ft.MainAxisAlignment.CENTER, spacing=40),
            ft.Container(height=20),
            self.play_button,
            ft.Text("Tap to Start workout", size=14, color=ft.colors.GREY)
        ]

    async def did_mount(self):
        # 1. 사용자 프로필 및 ACWR 로드 (임시로 빈 딕셔너리 사용)
        user_profile = {}
        
        recent_load = 120 # Mock
        chronic_avg = 100 # Mock
        acwr_val, status = calculate_acwr(recent_load, chronic_avg)
        
        # 2. 루틴 생성 (개인화 알고리즘 반영)
        routine_data = generate_routine(acwr_val, user_profile)
        self.page.data = {"current_routine": routine_data}
        
        # UI 업데이트
        duration_min = int(routine_data['total_duration'] / 60)
        level_str = "초보자 맞춤" if user_profile.get("level") == "beginner" else "중/고급자 훈련"
        self.training_title.value = f"{level_str} - {routine_data['steps'][0][0].upper()}"
        self.training_desc.value = f"{duration_min}분 세션 | 목표 페이스 {routine_data['target_pace']//60}'{routine_data['target_pace']%60:02d}\""
        self.update()

        # 3. GPS 및 오디오 엔진 초기화
        await self.start_js_tracking()
        self.audio_engine = AudioEngine(self.page)
        
        if self.page.data and "current_routine" in self.page.data:
            routine = self.page.data["current_routine"]
            self.audio_engine.set_program(
                mode=routine['audio_program'],
                duration=routine['total_duration']
            )

    async def start_js_tracking(self):
        js_code = """
        (function() {
            if ("geolocation" in navigator) {
                navigator.geolocation.watchPosition(
                    (position) => {
                        const lat = position.coords.latitude;
                        const lon = position.coords.longitude;
                        const bridge = document.querySelector('input[aria-label="gps_data_bridge"]');
                        if (bridge) {
                            bridge.value = lat + "," + lon;
                            bridge.dispatchEvent(new Event('input', { bubbles: true }));
                        }
                    },
                    (error) => { console.error("GPS Error:", error); },
                    { enableHighAccuracy: true, timeout: 5000, maximumAge: 0 }
                );
            }
        })();
        """
        # Flet 0.80.2 fallback and explicit await
        await self.page.launch_url(f"javascript:{js_code.replace('', '').replace('', '')}")

    def handle_js_gps(self, e):
        try:
            val = e.control.value
            if "," in val:
                lat_str, lon_str = val.split(",")
                lat = float(lat_str)
                lon = float(lon_str)
                if self.is_running:
                    self.gpstracker.update_position(lat, lon)
                    self.update_stats()
        except Exception as ex:
            print(f"GPS Parsing Error: {ex}")

    def update_stats(self):
        # Update distance
        self.dist_text.value = f"{self.gpstracker.total_distance:.2f} km"
        # Update pace
        pace_min_km = self.gpstracker.get_pace(self.seconds)
        if 0 < pace_min_km < 60: # Limit to sane values
            mins = int(pace_min_km)
            secs = int((pace_min_km - mins) * 60)
            self.pace_text.value = f"{mins}'{secs:02d}\"/km"
        else:
            self.pace_text.value = "0'00\"/km"
        self.update()

    def toggle_timer(self, e):
        if self.is_running:
            self.is_running = False
            self.play_button.icon = ft.icons.PLAY_CIRCLE_FILLED
            self.play_button.icon_color = "primary"
        else:
            self.is_running = True
            self.play_button.icon = ft.icons.PAUSE_CIRCLE_FILLED
            self.play_button.icon_color = ft.colors.RED_400
            
            # 오디오 시작 안내
            if self.audio_engine:
                self.audio_engine.play("start")
                
            # Start timer thread
            threading.Thread(target=self.run_timer, daemon=True).start()
        self.update()

    def run_timer(self):
        while self.is_running:
            mins, secs = divmod(self.seconds, 60)
            self.timer_text.value = f"{mins:02d}:{secs:02d}"
            self.update()
            
            # 코치 엔진 체크
            if self.audio_engine:
                current_pace = self.gpstracker.get_pace(self.seconds)
                # target_pace는 routine 데이터에서 가져올 수 있으나 현재는 7'00" (420초) 고정으로 가정
                self.audio_engine.check_coaching(
                    seconds=self.seconds,
                    distance=self.gpstracker.total_distance,
                    current_pace=current_pace * 60, # min/km -> sec/km
                    target_pace=420 # 7'00"
                )
            
            time.sleep(1)
            self.seconds += 1
            if self.seconds % 3 == 0: # Update stats more frequently
                self.update_stats()
                
            # 목표 시간 종료 체크 (간단 구현)
            if self.page.data and "current_routine" in self.page.data:
                if self.seconds >= self.page.data["current_routine"]["total_duration"]:
                    self.is_running = False
                    if self.audio_engine:
                        self.audio_engine.play("finish")
                    self.update()
                    break
