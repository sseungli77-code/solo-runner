from pydantic import BaseModel
from typing import List, Optional

class RunProfile(BaseModel):
    height: float
    weight: float
    weekly_min: int
    record_10km: float
    level: str  # beginner, intermediate, advanced

class DailyRun(BaseModel):
    day_nm: str
    type: str # Easy, Rest, Tempo, LSD, Interval
    dist: float
    pace: float
    p_str: str
    desc: str
    time: int

class WeekPlan(BaseModel):
    week: int
    schedule: List[DailyRun]
    total_km: float
    phase: str

class PredictionData(BaseModel):
    prediction_text: str
    trend_data: List[dict] # [{"x": 1, "y": 100}, ...]
    predicted_record: float

class PlanResponse(BaseModel):
    plan: List[WeekPlan]
    total_weeks: int
    bmi: float
    risk_level: str
    message: str
    analysis: Optional[PredictionData] = None
