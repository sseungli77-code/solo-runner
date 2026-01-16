def calculate_acwr(recent_workload, chronic_workload_avg):
    """
    ACWR (Acute:Chronic Workload Ratio) 계산
    Formula: Acute Workload / Chronic Workload
    
    recent_workload: 이번 주 (최근 7일) 부하 합계
    chronic_workload_avg: 지난 4주 평균 주간 부하
    
    Return: (ACWR value, Status)
    """
    if chronic_workload_avg == 0:
        return 0, "No data"
        
    acwr = recent_workload / chronic_workload_avg
    
    if 0.8 <= acwr <= 1.3:
        status = "Safe (안전)"
    elif acwr > 1.5:
        status = "Danger (위험 - 부상 주의)"
    elif acwr < 0.8:
        status = "Under-training (운동량 부족)"
    else:
        status = "Warning (주의)"
        
    return round(acwr, 2), status
