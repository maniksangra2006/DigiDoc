from pydantic import BaseModel
from typing import List, Dict, Optional, Union
import datetime

class UserBase(BaseModel):
    email: str
    name: str
    role: str
    profile_pic: Optional[str] = None

class UserResponse(UserBase):
    id: str
    created_at: datetime.datetime
    specialty: Optional[str] = None

    class Config:
        from_attributes = True

class DoctorProfileUpdate(BaseModel):
    specialty: str
    latitude: float
    longitude: float
    is_available: Optional[bool] = True
    availability_schedule: Optional[str] = "Mon-Fri 9:00 AM - 5:00 PM"
    clinic_name: Optional[str] = "City Hospital"
    address: Optional[str] = "Sector 10, Greater Noida"
    phone: Optional[str] = "+91 9876543210"
    rating: Optional[float] = 4.5
    reviews_count: Optional[int] = 120
    consultation_fee: Optional[int] = 500

class DoctorProfileResponse(BaseModel):
    user_id: str
    specialty: str
    latitude: Optional[float]
    longitude: Optional[float]
    is_available: bool
    availability_schedule: str
    name: str
    profile_pic: Optional[str]
    distance: Optional[float] = None
    clinic_name: Optional[str] = "City Hospital"
    address: Optional[str] = "Sector 10, Greater Noida"
    phone: Optional[str] = "+91 9876543210"
    rating: Optional[float] = 4.5
    reviews_count: Optional[int] = 120
    consultation_fee: Optional[int] = 500

    class Config:
        from_attributes = True

class PredictionRequest(BaseModel):
    symptoms: Union[List[str], Dict[str, int]]
    user_id: Optional[str] = None

class PredictionItem(BaseModel):
    disease: str
    confidence: float
    description: str
    precautions: List[str]
    doctor_specialty: str

class PredictionResponse(BaseModel):
    success: bool
    disease: str
    predictions: List[PredictionItem]
    history_id: Optional[int] = None

class BookingCreate(BaseModel):
    doctor_id: str
    patient_name: str
    symptoms: List[str]
    date: str
    time: str
    clinic_address: str
    additional_notes: Optional[str] = None

class BookingStatusUpdate(BaseModel):
    status: str

class BookingResponse(BaseModel):
    id: int
    user_id: str
    doctor_id: str
    patient_name: str
    symptoms: List[str]
    date: str
    time: str
    status: str
    clinic_address: str
    additional_notes: Optional[str] = None
    created_at: datetime.datetime

    class Config:
        from_attributes = True
