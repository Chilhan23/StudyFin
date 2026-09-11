# StudyFin

StudyFin is an offline-first productivity application built with Flutter, designed to integrate study session tracking and personal expense management into a single, unified interface.

## Purpose

The primary objective of this project is hands-on learning and practical experimentation with the Flutter framework, Dart ecosystem, and local data persistence architectures. It focuses on implementing clean architectural patterns, state handling, and direct SQLite integration without relying on third-party cloud infrastructure.

## Key Features

- Study Tracker: Logs study durations, specific subjects, and targeted topics with session completion status.
- Finance Tracker: Records cash inflows and outflows categorized by necessity, monitoring net balance and budget allocations.
- Dashboard Aggregation: Summarizes daily productivity metrics and active financial health on a centralized overview screen.
- Local Persistence: Implements SQLite via the sqflite package to ensure full data isolation, offline reliability, and low latency.
- Minimalist Interface: High-contrast monochrome aesthetic built for readability and distraction-free daily logging.

## Tech Stack

- Framework: Flutter
- Language: Dart
- Local Storage: SQLite (sqflite, path)
- Target Platforms: Android, Linux Desktop

## Getting Started

### Prerequisites

- Flutter SDK (version 3.20.0 or higher)
- Android SDK Platform-Tools and Build-Tools
- Connected Android device with USB Debugging enabled, or a configured Linux desktop environment

### Installation

1. Clone the repository:
git clone https://github.com/<username>/studyfin.git
cd studyfin

2. Install dependencies:
flutter pub get

3. Run the application:
For Android:
flutter run

For Linux Desktop:
flutter run -d linux