import math

def calculate_vdot(distance_m, time_sec):
    """
    Jack Daniels' VDOT Formula
    """
    velocity = distance_m / (time_sec / 60) # m/min
    t = time_sec / 60
    
    # VO2 Max Formula based on performance
    vo2 = (-4.60 + 0.182258 * velocity + 0.000104 * velocity**2) / (0.8 + 0.189439 * math.exp(-0.012778 * t) + 0.298955 * math.exp(-0.19326 * t))
    return round(vo2, 1)

def get_maf_hr(age, training_years=0):
    """
    Phil Maffetone's 180 Formula
    """
    base = 180 - age
    if training_years >= 2:
        base += 5
    elif training_years < 1:
        base -= 5
    return base

def get_bmi(height_cm, weight_kg):
    return weight_kg / ((height_cm / 100) ** 2)
