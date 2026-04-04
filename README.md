# EchoWrite

**Speak. It types.** A macOS menu bar app that turns your voice into text — right where your cursor is. No cloud, no subscriptions, no data leaving your Mac.

Built on [OpenAI's Whisper](https://github.com/openai/whisper) running locally via [whisper.cpp](https://github.com/ggerganov/whisper.cpp).

---

## Why EchoWrite?

- **100% private** — Everything runs on your Mac. Your audio never leaves the device.
- **Works everywhere** — Text appears wherever your cursor is: emails, code editors, Slack, browsers, terminal. Any app.
- **One hotkey** — Press your shortcut, talk, done. No window switching, no copy-pasting.
- **Actually fast** — Whisper runs natively on Apple Silicon. A 30-second recording transcribes in under 2 seconds with the right model.
- **Free and open source** — No subscriptions, no monthly fees. Whisper runs 100% locally. LLM post-processing is optional and uses your own API keys if you choose to enable it.

## Features

**Two ways to dictate**
- **Batch** — Record everything, then transcribe at once. Great for long thoughts.
- **Live** — See your words appear in real-time as you speak.

**16 languages**
Auto-detects or you choose: English, Spanish, French, German, Italian, Portuguese, Chinese, Japanese, Korean, Russian, Arabic, Hindi, Dutch, Polish, Turkish. Can also translate any of them to English on the fly.

**Pick your model**
21 Whisper models from Tiny (32 MB) to Large v3 Turbo (1.6 GB). Download and switch from within the app — smaller models are faster, larger ones are more accurate. Quantized versions (Q5, Q8) give you a good middle ground.

**LLM post-processing**
- Optionally pass transcribed text through an AI model to correct, reformat, or translate
- Works with OpenAI, Anthropic, Groq, or Claude Code (no API key needed if you already have it installed)
- Built-in style presets: formal, casual, bullet points, summary, and more

**Smart details**
- Auto-stops when you go silent (configurable timeout)
- Text replacements after transcription ("arroba" becomes "@", "hashtag" becomes "#")
- Custom prompts to guide transcription style, vocabulary, and punctuation
- Start/stop sound feedback so you know when it's listening
- Searchable history of your last 50 transcriptions
- Usage dashboard — see how many words you've dictated and how much time you've saved vs typing

## Getting Started

### Requirements

- macOS 14 (Sonoma) or later
- Microphone permission
- Accessibility permission (so EchoWrite can type for you)

### Granting Permissions

EchoWrite needs two permissions to work:

- **Microphone** — Required to record your voice. macOS will prompt you on first use.
- **Accessibility** — Required to type text into other apps. Go to **System Settings → Privacy & Security → Accessibility** and enable EchoWrite.

If you skip Accessibility access, the app will transcribe your voice but won't be able to insert the text — you'll need to paste it manually instead.

### Install (pre-built binary)

Download the latest `EchoWrite-x.x.x-arm64.zip` from the [Releases page](../../releases/latest), unzip it, and move `EchoWrite.app` to your Applications folder.

**First launch — macOS will block it** because the app isn't notarized with an Apple Developer certificate. There are three ways to open it anyway:

**Option A — System Settings (recommended on macOS 15 Sequoia)**
Try to open the app normally. macOS will block it. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**.

**Option B — Right-click (macOS 14 only)**
Right-click `EchoWrite.app` → **Open** → click **Open** in the dialog. You only need to do this once. Note: this no longer works on macOS 15 Sequoia.

**Option C — Terminal**
```bash
xattr -cr /Applications/EchoWrite.app
```
Then open the app normally.

### Build

**1. Get the whisper.cpp framework**

```bash
git clone https://github.com/ggerganov/whisper.cpp
cd whisper.cpp
cmake -B build -DBUILD_SHARED_LIBS=ON -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
cmake --build build --config Release
```

Then package the output as an xcframework and place it in `Frameworks/`:

```bash
xcodebuild -create-xcframework \
  -library build/src/libwhisper.dylib \
  -headers include/ \
  -output Frameworks/whisper.xcframework
```

**2. Build and run**

```bash
swift build && swift run VoiceToText
```

Or just `open Package.swift` in Xcode.

**3. Download a model**

On first launch, go to Settings > Models and grab one:

| If you want... | Pick this | Download |
|----------------|-----------|----------|
| Fastest possible | Base Q5 | 60 MB |
| Good balance | Small Q5 | 190 MB |
| Best accuracy | Large v3 Turbo Q5 | 574 MB |

**4. Set your hotkey, and start talking.**

## Built With

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) — C/C++ port of OpenAI's Whisper model
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) — Native macOS UI
- [AVFoundation](https://developer.apple.com/av-foundation/) — Audio capture
- [CoreGraphics](https://developer.apple.com/documentation/coregraphics) — Keystroke simulation

## License

MIT
