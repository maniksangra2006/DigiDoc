import os
import sys

# Ensure backend directory is in python search path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fastapi.testclient import TestClient
from main import app, all_symptoms
from database import SessionLocal, engine, Base
import models

# Configure test environment variable to bypass signature verification
os.environ["VERIFY_FIREBASE_TOKEN"] = "False"

client = TestClient(app)

def setup_module(module):
    # Ensure tables are created
    Base.metadata.create_all(bind=engine)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "symptom_count" in data
    assert "model_loaded" in data

def test_user_sync_and_db():
    # Test synchronizing a patient user via developer mock token
    headers = {"Authorization": "Bearer dev-token-patient"}
    response = client.post("/api/auth/sync?role=patient", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "patient"
    assert data["email"] == "patient@example.com"
    assert data["id"] == "mock_patient_uid"

    # Verify database insertion
    db = SessionLocal()
    user = db.query(models.User).filter(models.User.id == "mock_patient_uid").first()
    assert user is not None
    assert user.email == "patient@example.com"
    db.close()

def test_doctor_profile_sync_and_nearby():
    # Sync a doctor user
    headers = {"Authorization": "Bearer dev-token-doctor-Migraine"}
    response = client.post("/api/auth/sync?role=doctor&specialty=Migraine", headers=headers)
    assert response.status_code == 200

    # Update doctor coordinates & availability
    profile_data = {
        "specialty": "Migraine",
        "latitude": 28.6139,  # New Delhi
        "longitude": 77.2090,
        "is_available": True,
        "availability_schedule": "Mon-Fri 10:00 AM - 4:00 PM"
    }
    response = client.put("/api/doctor/profile", headers=headers, json=profile_data)
    assert response.status_code == 200
    data = response.json()
    assert data["specialty"] == "Migraine"
    assert data["latitude"] == 28.6139
    assert data["availability_schedule"] == "Mon-Fri 10:00 AM - 4:00 PM"

    # Query nearby doctors - patient located 1 km away (latitude + 0.005)
    patient_lat = 28.6139 + 0.005
    patient_lon = 77.2090
    response = client.get(
        f"/api/doctors/nearby?latitude={patient_lat}&longitude={patient_lon}&specialty=Migraine&radius=5.0"
    )
    assert response.status_code == 200
    nearby = response.json()
    assert len(nearby) > 0
    assert nearby[0]["user_id"] == "mock_doctor_uid"
    assert nearby[0]["distance"] < 1.0  # Should be around ~0.55 km

def test_prediction():
    # Formulate mock symptom dict (select headache, acidity, chills as 1, rest 0)
    symptoms = {s: 0 for s in all_symptoms}
    if all_symptoms:
        symptoms[all_symptoms[0]] = 1
        symptoms[all_symptoms[1]] = 1

    headers = {"Authorization": "Bearer dev-token-patient"}
    response = client.post("/api/predict", headers=headers, json={"symptoms": symptoms})
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "disease" in data
    assert data["history_id"] is not None

    # Verify history logged in DB
    db = SessionLocal()
    history = db.query(models.PredictionHistory).filter(models.PredictionHistory.id == data["history_id"]).first()
    assert history is not None
    assert history.predicted_disease == data["disease"]
    db.close()

if __name__ == "__main__":
    print("Running local API logic tests...")
    setup_module(None)
    test_health()
    print("Health check: PASS ✅")
    test_user_sync_and_db()
    print("User Sync / Database: PASS ✅")
    test_doctor_profile_sync_and_nearby()
    print("Doctor Profile / Nearby Haversine Lookup: PASS ✅")
    test_prediction()
    print("ML Predict & History Storage: PASS ✅")
    print("All tests completed successfully! 🎉")
