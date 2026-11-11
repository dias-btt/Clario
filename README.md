# Clario

Clario is an iOS app that helps you capture unstructured thoughts and turn them into **tasks**, **ideas**, and **notes** using OpenAI. The UI is built with **SwiftUI**, persistence with **SwiftData**, and the default model integration targets the OpenAI Chat Completions API.

## Features

- **Brain capture** — write a free-form thought; the app asks the model to return structured JSON (tasks, ideas, notes) and saves items locally.
- **Three tabs** — Tasks (with Today / Next / Done groupings), Ideas (grid), Notes.
- **In-app language switch** — globe button in the navigation bar; choose **English**, **Русский**, or **Қазақша** (stored in `UserDefaults`, no app restart required).
- **Localized strings** — `Localizable.strings` under `Clario/Resources/Localize/` (`en.lproj`, `ru.lproj`, `kk.lproj`).

## Requirements

- **Xcode** compatible with the project’s deployment target (see `IPHONEOS_DEPLOYMENT_TARGET` in the Xcode project; currently **iOS 26.1**).
- A valid **OpenAI API key** with access to the configured chat model.

## Setup

1. Clone the repository and open `Clario.xcodeproj` in Xcode.
2. Provide your **own** OpenAI API key for local development (never commit it):
   - In Xcode choose **Product → Scheme → Edit Scheme… → Run → Arguments → Environment Variables**.
   - Add `OPENAI_API_KEY` with your key as the value.
   - Leave the scheme **unshared** ("Shared" unchecked). Unshared schemes live under `xcuserdata/`, which is git-ignored. A shared scheme is written to `xcshareddata/` and **would be committed**.

How the key is resolved (see `RuntimeOpenAIConfiguration` in `Clario/Services/OpenAIService.swift`):

- **Debug builds:** the key is read only from the `OPENAI_API_KEY` process environment variable. Xcode sets this variable only when it launches the app; it is not stored in the app binary.
- **Release builds** (Archive, TestFlight, App Store): no key is resolved and AI features report a missing-key error. Builds never read a key from `Info.plist`, build settings, or any other bundled resource.

Do **not** put API keys in `Info.plist`, `project.pbxproj` build settings (`INFOPLIST_KEY_*`), or a shared scheme. Anything in those files ends up in the repository and/or the shipped app bundle, where anyone can extract it.

## Architecture (short)

| Area | Role |
|------|------|
| `ClarioApp.swift` | App entry, SwiftData `ModelContainer`. |
| `ContentView` | Tab navigation, composer sheet, language toolbar. |
| `BrainCaptureViewModel` | Orchestrates AI call and inserts `TaskItem` / `IdeaItem` / `NoteItem`. |
| `OpenAIService` | HTTP client for OpenAI chat completions + JSON schema response. |
| `AppLanguageStore` | Selected language code + loading strings from the matching `.lproj` bundle. |

## Project layout

```
Clario/
├── Models/           # SwiftData models (tasks, ideas, notes)
├── Views/            # Screens and reusable UI
├── ViewModels/
├── Services/         # AI protocol + OpenAI implementation
├── Resources/Localize/
│   ├── en.lproj/
│   ├── ru.lproj/
│   └── kk.lproj/
└── Support/          # Preview data, language store
```

## Building

```bash
xcodebuild -scheme Clario -destination 'platform=iOS Simulator,name=<Your Simulator>' build
```

Replace `<Your Simulator>` with a simulator name listed by `xcrun simctl list devices`.

## Security note

- Treat API keys like passwords. Use only your own key, and only through the Debug scheme environment variable described above.
- Mobile apps cannot keep a secret. A production release must not embed a developer-owned OpenAI key. Route AI requests through a backend or proxy you control, which holds the key and applies authentication and rate limits.
- `.gitignore` does not affect files that are already tracked. Before committing, check `git diff --cached` for credentials.
- If a key is ever committed, revoke it immediately in the OpenAI dashboard. Removing it in a later commit does not remove it from Git history.

## License

Add a license file if you distribute this project publicly.
