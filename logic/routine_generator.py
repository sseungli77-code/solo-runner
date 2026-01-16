def generate_routine(acwr_value, user_profile):
    """
    ACWR 값과 사용자 프로필 기반으로 개인맞춤형 루틴 생성
    """
    condition = '상' # 기본값
    level = user_profile.get("level", "beginner")
    
    steps = []
    audio_program = 'detail'
    
    # 1. 초보자 알고리즘 (BMI/나이 기반)
    if level == "beginner":
        bmi = user_profile.get("bmi", 22)
        if bmi > 25: # 과체중인 경우
            # 관절 보호를 위해 걷기 비중 대폭 강화 + 인터벌 제외
            steps = [('walk', 600), ('jog', 300), ('walk', 600)]
            audio_program = 'minimal'
        else:
            # 일반 초보자: 런-워크 인터벌로 심폐지구력 기초 확보
            steps = [('warm-up', 300), ('jog', 180), ('walk', 120), ('jog', 180), ('cool-down', 300)]
            audio_program = 'detail'
            
    # 2. 유경험자 알고리즘 (VDOT 기반)
    else:
        vdot = user_profile.get("vdot", 30)
        if acwr_value > 1.4:
            # 피로도 높음 -> 회복런
            steps = [('jog', 1200)]
            audio_program = 'minimal'
        elif vdot > 45:
            # 고수 -> 고강도 인터벌
            steps = [('warm-up', 600), ('run', 300), ('jog', 120), ('run', 300), ('cool-down', 600)]
            audio_program = 'detail'
        else:
            # 일반 중급자 -> 지속주
            steps = [('warm-up', 300), ('run', 900), ('cool-down', 300)]
            audio_program = 'detail'
        
    total_duration = sum(s[1] for s in steps)
    
    return {
        'steps': steps,
        'audio_program': audio_program,
        'total_duration': total_duration,
        'target_pace': 420 if level == "beginner" else 300 # 임시 고정값 (추후 VDOT 연동)
    }
