# gym_progression

Offline-first Flutter app for logging gym workouts. It's distributed outside the stores: an APK for Android and an unsigned IPA for iOS. See [DEPLOY_PLAN.md](DEPLOY_PLAN.md) for the full release procedure.

## Toolchain

### All platforms

- **Flutter** stable, 3.44 or newer. Run `flutter doctor` to check the setup.

### Android

- **Android Studio**, or just the Android SDK command-line tools. You need:
  - the Android SDK with `platform-tools` and `cmdline-tools`. Accept the licenses with `flutter doctor --android-licenses`.
  - NDK 28 and CMake 3.22. The first build installs them automatically.
- **JDK 17 or newer.** Android Studio ships one. To use another JDK, run `flutter config --jdk-dir <path>`.
- **A release keystore** in `android/key.properties`, which is git-ignored. See [DEPLOY_PLAN.md → Android signing](DEPLOY_PLAN.md#3-android-signing-one-time-before-the-first-release).

### iOS on Linux

- **[xlinux](https://github.com/cesardev31/xlinux#installation)**: it builds the iOS app on Linux.
- **Xcode `.xip`**, downloaded from [developer.apple.com/download](https://developer.apple.com/download/all/) with a free Apple ID. xlinux extracts the iOS SDK from it.
- Run `xlinux setup` once. It installs whatever is missing:
  - the Swift toolchain (via swiftly)
  - **[xtool](https://github.com/xtool-org/xtool)**, for signing and installing on the device
  - the iOS SDK
  - pymobiledevice3 and LLVM tools
- **Darling** runs Dart's macOS-only AOT compiler for release builds. xlinux installs it on first use, or you can install it upfront with `xlinux setup --all`.
- To install on a phone:
  - an iPhone on iOS 15 or newer, connected over USB, unlocked, with Developer Mode on
  - an Apple ID logged in with `xtool auth login`
- Run `xlinux doctor` to check everything.

### iOS on macOS

- **Xcode** with the iOS platform installed. CocoaPods isn't needed, because Flutter uses Swift Package Manager.

## Building

Each script reads the version from `pubspec.yaml` and writes its output to `dist/`, which is git-ignored.

| Command | Host | Output |
| --- | --- | --- |
| `./build-android.sh` | Linux / macOS | `dist/gym-progression-v<version>.apk` (release-signed) |
| `./build-ios-linux.sh` | Linux | `dist/gym-progression-v<version>-unsigned.ipa` |
| `./build-ios-linux.sh --install` | Linux | same IPA, then signs it and installs it on the connected iPhone with `xtool install` |
| `./build-ios.sh` | macOS | `build/ios/archive/Runner.xcarchive` and the unsigned IPA |

The unsigned IPA can also be sideloaded with Sideloadly or AltStore, which re-sign it with the installer's Apple ID.


Here is a clean, professional MVP Specification Document in English based on your requirements. You can keep this in your project's docs/ folder or your README.md.

📋 Gym Progression App - MVP Specification
1. Core Features (The "Must-Haves")
The initial version focuses on the essential workout loop to ensure a functional user experience from day one.

Workout Logger: * Create and manage workout routines (Templates).

Input real-time data: Exercise name, Sets, Repetitions, and Weight.

Exercise Database: * A searchable catalog of exercises categorized by muscle groups (e.g., Chest, Back, Legs).

Initial version: Static local list (Hardcoded or JSON).

Rest Timer: * A simple, integrated countdown widget to manage recovery time between sets.

2. Architecture & State Management
To ensure scalability, the project follows a modular structure from the start.

State Management: Riverpod (Recommended) or Provider.

Goal: Decouple business logic from the UI and avoid "SetState Hell."

Project Directory Structure:

/lib/models: Data structures (e.g., Exercise, Workout, Set).

/lib/screens: Primary views (Dashboard, Active Workout, History).

/lib/widgets: Reusable UI components (Custom buttons, Input fields).

/lib/services: Persistence logic and database handlers.

/lib/providers: Logic for state management.

3. Local Persistence (Offline-First)
Gyms often have poor connectivity. The app must work 100% offline.

Database Engine: Isar or Hive (NoSQL).

Reason: High performance for mobile and easy object mapping in Flutter.

Alternative: SQLite (sqflite) for developers preferring relational data structures.

4. UI/UX Strategy
A modern, high-energy interface to keep users motivated.

Design System: Material 3 (Default Flutter 3.x widgets).

Theme: Default Dark Mode to reduce eye strain in gym environments and save battery.

Data Visualization: Integration of fl_chart for future progress tracking (weight/volume over time).