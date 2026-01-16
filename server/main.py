from fastapi import FastAPI, HTTPException
from server.models import RunProfile, PlanResponse, PredictionData
from server.logic import generate_plan_core
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# CORS for Client
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/generate", response_model=PlanResponse)
async def generate_plan(profile: RunProfile):
    try:
        # Calculate Logic
        result = generate_plan_core(
            profile.level,
            profile.record_10km, 
            profile.weekly_min,
            profile.height,
            profile.weight
        )
        
        return PlanResponse(
            plan=result["plan"],
            total_weeks=result["total_weeks"],
            bmi=result["bmi"],
            risk_level=result["risk_level"],
            message=result["message"],
            analysis=PredictionData(
                prediction_text=result["analysis"]["prediction_text"],
                trend_data=result["analysis"]["trend_data"],
                predicted_record=result["analysis"]["predicted_record"]
            )
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
def health_check():
    return {"status": "ok", "service": "SoloRunner Brain"}
