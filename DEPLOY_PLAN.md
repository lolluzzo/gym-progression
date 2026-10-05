# Deploy plan: local distribution (no stores)

Goal: ship the app outside the stores.

- **Android**: a release-signed APK attached to GitHub Releases.
- **iOS**: an Xcode archive plus an unsigned IPA. You install it with a free Apple ID (Xcode, Sideloadly or AltStore).

Status as of 2026-10-05.

## 1. Done in this pass

- [x] **App ID** changed from `com.example.*` to `io.github.lolluzzo.gymprogression`, for both the Android `applicationId` and the iOS bundle ID.
  The Android `namespace` and the Kotlin package are still `com.example.gym_progression`. That name is internal and users never see it.
- [x] **Android toolchain** moved to the Flutter 3.44 template:
  - AGP 9.0.1, Kotlin 2.3.20, Gradle 9.1.0 and Java 17.
  - The new plugin loader in `settings.gradle`.
  - `versionCode`/`versionName` now come from `pubspec.yaml`.
- [x] **Android release signing** reads `android/key.properties`, which is git-ignored. When that file is missing, the build falls back to the debug keys, so `flutter run --release` still works.
- [x] **iOS project** updated with the same changes Flutter's own migrators make:
  - Deployment target raised from 11.0 to 13.0.
  - `@UIApplicationMain` replaced with `@main`.
  - `MinimumOSVersion` removed from `AppFrameworkInfo.plist`.
- [x] **`pubspec.lock`** upgraded with `flutter pub upgrade`, staying inside the existing `pubspec.yaml` ranges. The old lock pinned `win32 5.1.1`, which doesn't compile on Dart 3.5+.
- [x] **`build-android.sh`** and **`build-ios.sh`** added. Their output goes to `dist/`, which is git-ignored.

**Verified**
- In the `ghcr.io/cirruslabs/flutter:stable` image (Flutter 3.44.0), `./build-android.sh` builds `dist/gym-progression-v1.0.0.apk`:
  - Package `io.github.lolluzzo.gymprogression`, versionCode 1, minSdk 24, targetSdk 36.
  - Signed with the keystore from `key.properties`.
- `flutter analyze`: 0 errors and 15 infos (see section 6).

**Not verified**
- `build-ios.sh`, because iOS can only be built on macOS.
- `flutter test` fails (see 6.2).

## 2. Toolchain (one time)

- Flutter **3.44 stable**. Run `flutter doctor` to check the setup.
- For Android: the Android SDK (the build installs NDK 28 and CMake 3.22 automatically) and JDK 17 or newer.
- For iOS, on a Mac: Xcode with the iOS platform installed.
  - CocoaPods isn't needed: Flutter 3.44 uses Swift Package Manager by default.
  - The first iOS build adds the SwiftPM integration to `ios/Runner.xcodeproj`. **Commit that change.**

## 3. Android signing (one time, before the first release)

> Back up the keystore and its passwords outside the repo, for example in a password manager.
> If you lose them, you can't publish updates. Users would have to uninstall the app, and uninstalling deletes their workouts.

```bash
mkdir -p ~/keys
keytool -genkey -v -keystore ~/keys/gym-progression-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

If you don't have a JDK, you can run the same command with Docker:

```bash
docker run --rm -it --user "$(id -u):$(id -g)" -v ~/keys:/keys ghcr.io/cirruslabs/flutter:stable \
  keytool -genkey -v -keystore /keys/gym-progression-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties`. It's already git-ignored, so never commit it.

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=upload
storeFile=/home/<you>/keys/gym-progression-upload.jks
```

## 4. Release procedure (every version)

1. Bump `version:` in `pubspec.yaml`, for example `1.0.1+2`.
   **The build number after `+` must increase with every release.** Android refuses to install a lower versionCode over a higher one.
2. Build Android: run `./build-android.sh`. It produces `dist/gym-progression-v<version>.apk`.
3. Build iOS on the Mac: run `./build-ios.sh`. It produces:
   - `build/ios/archive/Runner.xcarchive`
   - `dist/gym-progression-v<version>-unsigned.ipa`
4. Tag the release and publish it:
   ```bash
   git tag v1.0.1 && git push origin v1.0.1
   gh release create v1.0.1 dist/* --title "v1.0.1" --notes "..."   # or upload the files in the GitHub web UI
   ```

## 5. Installing on devices

**Android**
1. Download the APK from the GitHub release.
2. Allow "Install unknown apps" for the browser or file manager you used.
3. Install the APK.

New versions install over the old one and keep the data, as long as they're signed with the same keystore.

**iOS with a free Apple ID**
- **Your own iPhone, from the Mac:**
  1. Open `ios/Runner.xcworkspace` in Xcode.
  2. Under Signing & Capabilities, set Team to your Personal Team.
  3. Connect the phone and run `flutter run --release`.
  4. On the iPhone, enable Developer Mode (Settings → Privacy & Security).
  5. Trust the certificate under Settings → General → VPN & Device Management.
- **Other iPhones, from GitHub:** they sideload the unsigned IPA with **Sideloadly** or **AltStore**, which re-sign it with their own Apple ID.
- **Limits of a free account:**
  - The signature expires after **7 days**. Refresh or reinstall over the same app to keep the data.
  - At most 3 sideloaded apps per device.
  - At most 10 new App IDs per week.
- A paid Apple Developer account ($99/yr) removes the 7-day limit by using Ad Hoc builds, which last 1 year and need registered device UDIDs.

## 6. Code review findings

### Must fix before sharing the app

1. **The workout editor attaches values to the wrong exercises.** See `lib/screens/workout_editor_screen.dart:78-91`.
   - Existing exercises are matched to the edited list by index.
   - For example, deleting exercise 1 of [A, B, C] saves B with A's `id`, weight and reps.
   - Reordering has the same effect.
   - Fix: keep each controller paired with its original `ExerciseEntry.id`, instead of looking up `previousExercises[index]`.
2. **`flutter test` fails.** `test/widget_test.dart` is still the counter template from `flutter create`.
   - Replace it with a smoke test that calls `SharedPreferences.setMockInitialValues({})` and then pumps `MyApp`.
   - Note that `main()` also initializes the database, and `MyApp` alone doesn't.
3. **The Android app label is `gym_progression`**, which is the name shown under the app icon. Set `android:label="Gym Progression"` in `android/app/src/main/AndroidManifest.xml`.
4. **App icon**: the app still uses the default Flutter icon. The `flutter_launcher_icons` package can generate the Android and iOS icons.

### Should fix

5. **Overlapping database calls can fail with `database_closed`.** See `lib/services/exercise_log_storage.dart:44-106`.
   - Every call opens and then closes the database.
   - sqflite returns the same shared instance for the same path.
   - So if two calls overlap (for example, a double tap on "Save log"), one can close the database while the other is still writing.
   - Fix: open the database once and keep the `Future<Database>` in a static field.
6. **Typed values are lost when leaving the screen.** In `lib/screens/workout_detail_screen.dart`, the back button discards weight/reps silently. Only "Save progress" and "Complete workout" store them.
   - Fix: wrap the screen in `PopScope` and either confirm before leaving or save automatically.
7. **There's no way to delete a workout** (`lib/screens/StartUpApp.dart`).
8. **Exercise history is keyed by exercise name** (`workout_detail_screen.dart:113`, `exercise_log_storage.dart:97`).
   - Renaming an exercise disconnects it from its history.
   - Two workouts that use the same exercise name share one history. That may be what you want, but it should be a deliberate choice.
9. **There's no backup or export.** Workouts live as JSON in SharedPreferences and the logs live in SQLite.
   - Uninstalling deletes both. That matters more for a sideloaded app, because a broken install often has to be fixed by uninstalling.
   - Consider adding JSON export/import, and possibly moving workouts into SQLite as well.
10. **Weight and reps are free text**, with no numeric validation. With an Italian keyboard you get `72,5`. Normalize the values before you add progress charts (`fl_chart`).

### Cleanup (`flutter analyze`: 15 infos, no errors)

11. **Dead code:**
    - `lib/widgets/Loader.dart` is unused, and it calls `Navigator.push` inside `build()`, so it would loop or throw if ever used.
    - `lib/screens/Dashboard.dart` is empty and unused.
    - Delete both.
12. **File names**: `Dashboard.dart`, `StartUpApp.dart` and `Loader.dart` trigger the `file_names` lint. Rename them to snake_case.
13. **Deprecated APIs:**
    - Replace `withOpacity(x)` with `withValues(alpha: x)` (`StartUpApp.dart:215`, `workout_detail_screen.dart:155`, `exercise_history_logs.dart:240`).
    - Replace `surfaceVariant` with `surfaceContainerHighest`.
14. **Duplicated code**: `_weekKeyFor` exists in both `StartUpApp.dart:151` and `workout_detail_screen.dart:104`. Move it into one shared helper.
15. **Repo housekeeping:**
    - `README.md` is still the Flutter template plus the pasted spec, and it has no install instructions.
    - The `pubspec.yaml` description is still "A new Flutter project.".
    - `.vscode/settings.json` points to a path on another machine.

### Optional

- **APK size is 54 MB.** It's a universal APK covering 3 ABIs, and it also bundles `libsqlite3.so` from `sqflite_common_ffi`, which only the desktop targets need.
  `flutter build apk --split-per-abi` produces an arm64 APK of roughly 19 MB, but users then have to pick the right file.
- **Features from the README spec that aren't implemented yet:** rest timer, exercise catalog, default dark mode, Riverpod providers, progress charts.
- **CI:** a GitHub Actions workflow could build the APK and IPA on every tag, on a macOS runner. It isn't set up for now.
- **Other platforms:** macOS, Linux, Windows and web still use the `com.example` IDs. They don't matter for mobile.
