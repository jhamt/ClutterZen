# Clutter Zen

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)
![Gemini AI](https://img.shields.io/badge/Gemini_AI-8E75B2?style=for-the-badge&logo=googlebard&logoColor=white)

**Clutter Zen** is a cross-platform digital sanctuary designed to help you declutter your digital life. By combining intent-based onboarding, powerful habit tracking, and AI-driven insights, it provides a calm, unified workspace to organize files, tasks, and routines across all your devices.

---

## 🚀 Features

- **✨ AI-Powered Insights**: Integrated **Google Gemini AI** to provide smart, context-aware recommendations for organization and habit formation.
- **🧘 Guided Onboarding**: Beautiful, step-by-step illustrated flows to introduce calm and effective decluttering techniques.
- **🔒 Secure Identity**: Robust authentication and account management powered by **Firebase Auth**.
- **☁️ Cloud Sync**: Real-time data synchronization across Android, iOS, Desktop, and Web using **Cloud Firestore**.
- **💳 Premium Features**: Integrated **Stripe** payment processing for unlocking advanced capabilities.
- **🎨 Cross-Platform Mastery**: A seamless, responsive UI tailored for every screen size, from mobile phones to large desktop monitors.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (3.x)
- **Language**: Dart, Kotlin, Swift
- **Backend**: Firebase (Firestore, Functions, Storage, Auth)
- **AI**: Google Generative AI (Gemini)
- **Payments**: Stripe

## 📂 Project Structure

```
├── android / ios / ...       # Native platform code
├── assets/                   # Branding, onboarding art, and icons
├── backend/functions/        # Firebase Cloud Functions (Node.js)
├── lib/
│   ├── backend/              # Data layer and repositories
│   ├── screens/              # UI screens and widgets
│   ├── services/             # App services (Gemini, Auth, etc.)
│   └── main.dart             # Entry point
├── test/                     # Unit and widget tests
└── firebase/                 # Security rules for Firestore & Storage
```

## 🏁 Getting Started

### Prerequisites

1.  **Flutter SDK**: Version 3.1.0 or newer.
2.  **Firebase CLI**: For backend deployment.
3.  **Environment Setup**:
    - Duplicate `ENV_TEMPLATE.txt` and rename it to `.env`.
    - Fill in your API keys (Gemini, Stripe, Firebase).

### Installation

1.  **Get Dependencies**:

    ```bash
    flutter pub get
    ```

2.  **Run the App**:
    ```bash
    flutter run
    ```

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1.  **Fork** the repository.
2.  Create a **feature branch** (`git checkout -b feature/AmazingFeature`).
3.  **Commit** your changes (`git commit -m 'Add some AmazingFeature'`).
4.  **Push** to the branch (`git push origin feature/AmazingFeature`).
5.  Open a **Pull Request**.

---

_Built with ❤️ for a clutter-free world._
