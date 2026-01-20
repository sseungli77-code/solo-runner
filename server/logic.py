
import google.generativeai as genai
from supabase import create_client, Client
import json
import os
import math

# --- AI & Cloud Config ---
# Security: Get keys from Environment Variables
GEMINI_KEY = os.environ.get("GEMINI_KEY")
SUPA_URL = os.environ.get("SUPA_URL", "https://cigtumbiljofgwnjeegu.supabase.co")
SUPA_KEY = os.environ.get("SUPA_KEY")


# ==========================================
# 1. Scientific Core: VDOT & Pacing
# ==========================================
def get_vdot_paces(race_10km_min):
    p10k = race_10km_min / 10.0 # min/km
    return {
        "E": p10k * 1.30, # Easy
        "M": p10k * 1.12, # Marathon
        "T": p10k * 1.04, # Threshold
        "I": p10k * 0.94, # Interval
        "R": p10k * 0.90  # Repetition
    }

def fmt_pace(p_val):
    m = int(p_val)
    s = int((p_val - m) * 60)
    return f"{m}'{s:02d}\""

# ==========================================
# 2. Logic Controller
# ==========================================
def generate_ai_comment(wk_total, level, bmi, weekly_vol, predicted_10km=None):
    try:
        genai.configure(api_key=GEMINI_KEY)
        model = genai.GenerativeModel('gemini-pro')
        
        # Determine trend based message
        trend_msg = ""
        if predicted_10km:
             trend_msg = f"현재 훈련 데이터 분석 결과, 예상 10km 기록은 {predicted_10km:.1f}분 입니다. "
        
        prompt = f"""
        당신은 스포츠 데이터 분석가입니다.
        사용자: {level}, BMI {bmi:.1f}, 주간 목표 {weekly_vol}분.
        {trend_msg}
        
        데이터 기반 피드백 (3줄):
        1. 현재 플랜의 특징 (ACSM 등 과학적 근거)
        2. 성장 예측 (데이터가 쌓이면 더 보여준다는 뉘앙스)
        3. 동기 부여 (미래 달성 예측 언급)
        """
        response = model.generate_content(prompt)
        return response.text
    except:
        return "데이터 기반 훈련 플랜입니다. 기록이 쌓이면 완주 시간을 예측해드립니다."

def save_plan_to_cloud(level_key, plan_data):
    try:
        supabase: Client = create_client(SUPA_URL, SUPA_KEY)
        data = {"user_level": level_key, "plan_data": plan_data}
        supabase.table("plans").insert(data).execute()
    except Exception as e:
        print(f"Cloud Error: {e}")

# ==========================================
# 3. New Analysis Engine
# ==========================================
def analyze_logs_and_predict(logs, current_10km_rec):
    # Logs are empty initially
    if not logs:
        return current_10km_rec, [], "첫 훈련을 완료하면 분석이 시작됩니다."

    # (Logic for actual logs would go here)
    predicted_rec = current_10km_rec * 0.99 
    
    trend_data = []
    # logic to populate trend_data from logs...
    
    analysis_text = f"현재 페이스가 매우 좋습니다!"
    
    return predicted_rec, trend_data, analysis_text

def generate_plan_core(level_key, pace_10km, user_weekly_min, height_cm, weight_kg):
    # --- A. Data Normalization ---
    height_m = height_cm / 100.0
    bmi = weight_kg / (height_m * height_m)
    
    # Volume Scaling
    ref_min = {"beginner": 120, "intermediate": 180, "advanced": 300}[level_key]
    vol_scale = user_weekly_min / ref_min
    if vol_scale > 1.3: vol_scale = 1.3 
    if vol_scale < 0.6: vol_scale = 0.6 

    # --- B. Scientific Adaptation (ACSM Guidelines) ---
    method_mod = "Continuous"
    message = "Standard Training"
    risk_level = "SAFE"
    
    # Pace Adjustment based on BMI (Direct Pace Impact)
    pace_base = pace_10km
    
    if bmi >= 25:
        method_mod = "Run/Walk"
        pace_base *= 1.05 # 5% slower
        risk_level = "CAUTION"
        message = "ACSM Guideline: Run/Walk Method applied."
        
    if bmi >= 30:
        method_mod = "Walk/Jog"
        pace_base *= 1.15 # 15% slower
        vol_scale *= 0.8 
        risk_level = "HIGH"
        message = "ACSM Guideline: Low Impact Volume adapted."

    paces = get_vdot_paces(pace_base * 10.0 if pace_base < 10 else pace_base)

    # --- C. Plan Generation ---
    plan_weeks = []
    
    total_weeks = 12 if level_key == "beginner" else 24 if level_key == "intermediate" else 48
    base_dist_wk = (15.0 if level_key=="beginner" else 30.0 if level_key=="intermediate" else 50.0) * vol_scale
    
    for wk in range(1, total_weeks + 1):
        phase = "Training"
        # Simplified generation for all levels to ensure robustness
        # Applying Periodization
        cycle = (wk-1)%4
        load = [0.9, 1.0, 1.1, 0.6][cycle]
        if wk > total_weeks - 2: load = 0.5 # Taper
        
        wk_dist = base_dist_wk * (1 + wk*0.02) * load
        
        # Schedule Template
        d_ratios = [0, 0.25, 0, 0.25, 0, 0, 0.50]
        type_map = ["Rest", "Easy", "Rest", "Easy", "Rest", "Rest", "LSD"]
        
        runs = []
        for i, r in enumerate(d_ratios):
            dd = round(wk_dist * r, 1)
            t = type_map[i]
            p_val = paces["E"]
            
            desc = t
            if dd > 0:
                if method_mod == "Run/Walk": desc = f"{t} (3min Run / 2min Walk)"
                elif method_mod == "Walk/Jog": desc = f"{t} (Jog 1min / Walk 4min)"
                else: desc = f"{t} Run"
            
            runs.append({
                "day_nm": ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][i],
                "type": t,
                "dist": dd,
                "pace": p_val if dd > 0 else 0,
                "p_str": fmt_pace(p_val) if dd > 0 else "-",
                "desc": desc
            })
            
        # Helper for volume/intensity display
        vol_str = f"{int(wk_dist * paces['E'])}~{int(wk_dist * paces['M'])}" # rough min estimate
        
        plan_weeks.append({
            "week": wk, 
            "schedule": runs, 
            "phase": phase, 
            "focus": f"{phase} Phase",  # Fix KeyError: focus
            "volume": vol_str,        # Fix potential KeyError
            "intensity": "Low" if wk < 4 else "Moderate", # safe default
            "total_km": round(wk_dist, 1)
        })

    # --- D. Analysis & Prediction ---
    # In V1, we simulate initial prediction based on profile
    rec_time = pace_10km * 10.0 if pace_10km < 10 else pace_10km
    pred_rec, trend_data, analysis_txt = analyze_logs_and_predict([], rec_time)
    
    # Calc Times
    for w in plan_weeks:
        for r in w["schedule"]:
            if r['dist'] > 0: r['time'] = int(r['dist'] * r['pace'])
            else: r['time'] = 0

    ai_msg = generate_ai_comment(total_weeks, level_key, bmi, user_weekly_min, pred_rec)
    save_plan_to_cloud(level_key, plan_weeks)
    
    # Return enriched response including trend data for charts
    response_data = {
        "plan": plan_weeks,
        "total_weeks": total_weeks,
        "bmi": bmi,
        "risk_level": risk_level,
        "message": f"{message} | {ai_msg}",
        "analysis": {
            "prediction_text": analysis_txt,
            "trend_data": trend_data,
            "predicted_record": pred_rec
        }
    }
    
    return response_data # New Return Structure
