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
2. Provide your API key in one of these ways (do **not** commit secrets):
   - **Environment variable** — set `OPENAI_API_KEY` for the Run scheme in Xcode, or in your shell when launching from the command line.
   - **Info.plist** — add a key `OPENAI_API_KEY` with your key as the value (keep this file out of version control if it contains real credentials).

The app reads the key from the environment first, then from `Info.plist` (see `OpenAIService` / runtime configuration).

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

Treat API keys like passwords: use Xcode scheme environment variables or a local, untracked `Info.plist` override. Rotate any key that was ever committed to a repository.

## License

Add a license file if you distribute this project publicly.
