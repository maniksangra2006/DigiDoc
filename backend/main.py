import os
import pickle
import math
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List, Dict, Optional

from database import engine, get_db
import models
import schemas
import auth

# Auto-migrate database tables on launch
models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="DigiDoc API", 
    description="FastAPI backend with PostgreSQL/SQLite database support and ML disease prediction"
)

# CORS middleware for Flutter clients (Mobile & Web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load ML model components
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(CURRENT_DIR, "model.pkl")
SYMPTOMS_PATH = os.path.join(CURRENT_DIR, "symptoms.pkl")

try:
    model = pickle.load(open(MODEL_PATH, "rb"))
    all_symptoms = pickle.load(open(SYMPTOMS_PATH, "rb"))
except Exception as e:
    print(f"Warning: Could not load ML model from {MODEL_PATH}: {e}")
    model = None
    all_symptoms = []

# Simple memory fallback to support legacy GET /predict requests
_legacy_prediction_store = {}

@app.get("/health")
def health():
    return {
        "status": "ok", 
        "symptom_count": len(all_symptoms), 
        "model_loaded": model is not None
    }

@app.post("/api/auth/sync", response_model=schemas.UserResponse)
def sync_user(
    role: Optional[str] = None,
    specialty: Optional[str] = None,
    token_data: dict = Depends(auth.verify_token),
    db: Session = Depends(get_db)
):
    uid = token_data.get("uid")
    email = token_data.get("email", "")
    name = token_data.get("name", "User")
    picture = token_data.get("picture")

    # In dev mode, verify_token might parse role/specialty directly
    inferred_role = role or token_data.get("role") or "patient"
    inferred_spec = specialty or token_data.get("specialty")

    user = db.query(models.User).filter(models.User.id == uid).first()
    if not user:
        user = models.User(
            id=uid,
            email=email,
            name=name,
            role=inferred_role,
            profile_pic=picture
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        # Sync values that may have updated on Google
        user.name = name
        user.profile_pic = picture or user.profile_pic
        # Only overwrite role if not already registered in database
        if role and not user.role:
            user.role = role
        db.commit()
        db.refresh(user)

    # Automatically set up standard doctor profile if role matches
    if user.role == "doctor":
        doc_profile = db.query(models.DoctorProfile).filter(models.DoctorProfile.user_id == uid).first()
        if not doc_profile:
            doc_profile = models.DoctorProfile(
                user_id=uid,
                specialty=inferred_spec or "General Medicine",
                is_available=True
            )
            db.add(doc_profile)
            db.commit()
        elif inferred_spec:
            doc_profile.specialty = inferred_spec
            db.commit()

    specialty_name = None
    if user.role == "doctor":
        doc_profile = db.query(models.DoctorProfile).filter(models.DoctorProfile.user_id == uid).first()
        if doc_profile:
            specialty_name = doc_profile.specialty

    return schemas.UserResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        role=user.role,
        profile_pic=user.profile_pic,
        created_at=user.created_at,
        specialty=specialty_name
    )

@app.put("/api/doctor/profile", response_model=schemas.DoctorProfileResponse)
def update_doctor_profile(
    profile_data: schemas.DoctorProfileUpdate,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    if current_user.role != "doctor":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="Only authenticated doctors can register clinics or update specialties."
        )

    doc_profile = db.query(models.DoctorProfile).filter(models.DoctorProfile.user_id == current_user.id).first()
    if not doc_profile:
        doc_profile = models.DoctorProfile(user_id=current_user.id)
        db.add(doc_profile)

    doc_profile.specialty = profile_data.specialty
    doc_profile.latitude = profile_data.latitude
    doc_profile.longitude = profile_data.longitude
    doc_profile.is_available = profile_data.is_available
    doc_profile.availability_schedule = profile_data.availability_schedule
    
    if profile_data.clinic_name is not None:
        doc_profile.clinic_name = profile_data.clinic_name
    if profile_data.address is not None:
        doc_profile.address = profile_data.address
    if profile_data.phone is not None:
        doc_profile.phone = profile_data.phone
    if profile_data.rating is not None:
        doc_profile.rating = profile_data.rating
    if profile_data.reviews_count is not None:
        doc_profile.reviews_count = profile_data.reviews_count
    if profile_data.consultation_fee is not None:
        doc_profile.consultation_fee = profile_data.consultation_fee

    db.commit()
    db.refresh(doc_profile)

    return schemas.DoctorProfileResponse(
        user_id=doc_profile.user_id,
        specialty=doc_profile.specialty,
        latitude=doc_profile.latitude,
        longitude=doc_profile.longitude,
        is_available=doc_profile.is_available,
        availability_schedule=doc_profile.availability_schedule,
        name=current_user.name,
        profile_pic=current_user.profile_pic,
        clinic_name=doc_profile.clinic_name,
        address=doc_profile.address,
        phone=doc_profile.phone,
        rating=doc_profile.rating,
        reviews_count=doc_profile.reviews_count,
        consultation_fee=doc_profile.consultation_fee
    )

DISEASE_INFO = {
    "Fungal infection": {
        "description": "An inflammatory skin condition caused by a fungus, leading to irritation, redness, and itching.",
        "precautions": ["Keep the affected area clean and dry", "Use antifungal creams", "Avoid sharing personal items like towels", "Wear loose-fitting cotton clothing"],
        "doctor_specialty": "Dermatologist"
    },
    "Allergy": {
        "description": "An immune system reaction to a foreign substance (allergen) that is typically not harmful.",
        "precautions": ["Identify and avoid allergens", "Use antihistamines", "Keep indoor air clean", "Wear a mask in high-pollen environments"],
        "doctor_specialty": "Allergist / Immunologist"
    },
    "GERD": {
        "description": "Gastroesophageal Reflux Disease occurs when stomach acid frequently flows back into the tube connecting your mouth and stomach.",
        "precautions": ["Avoid lying down immediately after meals", "Eat smaller, more frequent meals", "Limit fatty, spicy, or acidic foods", "Maintain a healthy weight"],
        "doctor_specialty": "Gastroenterologist"
    },
    "Chronic cholestasis": {
        "description": "A long-term condition where the flow of bile from the liver is reduced or stopped, causing toxin build-up.",
        "precautions": ["Follow a low-fat diet", "Avoid alcohol completely", "Take prescribed bile acid medications", "Monitor liver enzymes regularly"],
        "doctor_specialty": "Hepatologist / Gastroenterologist"
    },
    "Drug Reaction": {
        "description": "An adverse response or allergic reaction to a medication or drug.",
        "precautions": ["Stop the suspected medication immediately", "Consult a doctor for alternative drugs", "Take antihistamines if itching occurs", "Seek emergency care for breathing issues"],
        "doctor_specialty": "Allergist / General Physician"
    },
    "Peptic ulcer diseae": {
        "description": "Painful sores that develop on the lining of the stomach, lower esophagus, or small intestine.",
        "precautions": ["Avoid NSAID pain relievers", "Limit spicy foods and caffeine", "Quit smoking and reduce alcohol", "Take prescribed antacids or proton pump inhibitors"],
        "doctor_specialty": "Gastroenterologist"
    },
    "AIDS": {
        "description": "Acquired Immunodeficiency Syndrome is a chronic, life-threatening condition caused by the Human Immunodeficiency Virus (HIV).",
        "precautions": ["Adhere to antiretroviral therapy (ART)", "Practice safe intercourse", "Avoid sharing needles", "Maintain a healthy immune-boosting lifestyle"],
        "doctor_specialty": "Infectious Disease Specialist"
    },
    "Diabetes ": {
        "description": "A chronic metabolic disease characterized by high blood sugar levels due to inadequate insulin production or usage.",
        "precautions": ["Monitor blood glucose levels regularly", "Follow a low-glycemic, balanced diet", "Engage in regular physical activity", "Take insulin or oral medications as prescribed"],
        "doctor_specialty": "Endocrinologist"
    },
    "Gastroenteritis": {
        "description": "An intestinal infection marked by diarrhea, cramps, nausea, vomiting, and fever.",
        "precautions": ["Drink plenty of fluids and oral rehydration solutions (ORS)", "Eat bland foods like bananas and rice", "Wash hands thoroughly with soap", "Avoid dairy and fatty foods during symptoms"],
        "doctor_specialty": "Gastroenterologist / General Physician"
    },
    "Bronchial Asthma": {
        "description": "A chronic condition that inflames and narrows the airways of the lungs, causing difficulty breathing.",
        "precautions": ["Use prescribed rescue and controller inhalers", "Avoid known asthma triggers like dust and smoke", "Monitor peak flow values", "Have an action plan for asthma attacks"],
        "doctor_specialty": "Pulmonologist"
    },
    "Hypertension ": {
        "description": "A common condition in which the long-term force of the blood against your artery walls is high enough to cause health problems.",
        "precautions": ["Reduce dietary sodium intake", "Exercise regularly (cardio)", "Manage stress through relaxation techniques", "Take prescribed blood pressure medications daily"],
        "doctor_specialty": "Cardiologist / General Physician"
    },
    "Migraine": {
        "description": "A neurological condition characterized by intense, debilitating headaches, often accompanied by nausea and light sensitivity.",
        "precautions": ["Rest in a dark, quiet room during an attack", "Identify and avoid trigger foods (e.g. aged cheese, chocolate)", "Maintain a consistent sleep schedule", "Stay hydrated"],
        "doctor_specialty": "Neurologist"
    },
    "Cervical spondylosis": {
        "description": "Age-related wear and tear affecting the spinal disks in your neck.",
        "precautions": ["Maintain good posture while sitting or working", "Do gentle neck stretching exercises", "Use a supportive cervical pillow", "Apply warm compresses to relieve stiffness"],
        "doctor_specialty": "Orthopedist / Physiotherapist"
    },
    "Paralysis (brain hemorrhage)": {
        "description": "Loss of muscle function in part of the body, often caused by a stroke or rupture of a blood vessel in the brain.",
        "precautions": ["Undergo intensive physical and occupational therapy", "Monitor and strictly control blood pressure", "Take prescribed blood thinners or antiplatelet drugs", "Prevent bedsores with regular positioning"],
        "doctor_specialty": "Neurologist / Physiotherapist"
    },
    "Jaundice": {
        "description": "A yellow coloring of the skin and eyes caused by high levels of bilirubin in the blood, indicating liver or gallbladder issues.",
        "precautions": ["Consume a light, easily digestible diet", "Drink plenty of warm water", "Avoid alcohol and fried foods", "Get adequate bed rest"],
        "doctor_specialty": "Hepatologist / Gastroenterologist"
    },
    "Malaria": {
        "description": "A life-threatening disease caused by plasmodium parasites transmitted through the bites of infected female Anopheles mosquitoes.",
        "precautions": ["Take prescribed antimalarial medications", "Use mosquito nets and repellents", "Wear long sleeves and pants outdoors", "Eliminate standing water near the house"],
        "doctor_specialty": "Infectious Disease Specialist / General Physician"
    },
    "Chicken pox": {
        "description": "A highly contagious viral infection causing an itchy, blister-like rash on the skin.",
        "precautions": ["Avoid scratching the blisters to prevent scarring", "Take cool oatmeal baths to relieve itching", "Use calamine lotion", "Isolate from others to prevent spread"],
        "doctor_specialty": "Pediatrician / General Physician"
    },
    "Dengue": {
        "description": "A mosquito-borne viral disease causing high fever, severe body aches, headache, and skin rash.",
        "precautions": ["Stay hydrated and rest extensively", "Take acetaminophen (paracetamol) for pain/fever; avoid NSAIDs like ibuprofen", "Use mosquito repellents and nets", "Monitor platelet count"],
        "doctor_specialty": "Infectious Disease Specialist / General Physician"
    },
    "Typhoid": {
        "description": "A bacterial infection caused by Salmonella typhi, leading to high fever, diarrhea, and vomiting.",
        "precautions": ["Complete the full course of prescribed antibiotics", "Drink only boiled or bottled water", "Eat thoroughly cooked foods", "Practice strict hand hygiene"],
        "doctor_specialty": "General Physician / Gastroenterologist"
    },
    "hepatitis A": {
        "description": "A highly contagious liver infection caused by the hepatitis A virus, usually spread by contaminated food or water.",
        "precautions": ["Avoid alcohol to prevent liver strain", "Get plenty of bed rest", "Eat small, nutritious meals", "Wash hands thoroughly with soap"],
        "doctor_specialty": "Hepatologist / Gastroenterologist"
    },
    "Hepatitis B": {
        "description": "A serious liver infection caused by the hepatitis B virus, transmitted through contact with infectious body fluids.",
        "precautions": ["Avoid alcohol and liver-toxic medications", "Get vaccinated (for family members)", "Practice safe contact/intercourse", "Monitor liver health periodically"],
        "doctor_specialty": "Hepatologist / Gastroenterologist"
    },
    "Hepatitis C": {
        "description": "An infection caused by the hepatitis C virus that attacks the liver and leads to inflammation, transmitted through blood contact.",
        "precautions": ["Complete antiviral therapy as prescribed", "Avoid sharing needles or personal items like razors", "Refrain from alcohol consumption", "Undergo regular liver checkups"],
        "doctor_specialty": "Hepatologist"
    },
    "Hepatitis D": {
        "description": "A liver disease caused by the hepatitis D virus, which only occurs in people who are also infected with hepatitis B.",
        "precautions": ["Manage underlying Hepatitis B infection", "Avoid alcohol", "Take prescribed interferon therapies", "Practice safe healthcare procedures"],
        "doctor_specialty": "Hepatologist"
    },
    "Hepatitis E": {
        "description": "A liver disease caused by the hepatitis E virus, usually transmitted through drinking water contaminated with fecal matter.",
        "precautions": ["Ensure drinking water is boiled or treated", "Rest and allow the body to recover", "Avoid alcohol and self-medication", "Eat cooked, sanitary food"],
        "doctor_specialty": "Hepatologist / Gastroenterologist"
    },
    "Alcoholic hepatitis": {
        "description": "Liver inflammation caused by drinking too much alcohol over many years.",
        "precautions": ["Stop drinking alcohol completely and permanently", "Follow a high-protein, nutritionally rich diet", "Take vitamins and liver support medications", "Monitor for fluid accumulation (ascites)"],
        "doctor_specialty": "Hepatologist / Gastroenterologist"
    },
    "Tuberculosis": {
        "description": "A potentially serious infectious bacterial disease that mainly affects the lungs.",
        "precautions": ["Strictly adhere to the multi-month antitubercular treatment (ATT) course", "Wear a mask to prevent airborne transmission", "Stay in well-ventilated rooms", "Eat a protein-rich diet"],
        "doctor_specialty": "Pulmonologist"
    },
    "Common Cold": {
        "description": "A mild viral infection of the nose, throat, sinuses, and upper airways.",
        "precautions": ["Get plenty of rest", "Drink warm fluids and stay hydrated", "Use saline nasal drops", "Gargle with warm salt water for sore throat"],
        "doctor_specialty": "General Physician"
    },
    "Pneumonia": {
        "description": "An infection that inflames the air sacs in one or both lungs, which may fill with fluid or pus.",
        "precautions": ["Take prescribed antibiotics or antivirals fully", "Use a humidifier or inhale steam", "Avoid smoking and second-hand smoke", "Get plenty of rest"],
        "doctor_specialty": "Pulmonologist / General Physician"
    },
    "Dimorphic hemmorhoids(piles)": {
        "description": "Swollen and inflamed veins in the anus and lower rectum, causing discomfort and bleeding.",
        "precautions": ["Eat a high-fiber diet (fruits, vegetables, whole grains)", "Drink plenty of water", "Avoid straining during bowel movements", "Take warm sitz baths"],
        "doctor_specialty": "Proctologist / General Surgeon"
    },
    "Heart attack": {
        "description": "A medical emergency where the flow of blood to the heart muscle is suddenly blocked, usually by a blood clot.",
        "precautions": ["Call emergency medical services immediately", "Take an aspirin if advised by emergency operators", "Undergo cardiac rehabilitation", "Adopt a low-sodium, heart-healthy diet"],
        "doctor_specialty": "Cardiologist"
    },
    "Varicose veins": {
        "description": "Gnarled, enlarged veins, most commonly appearing in the legs due to weakened vein walls and valves.",
        "precautions": ["Wear compression stockings", "Elevate your legs when sitting or lying down", "Avoid standing or sitting for long periods", "Exercise regularly"],
        "doctor_specialty": "Vascular Surgeon"
    },
    "Hypothyroidism": {
        "description": "A condition in which the thyroid gland doesn't produce enough thyroid hormone, slowing the metabolism.",
        "precautions": ["Take daily thyroid hormone replacement medication (levothyroxine)", "Take medication on an empty stomach in the morning", "Get regular blood tests for TSH levels", "Maintain a balanced diet"],
        "doctor_specialty": "Endocrinologist"
    },
    "Hyperthyroidism": {
        "description": "A condition in which the thyroid gland produces too much of the hormone thyroxine, accelerating the metabolism.",
        "precautions": ["Take antithyroid medications or beta-blockers as prescribed", "Avoid high-iodine foods like seaweed", "Regularly monitor thyroid hormone levels", "Ensure adequate calcium and vitamin D intake"],
        "doctor_specialty": "Endocrinologist"
    },
    "Hypoglycemia": {
        "description": "A condition characterized by an abnormally low level of blood sugar (glucose).",
        "precautions": ["Consume fast-acting carbohydrates (e.g. fruit juice, candy) immediately", "Check blood sugar levels frequently", "Carry glucose tablets with you", "Eat regular, balanced meals"],
        "doctor_specialty": "Endocrinologist / General Physician"
    },
    "Osteoarthristis": {
        "description": "The most common form of arthritis, involving the wear and tear of protective cartilage on the ends of bones.",
        "precautions": ["Engage in low-impact exercises like swimming or walking", "Maintain a healthy weight to reduce joint load", "Apply warm or cold packs to joints", "Use pain relief medications as directed"],
        "doctor_specialty": "Rheumatologist / Orthopedist"
    },
    "Arthritis": {
        "description": "Inflammation of one or more joints, causing pain, stiffness, and reduced range of motion.",
        "precautions": ["Perform joint-friendly physical activities", "Maintain a healthy body weight", "Use hot and cold therapies", "Take prescribed anti-inflammatory drugs"],
        "doctor_specialty": "Rheumatologist"
    },
    "(vertigo) Paroymsal  Positional Vertigo": {
        "description": "A disorder of the inner ear characterized by short episodes of intense spinning sensations triggered by changes in head position.",
        "precautions": ["Perform the Epley maneuver as guided by a physician", "Avoid sudden head movements or turning quickly", "Sit down immediately when feeling dizzy", "Sleep with your head slightly elevated"],
        "doctor_specialty": "ENT Specialist / Neurologist"
    },
    "Acne": {
        "description": "A skin condition that occurs when hair follicles become plugged with oil and dead skin cells.",
        "precautions": ["Wash your face twice daily with a gentle cleanser", "Avoid squeezing or popping pimples", "Use non-comedogenic (pore-friendly) cosmetics", "Limit touching your face"],
        "doctor_specialty": "Dermatologist"
    },
    "Urinary tract infection": {
        "description": "An infection in any part of the urinary system, most commonly involving the bladder and urethra.",
        "precautions": ["Drink plenty of water to flush out bacteria", "Complete the full course of antibiotics", "Avoid irritating feminine products", "Urinate shortly after intercourse"],
        "doctor_specialty": "Urologist / General Physician"
    },
    "Psoriasis": {
        "description": "A skin disease that causes itchy or sore patches of thick, red skin with silvery scales.",
        "precautions": ["Keep your skin well-moisturized", "Avoid triggers like stress or skin injuries", "Limit exposure to extreme cold or dry weather", "Apply topical treatments or undergo light therapy"],
        "doctor_specialty": "Dermatologist"
    },
    "Impetigo": {
        "description": "A highly contagious bacterial skin infection that causes sores and crusts, commonly around the nose and mouth.",
        "precautions": ["Wash sores gently with warm water and soap", "Keep infected sores covered with bandages", "Avoid sharing towels, clothes, or toys", "Complete the prescribed antibiotic treatment"],
        "doctor_specialty": "Dermatologist / Pediatrician"
    }
}

def get_disease_metadata(disease_name: str) -> dict:
    sanitized = disease_name.strip()
    # Check lowercase map for robustness
    lower_map = {k.lower(): v for k, v in DISEASE_INFO.items()}
    if sanitized.lower() in lower_map:
        return lower_map[sanitized.lower()]
    
    # Fallback default values
    return {
        "description": f"A medical condition identified as {disease_name}. Detailed clinical assessment is recommended.",
        "precautions": ["Consult a medical professional", "Monitor your symptoms closely", "Ensure adequate rest", "Stay hydrated"],
        "doctor_specialty": "General Physician"
    }

@app.post("/api/predict", response_model=schemas.PredictionResponse)
def predict_disease(
    req: schemas.PredictionRequest,
    current_user: Optional[models.User] = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    if not model:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail="Machine learning prediction model not loaded."
        )

    # Encode symptom map to match symptom.pkl indices
    if isinstance(req.symptoms, list):
        symptom_map = {s: 1 for s in req.symptoms}
    else:
        symptom_map = req.symptoms

    input_vector = [int(symptom_map.get(symptom, 0)) for symptom in all_symptoms]

    try:
        import pandas as pd
        X_df = pd.DataFrame([input_vector], columns=all_symptoms)
        
        prediction = model.predict(X_df)
        top_disease = str(prediction[0]).strip()

        # Multi-disease probability predictions
        probabilities = model.predict_proba(X_df)[0]
        classes = model.classes_
        
        pred_tuples = sorted(zip(classes, probabilities), key=lambda x: x[1], reverse=True)
        top_preds = pred_tuples[:5]
        
        predictions_list = []
        for disease_cls, prob in top_preds:
            disease_name = str(disease_cls).strip()
            meta = get_disease_metadata(disease_name)
            predictions_list.append(
                schemas.PredictionItem(
                    disease=disease_name,
                    confidence=float(prob),
                    description=meta["description"],
                    precautions=meta["precautions"],
                    doctor_specialty=meta["doctor_specialty"]
                )
            )

        history_id = None
        uid = current_user.id if current_user else req.user_id
        if uid:
            user_exists = db.query(models.User).filter(models.User.id == uid).first()
            if user_exists:
                history = models.PredictionHistory(
                    user_id=uid,
                    symptoms=symptom_map,
                    predicted_disease=top_disease
                )
                db.add(history)
                db.commit()
                db.refresh(history)
                history_id = history.id

            _legacy_prediction_store[uid] = top_disease

        return schemas.PredictionResponse(
            success=True, 
            disease=top_disease, 
            predictions=predictions_list,
            history_id=history_id
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Model execution error: {str(e)}"
        )

# Legacy GET /predict fallback
@app.get("/predict")
def get_prediction_legacy(
    current_user: models.User = Depends(auth.get_current_user)
):
    disease = _legacy_prediction_store.get(current_user.id)
    if not disease:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, 
            detail="No prediction submitted in this session yet."
        )
    return {"success": True, "disease": disease}

def calculate_haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0  # Earth's radius in kilometers
    
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c

@app.get("/api/doctors/nearby", response_model=List[schemas.DoctorProfileResponse])
def get_nearby_doctors(
    latitude: float,
    longitude: float,
    specialty: Optional[str] = None,
    radius: float = 5.0,
    db: Session = Depends(get_db)
):
    query = db.query(models.DoctorProfile, models.User).join(
        models.User, models.User.id == models.DoctorProfile.user_id
    ).filter(
        models.DoctorProfile.latitude.isnot(None),
        models.DoctorProfile.longitude.isnot(None),
        models.DoctorProfile.is_available == True
    )

    if specialty:
        # Match specialty by substring
        query = query.filter(models.DoctorProfile.specialty.ilike(f"%{specialty.strip()}%"))

    results = query.all()
    nearby = []

    for doc_profile, user in results:
        dist = calculate_haversine(latitude, longitude, doc_profile.latitude, doc_profile.longitude)
        if dist <= radius:
            nearby.append(
                schemas.DoctorProfileResponse(
                    user_id=doc_profile.user_id,
                    specialty=doc_profile.specialty,
                    latitude=doc_profile.latitude,
                    longitude=doc_profile.longitude,
                    is_available=doc_profile.is_available,
                    availability_schedule=doc_profile.availability_schedule,
                    name=user.name,
                    profile_pic=user.profile_pic,
                    distance=dist,
                    clinic_name=doc_profile.clinic_name,
                    address=doc_profile.address,
                    phone=doc_profile.phone,
                    rating=doc_profile.rating,
                    reviews_count=doc_profile.reviews_count,
                    consultation_fee=doc_profile.consultation_fee
                )
            )

    nearby.sort(key=lambda d: d.distance if d.distance is not None else 99999)
    return nearby

@app.get("/api/symptoms")
def get_symptoms():
    categorized = []
    for idx, s in enumerate(all_symptoms):
        name = s.replace("_", " ").title()
        
        s_lower = s.lower()
        if any(w in s_lower for w in ["cough", "sneeze", "breath", "throat", "nose", "congestion", "sinus", "chest"]):
            category = "Respiratory"
        elif any(w in s_lower for w in ["stomach", "vomit", "nausea", "diar", "constip", "belly", "abdom", "digest", "appetite"]):
            category = "Digestive"
        elif any(w in s_lower for w in ["headache", "dizzy", "spin", "paralysis", "balance", "unsteadiness", "nervous"]):
            category = "Neurological"
        elif any(w in s_lower for w in ["joint", "muscle", "bone", "neck", "back", "pain", "limb"]):
            category = "Musculoskeletal"
        elif any(w in s_lower for w in ["rash", "itch", "skin", "spot", "blister", "ulcer", "acne", "peel"]):
            category = "Dermatological"
        elif any(w in s_lower for w in ["fever", "chill", "sweat", "fatig", "letharg", "weight", "weak"]):
            category = "Systemic"
        else:
            category = "Other"
            
        categorized.append({
            "id": f"symptom_{idx + 1}",
            "name": s,
            "display_name": name,
            "category": category
        })
    return {"symptoms": categorized}

@app.get("/api/doctors/{doctor_id}/slots")
def get_doctor_slots(
    doctor_id: str,
    date: str,
    db: Session = Depends(get_db)
):
    doc = db.query(models.DoctorProfile).filter(models.DoctorProfile.user_id == doctor_id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Doctor not found")
        
    all_slots = ["09:00 AM", "10:00 AM", "11:00 AM", "12:00 PM", "02:00 PM", "03:00 PM", "04:00 PM", "05:00 PM"]
    
    bookings = db.query(models.Booking).filter(
        models.Booking.doctor_id == doctor_id,
        models.Booking.date == date,
        models.Booking.status != "cancelled"
    ).all()
    
    booked_slots = [b.time for b in bookings]
    available_slots = [slot for slot in all_slots if slot not in booked_slots]
    
    return {
        "date": date,
        "doctor_id": doctor_id,
        "available_slots": available_slots,
        "booked_slots": booked_slots
    }

@app.post("/api/bookings", response_model=schemas.BookingResponse)
def create_booking(
    req: schemas.BookingCreate,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    doctor = db.query(models.User).filter(models.User.id == req.doctor_id, models.User.role == "doctor").first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor not found")
        
    existing = db.query(models.Booking).filter(
        models.Booking.doctor_id == req.doctor_id,
        models.Booking.date == req.date,
        models.Booking.time == req.time,
        models.Booking.status != "cancelled"
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Time slot already booked")
        
    booking = models.Booking(
        user_id=current_user.id,
        doctor_id=req.doctor_id,
        patient_name=req.patient_name,
        symptoms=req.symptoms,
        date=req.date,
        time=req.time,
        status="pending",
        clinic_address=req.clinic_address,
        additional_notes=req.additional_notes
    )
    db.add(booking)
    db.commit()
    db.refresh(booking)
    return booking

@app.get("/api/bookings", response_model=List[schemas.BookingResponse])
def get_user_bookings(
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    if current_user.role == "doctor":
        bookings = db.query(models.Booking).filter(models.Booking.doctor_id == current_user.id).order_by(models.Booking.created_at.desc()).all()
    else:
        bookings = db.query(models.Booking).filter(models.Booking.user_id == current_user.id).order_by(models.Booking.created_at.desc()).all()
    return bookings

@app.put("/api/bookings/{booking_id}/status", response_model=schemas.BookingResponse)
def update_booking_status(
    booking_id: int,
    status_update: schemas.BookingStatusUpdate,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    booking = db.query(models.Booking).filter(models.Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
        
    if current_user.id != booking.user_id and current_user.id != booking.doctor_id:
        raise HTTPException(status_code=403, detail="Not authorized to modify this booking")
        
    booking.status = status_update.status
    db.commit()
    db.refresh(booking)
    return booking
