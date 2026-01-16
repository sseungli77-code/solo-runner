import flet as ft

class AudioEngine:
    def __init__(self, page: ft.Page):
        self.page = page
        # Web 환경에서는 /audio/... 경로가 바로 서빙됩니다 (assets_dir="assets" 설정 덕분)
        self.assets_path = "/audio"
        self.audio_files = {
            "start": "start.mp3",
            "finish": "finish.mp3",
            "halfway": "halfway.mp3",
            "last_1km": "last_1km.mp3",
            "faster": "faster.mp3",
            "slower": "slower.mp3",
            "good_pace": "good_pace.mp3",
            "acwr_warning": "warning_fatigue.mp3"
        }
            
        self.current_program = None
        self.program_data = {} # { 'mode': 'minimal' or 'detail', 'duration': seconds }
        self.played_cues = set()

    def set_program(self, mode, duration):
        self.current_program = mode
        self.program_data = {'mode': mode, 'duration': duration}
        self.played_cues = set()

    def check_coaching(self, seconds, distance, current_pace, target_pace):
        """
        실시간 데이터를 기반으로 코칭 멘트 송출 여부 결정
        """
        if not self.current_program:
            return

        # 1. 공통 마일스톤
        if seconds == int(self.program_data['duration'] / 2) and "halfway" not in self.played_cues:
            self.play("halfway")
            self.played_cues.add("halfway")
            
        # 2. 상세 코칭 모드 (Detail) 전용 로직
        if self.current_program == 'detail':
            # 매 5분 정기 알림
            if seconds > 0 and seconds % 300 == 0 and f"time_{seconds}" not in self.played_cues:
                self.played_cues.add(f"time_{seconds}")
                # 5분 알림용 별도 오디오가 없다면 현재는 생략하거나 halfway 등을 재활용
                
            # 페이스 체크 (목표 대비 오차 감지)
            if seconds > 60 and seconds % 60 == 0: # 1분마다 체크
                pace_diff = current_pace - target_pace
                if pace_diff > 30: # 30초 이상 느릴 때 (pace_diff가 양수면 느린 것)
                    self.play("faster")
                elif pace_diff < -30: # 30초 이상 빠를 때
                    self.play("slower")

    def play(self, key):
        if key in self.audio_files:
            filename = self.audio_files[key]
            audio_url = f"{self.assets_path}/{filename}"
            
            # JS Bridge: 브라우저의 원시 Audio 객체를 사용하여 재생
            js_code = f"(function(){{ new Audio('{audio_url}').play(); }})();"
            self.page.launch_url(f"javascript:{js_code}")
