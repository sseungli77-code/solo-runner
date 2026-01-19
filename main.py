import flet as ft
import os
import math
import time
import threading
from datetime import datetime
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
    "last_feedback_time": 0,
    "current_dist": 0.0,
    "real_distance": 0.0,
    "last_pos": None,
    "current_log_key": None
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
    print(f"[TTS] {text}")

# ==========================================
# 3. Main App
# ==========================================

def main(page: ft.Page):
    # App Config
    page.title = "SoloRunner AI"
    page.theme_mode = ft.ThemeMode.DARK
    page.theme = ft.Theme(color_scheme_seed="teal")
    page.padding = 0
    # 스크롤은 각 Tab Content 내부에서 처리

    # --- Shared Refs for Navigation ---
    tabs_control = ft.Ref[ft.Tabs]()
    nav_bar = ft.Ref[ft.NavigationBar]()

    # --- Navigation Logic ---
    def go_to_tab(index: int):
        # Programmatic tab switch (e.g. from button)
        if tabs_control.current:
            tabs_control.current.selected_index = index
            nav_bar.current.selected_index = index
            page.update()
            
            if index == 1: # RUN TAB
                check_gps_hook()

    def on_nav_change(e):
        # Bottom Nav Clicked
        idx = e.control.selected_index
        if tabs_control.current:
            tabs_control.current.selected_index = idx
            page.update()
            if idx == 1: check_gps_hook()

    def on_tab_change(e):
        # Swipe or Tab Clicked
        idx = int(e.control.selected_index) # Flet sometimes sends string?
        if nav_bar.current:
            nav_bar.current.selected_index = idx
            page.update()
            if idx == 1: check_gps_hook()

    def check_gps_hook():
        # Inject GPS Logic when Run tab is active
        # We use a flag in window to avoid multiple listeners
        js = """
        if (!window.gpsHookActive) {
            window.gpsHookActive = true;
            navigator.geolocation.watchPosition(pos => {
                var inputs = document.querySelectorAll('input');
                // Broadcast to all inputs to be safe
                for(var i=0; i<inputs.length; i++) {
                     inputs[i].value = pos.coords.latitude + "," + pos.coords.longitude;
                     inputs[i].dispatchEvent(new Event('input', {bubbles:true}));
                }
            }, null, {enableHighAccuracy:true});
        }
        """
        page.launch_url(f"javascript:{js}")

    # =================================================================
    # VIEW COMPONENTS DEFINITIONS
    # =================================================================

    # --- 1. SETUP VIEW COMPONENTS ---
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

    btn_gen = ft.ElevatedButton("AI 플랜 생성하기", 
                                style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=10), padding=20),
                                width=200)

    # --- 2. LOG VIEW COMPONENTS ---
    col_log_content = ft.Column(scroll="auto", expand=True)

    # --- 3. RUN VIEW COMPONENTS ---
    txt_run_title = ft.Text("READY", size=16, weight="bold")
    txt_run_target = ft.Text("-", size=30, weight="bold", color="tealAccent")
    txt_run_desc = ft.Text("플랜에서 훈련을 선택하세요", color="white70")
    txt_timer = ft.Text("00:00", size=80, weight="bold", font_family="monospace", color="white")
    txt_stats = ft.Text("0.00 km | 0'00\"/km", size=18, color="white60")
    pb_dist = ft.ProgressBar(width=300, value=0, color="teal")
    btn_play = ft.IconButton(ft.icons.PLAY_CIRCLE_FILLED, icon_size=100, icon_color="teal400")
    btn_finish = ft.ElevatedButton("훈련 저장", visible=False, bgcolor="green700", color="white")
    gps_input = ft.TextField(visible=False)

    # =================================================================
    # LOGIC HANDLERS
    # =================================================================

    def build_log_view_content():
        col_log_content.controls.clear()
        
        # A. Analysis Section
        if state.get("analysis"):
            trend_data = state["analysis"].get("trend", [])
            pred_text = f"예상 10km: {state['analysis'].get('predicted_10km', 0):.1f}분"
            
            bars = []
            if trend_data:
                max_val = max(trend_data) if max(trend_data) > 0 else 1
                for val in trend_data:
                    bar_height = (val / max_val) * 80
                    bars.append(
                        ft.Column([
                            ft.Container(width=10, height=bar_height, bgcolor="tealAccent", border_radius=5),
                            ft.Container(height=5)
                        ], alignment=ft.MainAxisAlignment.END)
                    )
            else:
                 # 빈 그래프 (플레이스홀더)
                 for i in range(1, 13, 2):
                     bars.append(
                        ft.Column([
                            ft.Container(width=10, height=20, bgcolor="white10", border_radius=2),
                            ft.Text(f"W{i}", size=8, color="grey")
                        ], alignment=ft.MainAxisAlignment.END)
                     )

            col_log_content.controls.append(
                ft.Container(
                    height=200, padding=20,
                    border=ft.border.all(1, "white12"), border_radius=10,
                    content=ft.Column([
                        ft.Text("Performance Trend", size=12, color="grey"),
                        ft.Row(bars, alignment="spaceEvenly", height=120),
                        ft.Text("훈련이 지속될수록 기록이 향상됩니다.", size=10, color="grey")
                    ])
                )
            )
            col_log_content.controls.append(
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

        # B. Plan List
        plan = state.get("full_plan", [])
        for wk in plan:
            wk_num = wk["week"]
            week_data = wk
            
            week_card = ft.ExpansionTile(
                title=ft.Text(f"WEEK {wk_num} - {week_data['focus']}", weight="bold"),
                subtitle=ft.Text(f"Target: {week_data['volume']} min"),
                controls=[]
            )
            
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
                    on_click=lambda e, w=wk_num, d=i, r=day: on_select_run(w, d, r),
                    content=ft.Column([
                        ft.Text(day['day_nm'], size=12, color="grey"),
                        ft.Text(day['type'], size=14, weight="bold"),
                        ft.Text(f"{day['dist']}k", size=12),
                        ft.Icon(ft.icons.CHECK_CIRCLE, size=16, color="green", visible=is_done)
                    ], alignment="spaceBetween")
                )
                row_controls.append(card)
            
            week_card.controls.append(
                 ft.Container(padding=10, content=ft.Row(row_controls, wrap=True, spacing=10, run_spacing=10))
            )
            col_log_content.controls.append(week_card)
        
        page.update()

    def on_gen_click(e):
        if not all([tf_height.value, tf_weight.value, tf_weekly.value]):
            page.snack_bar = ft.SnackBar(ft.Text("모든 정보를 입력해주세요!"))
            page.snack_bar.open = True
            page.update()
            return

        btn_gen.disabled = True
        btn_gen.text = "AI 설계 중..."
        page.update()
        
        try:
            h = float(tf_height.value)
            w = float(tf_weight.value)
            rec = float(tf_record_10km.value) if tf_record_10km.value else 60.0
            weekly = int(tf_weekly.value)
            lvl = rg_level.value
            
            response_data = generate_plan_core(lvl, rec, weekly, h, w)
            state["full_plan"] = response_data["plan"]
            state["analysis"] = response_data.get("analysis")
            
            page.snack_bar = ft.SnackBar(ft.Text(f"✅ {response_data['message']}"))
            page.snack_bar.open = True
            
            build_log_view_content()
            go_to_tab(2) # 이동: PLAN
            
        except Exception as err:
            print(f"Error: {err}")
            page.snack_bar = ft.SnackBar(ft.Text(f"오류: {str(err)}"))
            page.snack_bar.open = True
        
        btn_gen.disabled = False
        btn_gen.text = "AI 플랜 생성하기"
        page.update()

    btn_gen.on_click = on_gen_click

    def on_select_run(wk_idx, day_idx, run_data):
        if run_data["type"] == "Rest": return
        state["current_run"] = run_data
        state["current_log_key"] = f"{wk_idx}-{day_idx}"
        
        txt_run_title.value = f"Week {wk_idx} : {run_data['day_nm']}"
        txt_run_target.value = f"{run_data['type']} {run_data['dist']}km"
        txt_run_desc.value = f"{run_data['desc']} (Target: {run_data['p_str']})"
        pb_dist.value = 0
        
        speak(f"오늘의 훈련: {run_data['desc']}")
        go_to_tab(1) # 이동: RUN

    def on_toggle_run(e):
        state["is_running"] = not state["is_running"]
        btn_play.icon = ft.icons.PAUSE_CIRCLE_FILLED if state["is_running"] else ft.icons.PLAY_CIRCLE_FILLED
        btn_play.icon_color = "red400" if state["is_running"] else "teal400"
        btn_finish.visible = not state["is_running"]
        
        if state["is_running"]:
             state["real_distance"] = 0.0
             state["current_dist"] = 0.0
             state["last_pos"] = None
             page.snack_bar = ft.SnackBar(ft.Text("🛰️ GPS 수신 시작... (움직여야 측정됩니다)"))
             page.snack_bar.open = True
        
        page.update()

    def on_finish_run(e):
        key = state.get("current_log_key")
        if not key: return
        
        state["is_running"] = False
        dist = state.get("current_run", {}).get("dist", 0)
        
        log_data = {
            "date": str(datetime.now().date()),
            "dist": dist,
            "time": state["seconds"],
            "pace": calculate_pace(state["seconds"], dist if dist > 0 else 1)
        }
        state["run_logs"][key] = log_data
        
        page.snack_bar = ft.SnackBar(ft.Text("훈련 저장 완료!"))
        page.snack_bar.open = True
        
        build_log_view_content()
        go_to_tab(2) # 이동: PLAN

    btn_play.on_click = on_toggle_run
    btn_finish.on_click = on_finish_run

    def on_gps_change(e):
        try:
            val = gps_input.value
            if not val or "," not in val: return
            lat, lon = map(float, val.split(","))
            
            if state.get("last_pos") is None:
                state["last_pos"] = (lat, lon)
                return

            last_lat, last_lon = state["last_pos"]
            # Haversine
            R = 6371.0
            dlat = math.radians(lat - last_lat)
            dlon = math.radians(lon - last_lon)
            a = math.sin(dlat/2)**2 + math.cos(math.radians(last_lat))*math.cos(math.radians(lat)) * math.sin(dlon/2)**2
            c = 2 * math.asin(math.sqrt(a))
            dist_km = R * c
            
            # Simple noise filter
            if 0.002 < dist_km < 0.05: 
                state["real_distance"] = state.get("real_distance", 0.0) + dist_km
                state["last_pos"] = (lat, lon)
            
            state["current_dist"] = state.get("real_distance", 0.0)

        except Exception as err:
            print(f"GPS Error: {err}")

    gps_input.on_change = on_gps_change


    # =================================================================
    # ASSEMBLE VIEWS
    # =================================================================
    
    # 1. Setup View Container
    view_set_content = ft.Container(
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

    # 2. Plan View Container (Wrapper)
    view_log_content = ft.Container(
        expand=True,
        gradient=ft.LinearGradient(colors=["grey900", "black"], begin=ft.Alignment(0, -1), end=ft.Alignment(0, 1)),
        content=col_log_content
    )

    # 3. Run View Container
    view_run_content = ft.Container(
        gradient=ft.RadialGradient(colors=["blueGrey900", "black"], radius=2),
        alignment=ft.Alignment(0,0),
        content=ft.Column([
            gps_input,
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


    # =================================================================
    # LAYOUT
    # =================================================================
    
    tabs_control.current = ft.Tabs(
        selected_index=0,
        animation_duration=300, # Slide Animation!
        on_change=on_tab_change,
        tabs=[
            ft.Tab(text="설정", icon=ft.icons.SETTINGS, content=view_set_content),
            ft.Tab(text="러닝", icon=ft.icons.DIRECTIONS_RUN, content=view_run_content),
            ft.Tab(text="플랜", icon=ft.icons.CALENDAR_MONTH, content=view_log_content),
        ],
        expand=True,
        divider_color="transparent",
        indicator_color="teal",
    )

    nav_bar.current = ft.NavigationBar(
        selected_index=0,
        destinations=[
            ft.NavigationDestination(icon=ft.icons.SETTINGS, label="Setup"),
            ft.NavigationDestination(icon=ft.icons.DIRECTIONS_RUN, label="Run"),
            ft.NavigationDestination(icon=ft.icons.CALENDAR_MONTH, label="Plan"),
        ],
        on_change=on_nav_change
    )

    page.add(
        ft.Column([
            tabs_control.current,
            nav_bar.current
        ], expand=True, spacing=0)
    )

    # =================================================================
    # TIMER TASK
    # =================================================================
    import asyncio
    async def run_timer_loop():
        while True:
            if state["is_running"]:
                try:
                    state["seconds"] += 1
                    m = state["seconds"] // 60
                    s = state["seconds"] % 60
                    txt_timer.value = f"{m:02d}:{s:02d}"
                    
                    current_km = state.get("current_dist", 0.0)
                    total_km = state.get("current_run", {}).get("dist", 5)
                    pb_dist.value = min(current_km / max(total_km, 0.1), 1.0)
                    
                    pace_val = (state["seconds"] / 60) / max(current_km, 0.001)
                    pm = int(pace_val)
                    ps = int((pace_val - pm) * 60)
                    pace_str = "-'--\"" if pm > 30 else f"{pm}'{ps:02d}\""
                    
                    txt_stats.value = f"{current_km:.2f} km | {pace_str}/km"
                    page.update()
                except: pass
            await asyncio.sleep(1)

    page.run_task(run_timer_loop)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8098))
    ft.app(target=main, view=ft.AppView.WEB_BROWSER, port=port, host="0.0.0.0")
