import flet as ft
import math
import time
import threading

# ==========================================
# 1. Logic: Periodization Generator (Scientific)
# ==========================================

import requests

# ==========================================
# 1. Logic: Migrated to Server (Dumb Client)
# ==========================================

# Local logic removed. Client will query: POST http://localhost:8000/generate

class GPSTracker:
    def __init__(self):
        self.points = []
        self.total_distance = 0.0
    def update_position(self, lat, lon):
        now = time.time()
        self.points.append((lat, lon, now))
        if len(self.points) > 1:
            prev_lat, prev_lon, _ = self.points[-2]
            dist = self.haversine_distance(prev_lat, prev_lon, lat, lon)
            if dist > 0.003: self.total_distance += dist
    def haversine_distance(self, lat1, lon1, lat2, lon2):
        R = 6371.0 
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c
    def get_pace(self, elapsed_seconds):
        if self.total_distance < 0.05: return 0.0
        return (elapsed_seconds / 60) / self.total_distance

# ==========================================
# 2. Main App
# ==========================================

def main(page: ft.Page):
    page.title = "SoloRunner AI"
    page.theme_mode = ft.ThemeMode.DARK
    page.theme = ft.Theme(color_scheme_seed=ft.Colors.TEAL)
    page.padding = 0
    # page.scroll = "adaptive"
    
    state = {
        "full_plan": [], 
        "current_run": None,
        "run_logs": {},
        "is_running": False,
        "seconds": 0,
        "last_feedback_time": 0
    }
    tracker = GPSTracker()

    def speak(text):
        try:
            # HTML5 TTS
            js = f"window.speechSynthesis.speak(new SpeechSynthesisUtterance('{text}'));"
            page.launch_url(f"javascript:{js}")
        except: pass

    def check_pace_feedback(current_seconds, current_dist_km):
        if not state["current_run"]: return
        if current_seconds < 60: return
        if (current_seconds - state["last_feedback_time"]) < 60: return
        
        target_pace = state["current_run"]["pace"]
        if target_pace == 0: return 

        if current_dist_km < 0.1: return
        current_pace_sec = current_seconds / current_dist_km 
        target_sec = target_pace * 60
        
        diff = current_pace_sec - target_sec
        
        if diff > 15: speak("속도가 느립니다")
        elif diff < -15: speak("속도가 빠릅니다")
        else: speak("페이스 좋습니다")
        state["last_feedback_time"] = current_seconds

    # --- UI COMPONENTS ---
    
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

# Import Logic Directly (Monolithic Architecture)
from server.logic import generate_plan_core, analyze_logs_and_predict

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
        gradient=ft.LinearGradient(colors=[ft.Colors.BLUE_GREY_900, ft.Colors.BLACK], begin=ft.Alignment(0, -1), end=ft.Alignment(0, 1)),
        alignment=ft.Alignment(0,0),
        content=ft.Container(
            padding=30,
            border_radius=20,
            border=ft.border.all(1, ft.Colors.WHITE24),
            bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.WHITE),
            content=ft.Column([
                ft.Text("SOLO RUNNER", size=40, weight="bold", color="white"),
                ft.Text("과학적인 맞춤형 러닝 플랜", size=14, color="white70"),
                ft.Divider(color="transparent", height=20),
                ft.Row([tf_height, tf_weight], alignment="center"),
                ft.Row([tf_weekly, tf_record_10km], alignment="center"),
                ft.Container(
                    bgcolor=ft.Colors.with_opacity(0.05, ft.Colors.WHITE),
                    padding=10, border_radius=10,
                    content=rg_level
                ),
                ft.Divider(color="transparent", height=20),
                btn_gen
            ], horizontal_alignment="center", scroll="auto")
        )
    )

    # 2. LOG VIEW
    # 2. LOG VIEW (Enhanced)
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
        controls = []
        
        # 1. Header
        controls.append(ft.Container(padding=20, content=ft.Text("TRAINING LOG", size=24, weight="bold")))

        analysis = state.get("analysis")
        
        # 2. Chart (Custom Bar Chart Implementation)
        # 2. Chart (Custom Bar Chart Implementation)
        # Always render the chart container, even if empty
        bars = []
        if analysis and analysis.get("trend_data"):
            max_y = 150 
            for d in analysis["trend_data"]:
                bar_height = (d["y"] / max_y) * 150 
                bars.append(
                    ft.Column([
                        ft.Container(
                            width=10, height=bar_height,
                            bgcolor=ft.Colors.TEAL_ACCENT,
                            border_radius=5,
                            animate=ft.Animation(1000, "easeOut"),
                        ),
                        ft.Text(f"W{d['x']}", size=8, color="grey")
                    ], alignment=ft.MainAxisAlignment.END, spacing=2)
                )
        else:
             # Empty Placeholder Bars (Ghost Bars)
             for i in range(1, 13, 2):
                 bars.append(
                    ft.Column([
                        ft.Container(width=10, height=1, bgcolor=ft.Colors.WHITE10), # Tiny dot
                        ft.Text(f"W{i}", size=8, color="grey")
                    ], alignment=ft.MainAxisAlignment.END, spacing=2)
                 )

        controls.append(
            ft.Container(
                height=200, padding=20,
                border=ft.border.all(1, ft.Colors.WHITE12),
                border_radius=10,
                content=ft.Column([
                    ft.Text("Estimated Goal Trajectory", size=12, color="grey"), # Renamed Title
                    ft.Row(
                        controls=bars,
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        vertical_alignment=ft.CrossAxisAlignment.END,
                    )
                ])
            )
        )
            
        # 3. Analysis Text
        if analysis:
            pred_text = analysis.get("prediction_text", "")
            # If no actual trend data, override the message for clarity
            if not analysis.get("trend_data"):
                pred_text = "런닝을 완료하면 기록 그래프와 정밀 분석이 시작됩니다."
                
            pred_rec = analysis.get("predicted_record", 0)
            
            controls.append(
                ft.Container(
                    margin=10, padding=15, border_radius=10,
                    bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.TEAL),
                    border=ft.border.only(left=ft.BorderSide(4, ft.Colors.TEAL)),
                    content=ft.Column([
                        ft.Text("AI ANALYTICS", size=12, color="teal"),
                        ft.Text(pred_text, size=14),
                        # Only show predicted numbers if we have data or prediction
                        ft.Text(f"🎯 예상 10km 기록: {int(pred_rec)}분", weight="bold", size=16, color="white") if pred_rec > 0 else ft.Container()
                    ])
                )
            )

        # 4. Plan List (Accordion for Week)
        if not state["full_plan"]:
            controls.append(ft.Container(padding=20, content=ft.Text("플랜을 먼저 생성해주세요.", color="grey")))
        else:
            # Show simplified view: Current Week + Next 3
            current_wk = 1 # Logic to track real week needed, default 1
            
            for week_data in state["full_plan"]:
                wk_num = week_data["week"]
                
                # Build Daily Cards
                row_controls = []
                for i, day in enumerate(week_data["schedule"]):
                    is_done = f"{wk_num}-{i}" in state["run_logs"]
                    card_color = ft.Colors.GREY_900 if day['type'] != 'Rest' else ft.Colors.BLACK12
                    if is_done: card_color = ft.Colors.GREEN_900
                    
                    card = ft.Container(
                        width=90, height=110,
                        bgcolor=card_color,
                        border_radius=8,
                        padding=5,
                        on_click=lambda e, w=wk_num, d=i, r=day: select_run(w, d, r) if r['dist']>0 else None,
                        content=ft.Column([
                            ft.Text(day['day_nm'], size=10, color="white54"),
                            ft.Icon(ft.Icons.CHECK_CIRCLE if is_done else ft.Icons.DIRECTIONS_RUN, size=20,
                                    color="green" if is_done else "white"),
                            ft.Text(f"{day['dist']}k", weight="bold", size=12),
                            ft.Text(day['type'][:4], size=9, color="white70") # Shorten
                        ], horizontal_alignment="center", alignment="center")
                    )
                    row_controls.append(card)

                # Expansion Tile for Week
                tile = ft.ExpansionTile(
                    title=ft.Text(f"Week {wk_num} - {week_data.get('phase')}", weight="bold"),
                    subtitle=ft.Text(f"Total: {week_data['total_km']}km", size=12, color="grey"),
                    controls=[
                        ft.Container(
                            height=130, 
                            padding=ft.padding.only(left=10, bottom=10),
                            content=ft.Row(row_controls, scroll="always")
                        )
                    ]
                )
                controls.append(tile)

        col_log_content.controls = controls
        try: col_log_content.update() 
        except: pass

    view_log = ft.Container(
        expand=True,
        gradient=ft.LinearGradient(colors=[ft.Colors.GREY_900, ft.Colors.BLACK], begin=ft.Alignment(0, -1), end=ft.Alignment(0, 1)),
        content=col_log_content
    )

    # 3. RUN VIEW (Modern)
    txt_run_title = ft.Text("READY", size=16, weight="bold")
    txt_run_target = ft.Text("-", size=30, weight="bold", color=ft.Colors.TEAL_ACCENT)
    txt_run_desc = ft.Text("-", color="white70")
    
    txt_timer = ft.Text("00:00", size=80, weight="bold", font_family="monospace", color=ft.Colors.WHITE)
    txt_stats = ft.Text("0.00 km | 0'00\"/km", size=18, color="white60")
    pb_dist = ft.ProgressBar(width=300, value=0, color=ft.Colors.TEAL)
    
    btn_play = ft.IconButton(ft.Icons.PLAY_CIRCLE_FILLED, icon_size=100, icon_color=ft.Colors.TEAL_400)
    btn_finish = ft.ElevatedButton("훈련 저장", visible=False, bgcolor=ft.Colors.GREEN_700, color="white")

    def finish_run(e):
        key = state.get("current_log_key")
        if key: state["run_logs"][key] = True
            
        state["is_running"] = False
        state["seconds"] = 0
        tracker.total_distance = 0.0
        txt_timer.value = "00:00"
        btn_play.icon = ft.Icons.PLAY_CIRCLE_FILLED
        btn_finish.visible = False
        
        build_log_view()
        switch_to("plan")
        page.snack_bar = ft.SnackBar(ft.Text("훈련이 저장되었습니다."))
        page.snack_bar.open = True
        page.update()

    btn_finish.on_click = finish_run

    def timer_loop():
        while state["is_running"]:
            time.sleep(1)
            state["seconds"] += 1
            m, s = divmod(state["seconds"], 60)
            txt_timer.value = f"{m:02d}:{s:02d}"
            
            # Progress Update
            if state["current_run"] and state["current_run"]["dist"] > 0:
                prog = tracker.total_distance / state["current_run"]["dist"]
                pb_dist.value = min(prog, 1.0)

            # Real-time Pace Coaching (Every 30s)
            if state["seconds"] % 30 == 0 and state["current_run"]:
                try:
                    target_p = state["current_run"]["pace"] # Target Pace (min/km)
                    current_dist = tracker.total_distance
                    
                    if current_dist > 0.05: # Analyzable distance (>50m)
                        # Current Pace in min/km
                        current_pace = (state["seconds"] / 60) / current_dist
                        
                        # Tolerance: +/- 10%
                        if current_pace > target_p * 1.1: # Too Slow (Number is bigger)
                            speak("페이스가 너무 느립니다. 속도를 올리세요!")
                        elif current_pace < target_p * 0.9: # Too Fast
                            speak("속도가 너무 빠릅니다. 조금 천천히 달리세요.")
                        elif state["seconds"] % 60 == 0: # Good pace (Every 1m)
                            speak(f"현재 페이스 좋습니다. {tracker.total_distance:.1f} 킬로미터.")
                except: pass
            
            try: page.update()
            except: break

    def toggle_run(e):
        if not state["current_run"]: return
        state["is_running"] = not state["is_running"]
        btn_play.icon = ft.Icons.PAUSE_CIRCLE_FILLED if state["is_running"] else ft.Icons.PLAY_CIRCLE_FILLED
        btn_finish.visible = not state["is_running"] and state["seconds"] > 10
        if state["is_running"]:
            btn_finish.visible = False
            threading.Thread(target=timer_loop, daemon=True).start()
        page.update()

    def on_gps(e):
        if state["is_running"] and "," in e.control.value:
            try:
                lat, lon = map(float, e.control.value.split(","))
                tracker.update_position(lat, lon)
                
                p = tracker.get_pace(state["seconds"])
                m = int(p); s = int((p-m)*60)
                
                txt_stats.value = f"{tracker.total_distance:.2f} km | {m}'{s:02d}\"/km"
                page.update()
            except: pass

    gps_bridge = ft.TextField(visible=False, on_change=on_gps)
    btn_play.on_click = toggle_run

    view_run = ft.Container(
        gradient=ft.RadialGradient(colors=[ft.Colors.BLUE_GREY_900, ft.Colors.BLACK], radius=2),
        alignment=ft.Alignment(0,0),
        content=ft.Column([
            ft.Container(height=40),
            txt_run_title,
            txt_run_target,
            txt_run_desc,
            ft.Divider(color="white24"),
            ft.Container(height=40),
            ft.Container(
                content=txt_timer, 
                padding=20, 
                border=ft.border.all(2, ft.Colors.TEAL_700),
                border_radius=100,
                shadow=ft.BoxShadow(spread_radius=1, blur_radius=20, color=ft.Colors.TEAL_900)
            ),
            ft.Container(height=20),
            txt_stats,
            pb_dist,
            ft.Container(height=40),
            btn_play,
            btn_finish,
            gps_bridge
        ], horizontal_alignment="center")
    )

    # 4. MANUAL NAVIGATION (ROUTER REPLACEMENT)
    
    def switch_to(view_key):
        page.clean()
        
        # Bottom Nav Component
        nav = ft.NavigationBar(
            selected_index={"set":0, "run":1, "plan":2}.get(view_key, 0),
            destinations=[
                ft.NavigationBarDestination(icon=ft.Icons.SETTINGS, label="Setup"),
                ft.NavigationBarDestination(icon=ft.Icons.DIRECTIONS_RUN, label="Run"),
                ft.NavigationBarDestination(icon=ft.Icons.CALENDAR_MONTH, label="Plan"),
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
            
        page.add(content)
        page.add(nav) # Add Nav separately to ensure it's at bottom if using Column, but here page adds vertically. 
        # Better: Page acts as Column. To stick Nav at bottom, we might need a different layout, 
        # but for now let's just add it. Flet Page defaults to Column.
        # To make it stick: Use a global Column with expand.
        
        # Refined Layout for Stability:
        # page.add(ft.Column([content, nav], expand=True)) # content needs expand=True
        
        page.update()

    # Initial Load
    switch_to("set")

if __name__ == "__main__":
    # Render assigns a PORT env var, mostly 10000
    # We must listen on 0.0.0.0 to be accessible externally
    port = int(os.environ.get("PORT", 8098))
    print(f"Starting Flet App on port {port}...")
    ft.app(target=main, view=ft.AppView.WEB_BROWSER, port=port, host="0.0.0.0")
