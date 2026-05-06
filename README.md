# FlashLearn PWD 📚✨

**Interactive Bilingual Flashcard & Vocabulary Learning App for Persons with Disabilities (PWD) Students**

A Flutter-based mobile application designed as a thesis/capstone project. FlashLearn PWD helps PWD students learn English and Filipino vocabulary through accessible flashcards, educational games, Filipino Sign Language (FSL) videos, and interactive stories — all with comprehensive accessibility support.

---

## Features

### Core Learning
- **144 Flashcards** across 12 categories (Animals, Colors & Shapes, Numbers, Body Parts, Food & Drinks, Family & Greetings, Clothing, Weather, Classroom, Transportation, Emotions, Days & Time)
- **Bilingual Support** — English and Filipino translations for every word
- **Filipino Sign Language (FSL)** — embedded video demonstrations for vocabulary
- **Text-to-Speech** — hear pronunciations in English and Filipino
- **Interactive Stories** — reading comprehension with quizzes

### Educational Games (8 types)
| Game | Description |
|------|-------------|
| Word Match | Match English words to Filipino translations |
| Spelling Bee | Spell vocabulary words with audio hints |
| Memory Match | Classic memory card game with flashcard content |
| Drag & Drop | Drag words to correct categories |
| Flashcard Quiz | Timed multiple-choice vocabulary quiz |
| Pronunciation Practice | Speech-to-text pronunciation scoring |
| Tracing | Letter tracing with guided paths |
| Smart Review | Spaced repetition review system |

### Accessibility ♿
- **Disability Presets** — auto-configure settings for visual, hearing, motor, cognitive, and autism needs
- **Font Scaling** — adjustable text size (0.8x – 2.0x)
- **High Contrast Mode** — enhanced color contrast for low vision
- **Dark Mode** — OLED-friendly dark theme
- **Reduced Motion** — disable animations for motion sensitivity
- **Sound Effects Toggle** — mute/unmute game sounds
- **Speech-to-Text** — voice input for spelling and pronunciation games
- **Haptic Feedback** — tactile responses on interactions
- **Semantic Labels** — full screen reader support

### Progress & Gamification
- **Star System** — earn stars for games, spend them in the shop
- **Daily Streaks** — track consecutive learning days
- **Achievements** — unlock badges for milestones
- **Leaderboard** — compare progress across profiles
- **Detailed Analytics** — category mastery, accuracy charts, weak areas
- **Learning Paths** — structured curriculum progression

### Multi-User & Roles
- **Student / Teacher / Parent** roles with role-specific onboarding tutorials
- **Multi-Profile Support** — store multiple learner profiles on one device
- **PIN Protection** — optional 4-digit PIN per profile
- **Teacher Dashboard** — student monitoring, classroom real-time view, PDF/CSV report export
- **Parent Dashboard** — track child's progress and achievements

### Internationalization (i18n)
- Full English and Filipino localization via Flutter gen-l10n
- All UI strings localized (290+ ARB keys)

### Reliability
- **Global Error Handling** — centralized error logging with user-friendly messages
- **Offline Connectivity Banner** — visual indicator when network is unavailable
- **Offline-First Architecture** — all content works without internet (Hive local storage)

---

## Architecture

```
lib/
├── main.dart                 # App entry point with error handling
├── core/
│   ├── accessibility/        # Sound, haptic, TTS services
│   ├── constants/            # Flashcard emojis, letter paths
│   ├── services/             # Sync, backup, notification services
│   ├── theme/                # AppColors, AppTypography, AppTheme
│   └── utils/                # ErrorHandler, responsive utilities
├── data/
│   ├── local/                # HiveService, seed data, daily challenges
│   └── models/               # Flashcard, UserProfile, GameScore, enums
├── features/
│   ├── classroom/            # Real-time classroom monitoring
│   ├── flashcards/           # Viewer, creator, FSL dictionary, smart review
│   ├── games/                # 8 game screens (quiz, match, spell, etc.)
│   ├── home/                 # Home screen with category grid
│   ├── onboarding/           # Profile creation, accessibility setup, splash
│   ├── progress/             # Progress dashboard, leaderboard, analytics
│   ├── settings/             # Settings, dashboard, backup/restore
│   ├── shop/                 # Star shop with themes & avatars
│   └── stories/              # Story reader with quizzes
├── l10n/                     # ARB localization files (en, fil)
├── navigation/               # GoRouter config, bottom nav shell
├── providers/                # Riverpod providers (profile, settings, progress)
└── widgets/                  # Shared widgets, tutorial overlay, error boundary
```

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| State Management | flutter_riverpod (StateNotifier) |
| Navigation | go_router (ShellRoute for bottom nav) |
| Local Storage | hive_flutter |
| Cloud Sync | supabase_flutter (scaffolded) |
| Animations | flutter_animate, confetti, shimmer |
| Audio | audioplayers, flutter_tts, speech_to_text |
| Charts | fl_chart, percent_indicator |
| PDF Export | pdf, printing |
| Localization | Flutter gen-l10n (ARB files) |
| Testing | flutter_test, mocktail |

---

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.11.0
- Dart SDK ≥ 3.11.0
- Android Studio / VS Code with Flutter extension
- An Android or iOS device/emulator

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd thesis2

# Install dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run on connected device
flutter run
```

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/new_implementations_test.dart

# Run with coverage
flutter test --coverage
```

### Building

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (requires macOS)
flutter build ios --release
```

---

## Project Structure Details

### Data Flow
1. **Seed Data** → `HiveService` stores 144 flashcards + 12 categories locally
2. **User Profile** → created during onboarding with role, avatar, disability type
3. **Learning Progress** → updated after each game/flashcard session
4. **Settings** → persisted per-profile (font scale, contrast, TTS, locale, etc.)

### Key Design Patterns
- **Feature-Based Folders** — each feature has its own `screens/`, `widgets/` directories
- **Repository Pattern** — `HiveService` as the single data access layer
- **Provider Pattern** — `profileProvider`, `settingsProvider`, `progressProvider` for reactive state
- **Accessibility-First** — every interactive widget has `Semantics` labels; disability presets auto-configure multiple settings at once

---

## Testing

The project includes unit and widget tests covering:
- Model serialization (Flashcard, GameScore, LeaderboardEntry)
- Settings copyWith/roundtrip
- UserProfile PIN protection
- AppError handling and user messaging
- Tutorial steps for all roles (Student, Teacher, Parent)
- Seed data integrity and category validation
- Shop data and theme validation
- Spaced repetition algorithm
- Achievement unlocking logic

---

## License

This project was developed as a thesis/capstone project. All rights reserved.
