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
4. *Note: Since this is an unsigned application, you may need to go to System Settings -> Privacy & Security and click "Open Anyway" on the first launch.*

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

If you prefer to build it yourself:

```bash
git clone https://github.com/tor-knight/VoiceInput.git
cd VoiceInput
make install
```
