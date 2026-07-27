# VoiceInput 🎙️

A native, elegant, and intelligent macOS speech-to-text menubar application. 
Press and hold the `Fn` key to dictate anywhere. Powered by Apple's on-device Speech framework for blazing-fast real-time transcription, and refined by advanced LLMs (OpenAI, Anthropic, Gemini, DeepSeek, Ollama, etc.) for flawless accuracy, perfect punctuation, and technical vocabulary correction.

## Features ✨
- **Press-to-talk**: Hold down the `Fn` key anywhere in macOS to start dictating. Release to type.
- **Native HUD**: A beautiful, unobtrusive, translucent capsule (Dynamic Island style) shows your live transcription and a recording timer.
- **AI-Powered Refiner**: Automatically corrects speech recognition errors, homophones (e.g., recognizing technical terms like "Python" or "JSON" correctly instead of literal Chinese translations), and intelligently adds punctuation.
- **Multi-Model Support**: Bring your own API key. Supports OpenAI, Gemini, Claude, DeepSeek, OpenRouter, and even local LLMs via Ollama.
- **Secure**: Your API Key is securely stored in the macOS Keychain.
- **Privacy-First**: No data is sent to the cloud unless you explicitly enable the LLM refiner.

## Installation 📦

You can download the pre-compiled, ready-to-use application from the [Releases](#) page.

1. Download `VoiceInput.app.zip` and extract it.
2. Drag `VoiceInput.app` into your `/Applications` folder.
3. Open it from Launchpad or Spotlight.

> **⚠️ Note: "App is damaged and can't be opened"**
> Since this application is built via GitHub Actions and is not officially notarized by Apple, macOS Gatekeeper may block it and claim the app is "damaged". 
> To fix this, simply open your **Terminal** and run the following command to remove the quarantine attribute:
> ```bash
> xattr -cr /Applications/VoiceInput.app
> ```
> After running this command, you can double-click the app to open it normally. You only need to do this once.

## Configuration ⚙️

1. Click the microphone icon in your macOS status bar and select **Settings**.
2. **Enable LLM**: Check the box if you want AI to fix punctuation and correct technical terms.
3. **Provider**: Choose your LLM provider.
4. **API Key**: Enter your API Key (securely stored in Keychain).
5. **Model**: Set your preferred model (e.g., `gpt-4o-mini`, `gemini-3.6-flash`, `claude-3-5-haiku-latest`).

### System Prompt 🧠
VoiceInput uses the following highly optimized prompt to refine your text without changing your meaning:

```text
You are a speech-recognition error corrector and formatter. Your job is to fix \
speech-to-text mistakes AND add proper punctuation to the text the user provides.

Rules (follow strictly):
1. Fix speech-recognition errors, for example:
   • Chinese homophones that are actually English technical terms
     (e.g. "配森" → "Python", "杰森" → "JSON", "基特" → "Git")
   • Obvious misheard words.
2. Add appropriate punctuation (commas, periods, question marks) to make the text \
   grammatically correct and easy to read. 
3. Do NOT rephrase, rewrite, summarise, or change the original meaning of the text.
4. Output ONLY the corrected and punctuated text. No explanations, no markdown.
```

## Building from Source 🛠️

If you prefer to build it yourself (macOS):

```bash
git clone https://github.com/tor-knight/VoiceInput.git
cd VoiceInput
make install
```

## iPhone Version (iOS App & Keyboard Extension) 📱

VoiceInput includes an iOS app and custom keyboard extension sharing the same code core library target (`VoiceInputCore`).

### Features:
- **Main App**: Contains recording screen, complete history view with pagination, daily summary reports, and preferences settings.
- **Keyboard Extension**: Allows you to dictate and paste LLM-refined text in *any* iOS app (e.g. Messages, Notes, Safari) by selecting the custom VoiceInput keyboard.
- **Shared Database & Settings**: The App and Keyboard Extension share preferences and SQLite database entries using iOS App Groups container.

### Setup and Installation:
1. Open `VoiceInputMobile/VoiceInputMobile.xcodeproj` in Xcode.
2. Select the `VoiceInputMobile` target, and under **Signing & Capabilities**, select your Apple Developer Team. (A free personal developer account works for installing onto your own device).
3. Ensure the App Group identifier `group.com.voiceinput.shared` is registered and ticked (if you use a different Bundle ID, update the App Group identifier in the app and extension entitlements and matching code sites).
4. Connect your iPhone and run the project (`Cmd + R`) to install.
5. **Enable Custom Keyboard**:
   - On your iPhone, go to **Settings** -> **General** -> **Keyboard** -> **Keyboards** -> **Add New Keyboard...**
   - Under Third-Party Keyboards, select **VoiceInput**.
   - Tap **KeyboardExtension - VoiceInput** in the list, and turn on **Allow Full Access**. *(This is required to make network calls to your configured LLM API provider).*

---

## Unit & Integration Tests 🧪

To verify the backend logic (DatabaseManager, Preferences, SyncService, LLMRefiner) without needing `XCTest.framework` (which is unavailable in standard Command Line Tools on macOS without full Xcode installations), compile and execute our custom test runner:

```bash
# Create scratch folder
mkdir -p .scratch

# Compile shared VoiceInputCore library
swiftc -module-cache-path .scratch/module-cache -emit-module -emit-library -module-name VoiceInputCore Sources/VoiceInputCore/*.swift -o .scratch/libVoiceInputCore.dylib

# Compile Test Runner
swiftc -module-cache-path .scratch/module-cache -I .scratch/ -L .scratch/ -lVoiceInputCore Tests/VoiceInputTests/TestRunner.swift -o .scratch/TestRunner

# Run tests
.scratch/TestRunner
```

