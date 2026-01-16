import flet as ft
import os
import math
import time
import threading
from datetime import datetime, timedelta
# Import Logic Directly (Monolithic Architecture)
from server.logic import generate_plan_core, analyze_logs_and_predict

# ==========================================
# 1. State Management (Global for MVP)
# ==========================================
state = {
    "full_plan": [], 
    "current_run": None,
    "run_logs": {},
    "is_running": False,
    "seconds": 0,
    "last_feedback_time": 0
}

# ==========================================
# 2. Helper Functions
# ==========================================
def calculate_pace(seconds, km):
    if km <= 0: return "0'00\""
    pace_min = (seconds / 60) / km
    m = int(pace_min)
    s = int((pace_min - m) * 60)
    return f"{m}'{s:02d}\""

def speak(text):
    # Minimal TTS Stub for Web
    # In a real deployed web app, use window.speechSynthesis via page.launch_url(javascript)
    # But strictly speaking, doing that from a background thread is tricky.
    # We will skip active implementation to prevent errors, or just print log.
    print(f"[TTS] {text}")

# ==========================================
# 3. Main App
# ==========================================

def main(page: ft.Page):
    page.title = "SoloRunner AI"
    page.theme_mode = ft.ThemeMode.DARK
    page.theme = ft.Theme(color_scheme_seed="teal")
    page.padding = 0
    # page.scroll = "adaptive"
    
    # --- Navigation Logic ---
    def switch_to(view_key):
        page.clean()
        
        # Bottom Nav Component
        nav = ft.NavigationBar(
            selected_index={"set":0, "run":1, "plan":2}.get(view_key, 0),
            destinations=[
                ft.NavigationDestination(icon=ft.icons.SETTINGS, label="Setup"),
                ft.NavigationDestination(icon=ft.icons.DIRECTIONS_RUN, label="Run"),
                ft.NavigationDestination(icon=ft.icons.CALENDAR_MONTH, label="Plan"),
            ],
            on_change=lambda e: switch_to(["set", "run", "plan"][e.control.selected_index])
        )

        content = None
        if view_key == "set": content = view_set
        elif view_key == "plan": content = view_log
        elif view_key == "run": 
            # GPS JS Hook
            js = """
            navigator.geolocation.watchPosition(pos => {
                var inputs = document.querySelectorAll('input');
                var last = inputs[inputs.length - 1];
                if(last) {
                    last.value = pos.coords.latitude + "," + pos.coords.longitude;
                    last.dispatchEvent(new Event('input', {bubbles:true}));
                }
            }, null, {enableHighAccuracy:true});
            window.speechSynthesis.cancel();
            """
            page.launch_url(f"javascript:{js}")
            content = view_run
            
        page.add(ft.Column([content, nav], expand=True))
        page.update()

    # --- VIEWS ---

    # 1. SETUP VIEW
    tf_height = ft.TextField(label="키 (cm)", value="175", width=120, border_radius=10)
    tf_weight = ft.TextField(label="체중 (kg)", value="70", width=120, border_radius=10)
    tf_weekly = ft.TextField(label="주간 훈련량(분)", value="120", width=150, border_radius=10)
    tf_record_10km = ft.TextField(label="10km 기록(분)", value="60", width=150, border_radius=10)
    
    rg_level = ft.RadioGroup(content=ft.Column([
        ft.Radio(value="beginner", label="12주 10km 완주 (입문)"),
        ft.Radio(value="intermediate", label="24주 하프 마라톤 (중급)"),
        ft.Radio(value="advanced", label="48주 풀 코스 (고급)"),
    ]))
    rg_level.value = "beginner"

    def on_gen(e):
        if not all([tf_height.value, tf_weight.value, tf_weekly.value]):
            page.snack_bar = ft.SnackBar(ft.Text("모든 정보를 입력해주세요!"))
            page.snack_bar.open = True
            page.update()
            return

        btn_gen.disabled = True
        btn_gen.text = "AI가 플랜을 설계 중입니다..."
        page.update()
        
        try:
            # Call Logic Directly (Monolithic)
            h = float(tf_height.value)
            w = float(tf_weight.value)
            rec = float(tf_record_10km.value) if tf_record_10km.value else 60.0
            weekly = int(tf_weekly.value)
            lvl = rg_level.value
            
            # Direct Function Call
            response_data = generate_plan_core(lvl, rec, weekly, h, w)
            
            # Store to state
            state["full_plan"] = response_data["plan"]
            state["analysis"] = response_data.get("analysis")
            
            page.snack_bar = ft.SnackBar(ft.Text(f"✅ {response_data['message']}"))
            page.snack_bar.open = True
            
            build_log_view()
            switch_to("plan")
            
        except Exception as err:
            print(f"Error: {err}")
            page.snack_bar = ft.SnackBar(ft.Text(f"오류 발생: {str(err)}"))
            page.snack_bar.open = True
        
        btn_gen.disabled = False
        btn_gen.text = "AI 플랜 생성하기"
        page.update()

    btn_gen = ft.ElevatedButton("AI 플랜 생성하기", on_click=on_gen, 
                                style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=10), padding=20),
                                width=200)

    # --- RESTORED MODERN UI ---
    view_set = ft.Container(
        expand=True,
        gradient=ft.LinearGradient(colors=["blueGrey900", "black"], begin=ft.Alignment(0, -1), end=ft.Alignment(0, 1)),
        alignment=ft.Alignment(0,0),
        content=ft.Container(
            padding=30,
            border_radius=20,
            border=ft.border.all(1, "white24"),
            bgcolor=ft.colors.with_opacity(0.1, "white"),
            content=ft.Column([
                ft.Text("SOLO RUNNER", size=40, weight="bold", color="white"),
                ft.Text("과학적인 맞춤형 러닝 플랜", size=14, color="white70"),
                ft.Divider(color="transparent", height=20),
                ft.Row([tf_height, tf_weight], alignment="center"),
                ft.Row([tf_weekly, tf_record_10km], alignment="center"),
                ft.Container(
                    bgcolor=ft.colors.with_opacity(0.05, "white"),
                    padding=10, border_radius=10,
                    content=rg_level
                ),
                ft.Divider(color="transparent", height=20),
                btn_gen
            ], horizontal_alignment="center", scroll="auto")
        )
    )

    # 2. LOG VIEW
    col_log_content = ft.Column(scroll="auto", expand=True) # Main scrollable container

    def select_run(wk_idx, day_idx, run_data):
        if run_data["type"] == "Rest": return
        state["current_run"] = run_data
        state["current_log_key"] = f"{wk_idx}-{day_idx}"
        
        txt_run_title.value = f"Week {wk_idx} : {run_data['day_nm']}"
        txt_run_target.value = f"{run_data['type']} {run_data['dist']}km"
        txt_run_desc.value = f"{run_data['desc']} (목표 페이스: {run_data['p_str']})"
        pb_dist.value = 0
        switch_to("run")
        speak(f"오늘의 훈련은 {run_data['desc']} 입니다. 준비되시면 시작 버튼을 누르세요.")

    def build_log_view():
        col_log_content.controls.clear()
        
        # 1) Analysis & Prediction Section
        if state.get("analysis"):
            # Simple Chart (Bar)
            trend_data = state["analysis"].get("trend", [])
            pred_text = f"예상 10km 기록: {state['analysis'].get('predicted_10km', 0):.1f}분"
            
            # Simple Bar Chart creation using Containers
            bars = []
            if trend_data:
                # Normalize for height 100
                max_val = max(trend_data) if max(trend_data) > 0 else 1
                for val in trend_data:
                    bar_height = (val / max_val) * 80
                    # Color based on improvement (lower is better for pace, but let's just use simple logic)
                    bars.append(
                        ft.Column([
                            ft.Container(
                                width=10, height=bar_height,
                                bgcolor="tealAccent",
                                border_radius=5,
                                animate=ft.Animation(1000, "easeOut"),
                            ),
                            ft.Container(height=5)
                        ], alignment=ft.MainAxisAlignment.END)
                    )
            else:
                 # Dummy visualization for empty state
                 for i in range(1, 13, 2):
                     bars.append(
                        ft.Column([
                            ft.Container(width=10, height=1, bgcolor="white10"), # Tiny dot
                            ft.Text(f"W{i}", size=8, color="grey")
                        ], alignment=ft.MainAxisAlignment.END, spacing=2)
                     )

            controls = []
            controls.append(
                ft.Container(
                    height=200, padding=20,
                    border=ft.border.all(1, "white12"),
                    border_radius=10,
                    content=ft.Column([
                        ft.Text("Estimated Goal Trajectory", size=12, color="grey"), # Renamed Title
                        ft.Row(bars, alignment="spaceEvenly", height=100),
                        ft.Text("훈련이 지속될수록 완주 시간이 단축됩니다.", size=10, color="grey")
                    ])
                )
            )

            # Analysis Text
            controls.append(
                ft.Container(
                    margin=10, padding=15, border_radius=10,
                    bgcolor=ft.colors.with_opacity(0.1, "teal"),
                    border=ft.border.only(left=ft.BorderSide(4, "teal")),
                    content=ft.Column([
                        ft.Text("AI ANALYTICS", size=12, color="teal"),
                        ft.Text(pred_text, size=14),
                        ft.Text(state["analysis"].get("comment", ""), size=12, color="white70")
                    ])
                )
            )
            
            col_log_content.controls.extend(controls)

        # 2) Plan List
        plan = state.get("full_plan", [])
        for wk in plan:
            wk_num = wk["week"]
            week_data = wk
            
            # Week Card
            week_card = ft.ExpansionTile(
                title=ft.Text(f"WEEK {wk_num} - {week_data['focus']}", weight="bold"),
                subtitle=ft.Text(f"주간 목표: {week_data['volume']}분 / 강도: {week_data['intensity']}"),
                controls=[]
            )
            
            # Days
            row_controls = []
            for i, day in enumerate(week_data["schedule"]):
                is_done = f"{wk_num}-{i}" in state["run_logs"]
                card_color = "grey900" if day['type'] != 'Rest' else "white10"
                if is_done: card_color = "green900"
                
                card = ft.Container(
                    width=90, height=110,
                    bgcolor=card_color,
                    border_radius=10,
                    padding=10,
                    on_click=lambda e, w=wk_num, d=i, r=day: select_run(w, d, r),
                    content=ft.Column([
                        ft.Text(day['day_nm'], size=12, color="grey"),
                        ft.Text(day['type'], size=14, weight="bold"),
                        ft.Text(f"{day['dist']}k", size=12),
                        ft.Icon(ft.icons.CHECK_CIRCLE, size=16, color="green", visible=is_done)
                    ], alignment="spaceBetween")
                )
                row_controls.append(card)
            
            # Wrap rows for mobile
            week_card.controls.append(
                ft.Container(
                    padding=10,
                    content=ft.Row(row_controls, wrap=True, spacing=10, run_spacing=10)
                )
            )
            
            col_log_content.controls.append(week_card)
        
        col_log_content.update()

    view_log = ft.Container(
        expand=True,
        gradient=ft.LinearGradient(colors=["grey900", "black"], begin=ft.Alignment(0, -1), end=ft.Alignment(0, 1)),
        content=col_log_content
    )

    # 3. RUN VIEW (Modern & Safe)
    txt_run_title = ft.Text("READY", size=16, weight="bold")
    txt_run_target = ft.Text("-", size=30, weight="bold", color="tealAccent")
    txt_run_desc = ft.Text("-", color="white70")
    
    txt_timer = ft.Text("00:00", size=80, weight="bold", font_family="monospace", color="white")
    txt_stats = ft.Text("0.00 km | 0'00\"/km", size=18, color="white60")
    pb_dist = ft.ProgressBar(width=300, value=0, color="teal")
    
    btn_play = ft.IconButton(ft.icons.PLAY_CIRCLE_FILLED, icon_size=100, icon_color="teal400")
    btn_finish = ft.ElevatedButton("훈련 저장", visible=False, bgcolor="green700", color="white")

    def finish_run(e):
        key = state.get("current_log_key")
        if not key: return
        
        # Stop Timer
        state["is_running"] = False
        
        # Save Log
        log_data = {
            "date": str(datetime.now().date()),
            "dist": state.get("current_run", {}).get("dist", 0),
            "time": state["seconds"], # seconds
            "pace": calculate_pace(state["seconds"], state.get("current_run", {}).get("dist", 1))
        }
        
        # Local State
        state["run_logs"][key] = log_data
        
        # Cloud Save Stub
        def upload():
            try: pass 
            except: pass
        threading.Thread(target=upload).start()
        
        page.snack_bar = ft.SnackBar(ft.Text("훈련 기록이 저장되었습니다!"))
        page.snack_bar.open = True
        
        build_log_view()
        switch_to("plan")
        page.update()

    # Audio Feedback Loop
    def timer_loop():
        while True:
            if state["is_running"]:
                state["seconds"] += 1
                
                # Update Timer Text
                m = state["seconds"] // 60
                s = state["seconds"] % 60
                txt_timer.value = f"{m:02d}:{s:02d}"
                
                # Mock GPS
                total_km = state.get("current_run", {}).get("dist", 5)
                mock_dist_km = (state["seconds"] * 3.0) / 1000.0
                if mock_dist_km > total_km: mock_dist_km = total_km
                
                pb_dist.value = min(mock_dist_km / total_km, 1.0)
                
                # Pace
                pace = calculate_pace(state["seconds"], mock_dist_km)
                txt_stats.value = f"{mock_dist_km:.2f} km | {pace}/km"
                
                page.update()
                
                # Audio Coach (Every 60s)
                if state["seconds"] % 60 == 0:
                     speak(f"현재 페이스 {pace}입니다. 화이팅!")
                     
            time.sleep(1)

    # Start Timer Thread
    threading.Thread(target=timer_loop, daemon=True).start()

    def toggle_run(e):
        state["is_running"] = not state["is_running"]
        btn_play.icon = ft.icons.PAUSE_CIRCLE_FILLED if state["is_running"] else ft.icons.PLAY_CIRCLE_FILLED
        btn_play.icon_color = "red400" if state["is_running"] else "teal400"
        btn_finish.visible = not state["is_running"]
        page.update()
        
        if state["is_running"]:
            speak("훈련을 시작합니다.")

    btn_play.on_click = toggle_run

    view_run = ft.Container(
        gradient=ft.RadialGradient(colors=["blueGrey900", "black"], radius=2),
        alignment=ft.Alignment(0,0),
        content=ft.Column([
            ft.Container(height=40),
            txt_run_title,
            txt_run_target,
            txt_run_desc,
            ft.Container(height=40),
            ft.Container(
                content=txt_timer, 
                padding=20, 
                border=ft.border.all(2, "teal700"),
                border_radius=100,
                shadow=ft.BoxShadow(spread_radius=1, blur_radius=20, color="teal900")
            ),
            ft.Container(height=20),
            txt_stats,
            pb_dist,
            ft.Container(height=40),
            ft.Row([btn_play, btn_finish], alignment="center", spacing=20)
        ], horizontal_alignment="center")
    )

    # Initial Load
    switch_to("set")

if __name__ == "__main__":
    # Render assigns a PORT env var, mostly 10000
    # We must listen on 0.0.0.0 to be accessible externally
    port = int(os.environ.get("PORT", 8098))
    print(f"Starting Flet App on port {port}...")
    ft.app(target=main, view=ft.AppView.WEB_BROWSER, port=port, host="0.0.0.0")
