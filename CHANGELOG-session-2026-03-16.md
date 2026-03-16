# Session 2026-03-16 — EchoWrite improvements

## Bug fixes

### Accessibility permission not persisting
- **Problem:** macOS kept asking for Accessibility permission on every transcription, never saving it as enabled.
- **Root cause:** `EchoWrite.entitlements` contained a bogus entitlement `com.apple.security.accessibility` (doesn't exist in Apple's entitlement catalog). This made macOS TCC distrust the app's code signature and refuse to persist the permission.
- **Fix:** Removed the invalid entitlement. Only `com.apple.security.device.audio-input` remains.
- **Files:** `EchoWrite.entitlements`

### Accessibility prompt on launch
- Added `AXIsProcessTrusted` check + `requestAccessibilityPermission()` in `applicationDidFinishLaunching` so the user is prompted once at startup instead of on first transcription.
- **Files:** `AppDelegate.swift`

### Empty transcription guard
- If the transcribed text is empty/whitespace, it now skips the LLM post-processing entirely to avoid wasting an API call.
- **Files:** `AppDelegate.swift`

## Features

### Claude Code CLI as LLM provider — model aliases
- Changed Claude Code's available models from full IDs (`claude-sonnet-4-5-20250514`, etc.) to short aliases: `haiku`, `sonnet`, `opus`.
- Default model set to `haiku`.
- Claude Code CLI resolves these to the latest version automatically.
- **Files:** `Models/LLMProvider.swift`

### Style presets for AI enhancement
- Added `StylePreset` enum with 8 presets: Custom, Formal, Elegant, Casual, Friendly, Passive-Aggressive, Concise, Technical.
- Each preset fills the Style Instructions field with a tailored prompt.
- Editing the prompt manually switches back to "Custom".
- UI: 4-column grid of selectable buttons in the AI Enhance panel.
- **Files:** `Models/Enums.swift`, `Views/Settings/LLMPanel.swift`

### Language-aware LLM responses
- Updated the LLM system prompt to enforce responding in the same language as the input text (no accidental translations).
- **Files:** `TextPostProcessor.swift`

### Translation moved to AI Enhance panel
- **Removed** the "Translate to English" toggle from General settings.
- **Added** a "Translate to" language picker in the AI Enhance panel with all supported languages.
- Translation is now performed by the LLM (not whisper), supporting any target language, not just English.
- Whisper always transcribes in the original language now (`translate: false`).
- New `llmTranslateLanguage: Language?` property in AppState with full persistence.
- **Files:** `AppState.swift`, `Persistence.swift`, `AppDelegate.swift`, `TextPostProcessor.swift`, `Views/Settings/GeneralPanel.swift`, `Views/Settings/LLMPanel.swift`

### Floating window on all monitors
- Changed from a single `NSPanel` to one panel per physical screen (`NSScreen.screens`).
- All panels show/hide together and are centered at the bottom of each monitor.
- **Files:** `AppDelegate.swift`

### Floating window pipeline feedback
- The floating window now stays visible through the full pipeline (recording, transcribing, enhancing) instead of closing when recording stops.
- Three visual states:
  - **Recording:** Red pulsing dot + waveform + timer
  - **Transcribing:** Orange waveform icon + "Transcribing" label + spinner
  - **Enhancing:** Purple sparkles icon + "Enhancing" label + spinner
- Window only closes after the entire pipeline completes (or on error).
- **Files:** `AppDelegate.swift`, `Views/FloatingRecordingView.swift`

### Floating window redesign
- Borderless `NSPanel` (`.borderless` + `.nonactivatingPanel`) — no system chrome.
- Pill-shaped design with `cornerRadius: 22, style: .continuous`.
- Clean shadow (double layer: diffuse + tight).
- Horizontal layout: status indicator, center content, trailing info.
- Pulsing animation modifier for all status indicators.
- Waveform bars with dynamic color (low/mid/high).
- **Files:** `AppDelegate.swift`, `Views/FloatingRecordingView.swift`

### Theme system
- New `AppTheme` enum with 9 themes: System, Light, Dark, Midnight, Ocean, Forest, Sunset, Rose, Lavender.
- `ThemeColors` struct with 10 color properties: accent, floating background/text/secondary, waveform low/mid/high, card background/border, sidebar accent.
- Injected via SwiftUI `EnvironmentValues` (`\.themeColors`).
- `settingsCard` helper updated to read theme from environment.
- Floating window reads theme directly from `appState.appTheme`.
- New **Appearance** section in Settings sidebar with:
  - Theme grid (3 columns) with color swatches per theme.
  - Live floating window preview.
- Full persistence via UserDefaults.
- **Files:** `Models/AppTheme.swift` (new), `Models/Enums.swift`, `State/AppState.swift`, `State/Persistence.swift`, `Views/Settings/SettingsHelpers.swift`, `Views/Settings/AppearancePanel.swift` (new), `Views/SettingsView.swift`, `Views/FloatingRecordingView.swift`

## Files changed (summary)

| File | Status |
|---|---|
| `EchoWrite.entitlements` | Modified |
| `Models/AppTheme.swift` | **New** |
| `Models/Enums.swift` | Modified |
| `Models/LLMProvider.swift` | Modified |
| `State/AppState.swift` | Modified |
| `State/Persistence.swift` | Modified |
| `AppDelegate.swift` | Modified |
| `TextPostProcessor.swift` | Modified |
| `Views/FloatingRecordingView.swift` | Modified |
| `Views/SettingsView.swift` | Modified |
| `Views/Settings/AppearancePanel.swift` | **New** |
| `Views/Settings/GeneralPanel.swift` | Modified |
| `Views/Settings/LLMPanel.swift` | Modified |
| `Views/Settings/SettingsHelpers.swift` | Modified |
