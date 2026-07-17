from sqlalchemy import Column, String, Float, Boolean, DateTime, ForeignKey, Integer, JSON
from sqlalchemy.orm import relationship
import datetime
from database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, index=True)  # Firebase UID
    email = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=False)
    role = Column(String, nullable=False)  # 'patient' or 'doctor'
    profile_pic = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    # Relationships
    doctor_profile = relationship("DoctorProfile", back_populates="user", uselist=False, cascade="all, delete-orphan")
    predictions = relationship("PredictionHistory", back_populates="user", cascade="all, delete-orphan")

class DoctorProfile(Base):
    __tablename__ = "doctor_profiles"

    user_id = Column(String, ForeignKey("users.id"), primary_key=True)
    specialty = Column(String, nullable=False, index=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    is_available = Column(Boolean, default=True)
    availability_schedule = Column(String, default="Mon-Fri 9:00 AM - 5:00 PM")
    clinic_name = Column(String, default="City Hospital")
    address = Column(String, default="Sector 10, Greater Noida")
    phone = Column(String, default="+91 9876543210")
    rating = Column(Float, default=4.5)
    reviews_count = Column(Integer, default=120)
    consultation_fee = Column(Integer, default=500)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    # Relationship back to User
    user = relationship("User", back_populates="doctor_profile")

class PredictionHistory(Base):
    __tablename__ = "prediction_histories"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    symptoms = Column(JSON, nullable=False)
    predicted_disease = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    # Relationship back to User
    user = relationship("User", back_populates="predictions")

class Booking(Base):
    __tablename__ = "bookings"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    doctor_id = Column(String, ForeignKey("users.id"), nullable=False)
    patient_name = Column(String, nullable=False)
    symptoms = Column(JSON, nullable=False)  # List of symptoms
    date = Column(String, nullable=False)  # YYYY-MM-DD
    time = Column(String, nullable=False)  # "10:00 AM"
    status = Column(String, default="pending")  # "pending", "confirmed", "cancelled"
    clinic_address = Column(String, nullable=False)
    additional_notes = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    # Relationships
    patient = relationship("User", foreign_keys=[user_id])
    doctor = relationship("User", foreign_keys=[doctor_id])
