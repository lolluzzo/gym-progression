# gym_progression

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


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