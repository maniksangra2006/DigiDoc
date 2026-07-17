# DigiDoc Deployment Guide (Render.com)

This guide details how to deploy the FastAPI Python backend and host/build the Flutter frontend for production using Render.

---

## 💻 Part 1: Deploying the Python FastAPI Backend on Render

Render natively hosts Python servers and provides managed PostgreSQL databases. Follow these steps to host your backend.

### Step 1: Create a PostgreSQL Database on Render
1. Log in to [Render.com](https://render.com/).
2. Click **New** (top-right) → **PostgreSQL**.
3. Configure the database:
   - **Name**: `digidoc-db`
   - **Database**: `digidoc`
   - **User**: `digidoc_user`
4. Click **Create Database**.
5. Once created, copy the **Internal Database URL** (e.g., `postgres://digidoc_user:.../digidoc`).

### Step 2: Create a Web Service for the Backend
1. Click **New** → **Web Service**.
2. Connect your GitHub repository (`maniksangra2006/DigiDoc`).
3. Configure the deployment settings:
   - **Name**: `digidoc-backend`
   - **Environment**: `Python`
   - **Root Directory**: `backend` *(Crucial because the python files are in the backend subfolder!)*
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
4. Click **Advanced** and add the following **Environment Variables**:
   - `DATABASE_URL`: *(Paste the **Internal Database URL** you copied in Step 1)*
   - `PYTHON_VERSION`: `3.10.13`
5. Click **Create Web Service**.

Render will provision your PostgreSQL instance, install dependencies, and build the backend. It will output a public URL (e.g. `https://digidoc-backend.onrender.com`).

---

## 📱 Part 2: Configuring and Building the Flutter Client

### Step 1: Update API Base URL
Open the configuration file `lib/config.dart` and update the `baseUrl` getter to point to your live backend domain:

```dart
// lib/config.dart
class AppConfig {
  /// Base URL for the DigiDoc FastAPI backend in production.
  static String get baseUrl => 'https://digidoc-backend.onrender.com'; // Paste your Render URL here
  
  // Set useDevMode to false for production
  static const bool useDevMode = false; 
}
```

### Step 2: Build for Android (Production APK)
Generate a signed release APK to install on physical Android devices:
```bash
# Clean project
flutter clean
flutter pub get

# Build Release APK
flutter build apk --release
```
The output APK file will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

### Step 3: Build for Web (HTML5 hosting)
If you want to host the app as a website on platforms like Vercel, Netlify, or Firebase Hosting:
```bash
flutter build web --release
```
The deployable web files will be compiled inside the `build/web/` folder.
