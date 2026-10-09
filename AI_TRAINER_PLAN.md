# Plan: local AI trainer (text-to-text)

Goal: an offline assistant that can:

1. answer questions about exercises
2. turn free-form notes into workouts

Status as of 2026-10-07: analysis only. The rule-based import (`lib/services/workout_import.dart`) is done and is the base for step 2.

## 1. Verdict

**Feasible, but the model is the heavy part.** A model that answers in useful sentences weighs 0.3–1 GB and needs about 1 GB of RAM. Neither the facts about exercises nor the import of tidy notes needs a model. Build it in layers, and add the model last, as an optional download.

| Job | Needs a model? | Why |
| --- | --- | --- |
| Import a tidy note (`Name` + `- exercise` lines) | No | Done. The parser is instant, deterministic and tested. |
| Import a messy note ("push: panca 4x8 80kg, poi croci") | Yes, or a smarter parser | Free text, typos, mixed languages. |
| Facts about an exercise (muscles, equipment, how-to) | No | A bundled catalog is always right. A 1B model makes up facts. |
| Open questions ("how do I get past a bench plateau?") | Yes | Generative by nature. |

## 2. Options

### A. No model: an exercise catalog (do this first)

- Bundle [free-exercise-db](https://github.com/yuhonas/free-exercise-db) as a JSON asset, without its images. It's public domain: about 800 exercises with muscles, equipment and step-by-step instructions.
- An "About this exercise" sheet on the workout screen, matched by exercise name.
- The catalog also suggests **alternatives**: same primary muscle, different equipment. The user adds them to the editor's alternative chips with one tap.
- Cost: small. No download, and it works on every device.
- Gap: the catalog is in English. Notes written in Italian ("panca piana") need an alias table that maps names to catalog entries.

### B. An open model, downloaded on demand ([flutter_gemma](https://pub.dev/packages/flutter_gemma))

- Runs small models on Android and iOS, with GPU support. Its [model list](https://fluttergemma.dev/docs/models) includes Gemma 3 1B, Gemma 3 270M, FunctionGemma 270M (made for structured output) and Qwen3 0.6B.
- Download the model from Settings ("Download AI trainer, ~X MB"). Don't ship it in the APK or IPA. Check the size on the model card: roughly 0.3–0.6 GB quantized for 270M–1B.
- Quality: models this size reformat text well and give poor fitness advice. Ground each answer in the catalog entry and the user's own logs, and keep answers short.
- **Main risk for this repo:** the plugin's native iOS frameworks have to build with xlinux. Run a spike before committing to it.

### C. Models built into the OS (no download)

- **iOS 26:** Apple's [Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/286/), an on-device model of about 3B parameters. Its guided generation returns typed structured output, which suits import very well.
  - Only on Apple Intelligence iPhones.
  - The API is Swift-only. Flutter wrappers exist, for example [foundation_models_framework](https://pub.dev/packages/foundation_models_framework/versions).
  - xlinux needs the iOS 26 SDK.
- **Android:** Gemini Nano through the [ML Kit Prompt API](https://developers.google.com/ml-kit/genai). It works on Pixel 9 and newer and on recent flagships, and the API is still early.
- Pros: no download, better quality. Cons: only some devices have them, so A or B is still needed as a fallback. It also means two native integrations.

## 3. Recommended roadmap

1. **Catalog (no AI).** Add the JSON asset, the "About this exercise" sheet and "Suggest alternatives" in the editor.
   Check: unit tests for name matching, including Italian aliases.
2. **Spike on flutter_gemma.** Gemma 3 1B or FunctionGemma 270M, behind a Settings toggle.
   Check: the iOS build works with `./build-ios-linux.sh`, and tokens per second on your phone are acceptable.
3. **"Fix with AI" on the import screen**, shown when the parser finds nothing.
   - The model rewrites the note into the same `Name` / `- exercise` format.
   - That text goes through `parseWorkoutNotes` and the existing preview, which is the safety net: nothing is saved until the user confirms.
   - Check: a set of real messy notes produces the expected workouts.
4. **"Ask the trainer" chat.**
   - The prompt combines the catalog entries for the exercises mentioned with the user's last logs for them.
   - The answer is streamed and kept short.
   - Check: manual review of answers to 20 typical questions.
5. **Optional:** Foundation Models on iOS where it's available, as a better backend behind the same interface.

## 4. Design notes

- One interface, so backends can be swapped:
  ```dart
  abstract class TrainerModel {
    Future<bool> isAvailable();
    Future<void> download(void Function(double progress) onProgress);
    Stream<String> generate(String prompt, {int maxTokens = 256});
  }
  ```
- For import, ask for the plain-text note format rather than JSON. Small models follow it more reliably, and it reuses the parser and its tests.
- Everything stays on the device. Keep the model file in the app support directory, with a "Delete model" button in Settings.

## 5. Open questions

- Which phones must it run on? That decides between B and C.
- Are your notes in Italian, English or both? That decides the alias table, and whether a multilingual model (Qwen, Gemma) is needed.
