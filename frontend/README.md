# 🌿 AgriVora – Smart Farming Flutter App

AgriVora is a Flutter-based mobile application designed to assist farmers and home gardeners with soil analysis, crop recommendations, and smart farming insights powered by AI.

## 📱 Features

- **Welcome & Onboarding** – Clean onboarding flow with permissions
- **Authentication** – Login & Signup system
- **Role Selection** – Farmer / Home Gardener mode
- **Home Dashboard** – Central hub for all features
- **Soil Analysis** – Camera-based and manual soil input analysis
- **Crop Recommendations** – AI-powered crop suggestions with detailed overview
- **Map View** – Location-based farming insights using Google Maps
- **AI Chat** – Conversational AI assistant for farming queries
- **Profile** – User profile management

## 🗂️ Project Structure

```
lib/
├── main.dart               # App entry point & routes
├── theme.dart              # App theme configuration
├── pages/
│   ├── welcome_page.dart
│   ├── permission_page.dart
│   ├── login_page.dart
│   ├── signup_page.dart
│   ├── role_select_page.dart
│   ├── home_page.dart
│   ├── soil_analysis_page.dart
│   ├── manual_soil_analysis_page.dart
│   ├── crop_recom_page.dart
│   ├── crop_overview_page.dart
│   ├── map_page.dart
│   ├── ai_chat_page.dart
│   └── profile_page.dart
└── scan_flow/
    ├── start_scan_screen.dart
    ├── gps_step_screen.dart
    ├── ph_step_screen.dart
    └── image_step_screen.dart

assets/
└── images/                 # App images and logo
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `^3.0.0`
- Android Studio / Xcode
- Google Maps API Key (for map features)

### Setup

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd Frontend
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Add Google Maps API Key:**
   - Open `android/app/src/main/AndroidManifest.xml`
   - Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual key

4. **Run the app:**
   ```bash
   flutter run
   ```

## 📦 Dependencies

| Package | Purpose |
|---|---|
| `google_maps_flutter` | Map integration |
| `location` | GPS location access |
| `image_picker` | Camera & gallery access |
| `google_fonts` | Premium typography |
| `cupertino_icons` | iOS-style icons |

## 🤝 Team

Built as part of the **SDGP (Software Development Group Project)** — AgriVora Team.
