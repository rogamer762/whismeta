# Whis for iPhone: first hardware probe

Target: Ray-Ban Meta Wayfarer Gen 2, user's iPhone on iOS 27.0.1,
Windows development, SideStore/AltStore installation, YouTube Premium.
Assistant name: **Whis**, pronounced **whees**.

This is a new, key-free iOS feasibility app. It is **not a completed CJ port**.
No Mac purchase is needed: the included GitHub Actions workflow uses a hosted
macOS runner to compile the app. The [first cloud build succeeded](https://github.com/rogamer762/whismeta/actions/runs/41325377367),
including all four simulator unit tests and the unsigned ARM64 iPhone build.

## Install the existing test build

Open the successful build link above while signed in to GitHub. Under **Artifacts**,
download **WhisProbe-unsigned**, unzip it, and transfer `WhisProbe-unsigned.ipa` to
your iPhone's Files app. Import it through your existing SideStore/AltStore setup
to sign and install it. Allow Microphone and Speech Recognition when the test
app asks. No AI key is needed. This is the hardware probe described below, not
the finished assistant.

## What is implemented

- An iPhone UI for starting/stopping on-device English speech recognition.
- Experimental Whis/whees transcript matching, with optional hey/okay prefixes.
- Glasses Bluetooth microphone mode and an alternative iPhone microphone mode.
- Background audio configuration, request rotation, interruption handling and route logging.
- YouTube Music search links and an optional, user-configured Shortcuts URL handoff.
- A shareable JSON report without audio, full transcripts, API keys or account credentials.
- Simulator unit tests and an unsigned device IPA build workflow.

**Verified:** Xcode compilation for simulator and device, four passing simulator
unit tests, and the unsigned IPA's package structure, permissions and ARM64 executable.

**Not verified:** recognition on this iPhone, locked-screen operation, music quality,
wake-word reliability, and YouTube Music autoplay. This workspace is on Windows;
Xcode compilation and unit tests run in the cloud. Passing simulator tests does
not establish that the required glasses/music experience works on hardware.

**Not implemented:** a trained keyword model, AI conversations, the Windows backend,
Meta camera integration, pause/skip/playlist control, or direct control of the
YouTube Music iPhone app. Siri successfully playing a song does not expose Siri's
capabilities to this app. Opening a URL is not evidence of successful playback.

## Build from Windows

1. Create a GitHub repository, then upload this project's files, including `.github`
   and `ios`. Leave out `upstream` and `.git`; the upstream CJ clone is reference material.
   A private repository uses your account's included Actions minutes and may incur
   charges when those are exhausted. Check GitHub's current billing settings.
2. Open the repository's **Actions** tab. Enable Actions if GitHub asks.
3. Select **Build Whis iPhone probe**, then **Run workflow**. Pushing changes under
   `ios` also starts a build.
4. A successful run provides **WhisProbe-unsigned** under **Artifacts**. Download
   and unzip it to obtain `WhisProbe-unsigned.ipa`.
5. Import the IPA using your existing SideStore/AltStore installation process.
   The workflow does not sign it. Your sideloading tool must sign it with your
   own Apple credentials locally. Do not upload signing credentials to this repo.
   If you haven't set up SideStore/AltStore yet, complete that setup first.
6. If the workflow fails, download **WhisProbe-build-logs** or copy the first
   build error. An IPA cannot be produced by this Windows workspace alone.

The prepared source was published with the user's approval to
[rogamer762/whismeta](https://github.com/rogamer762/whismeta). The build workflow
requires no signing credentials or AI keys. GitHub authentication is needed to
push changes; SideStore/AltStore signs the IPA separately.

## Test on the phone

1. Pair the glasses in iPhone Bluetooth settings. Play a song using the actual
   YouTube Music app, and check that it comes through the glasses normally.
2. Open Whis Probe, choose **Glasses microphone**, tap **Start listening** and
   grant Microphone and Speech Recognition permissions. Recognition requires
   on-device English support; it will stop rather than use server transcription.
   First-time speech model downloads may require internet access through iOS.
3. Confirm the input route is the glasses. Say **whees** and check the wake count.
   The current speech-to-text approach may miss the pronunciation or falsely
   recognize words such as "wheeze"; it is an experiment, not a trained detector.
4. Keep music playing, lock the phone, put it in your pocket, and repeat after
   30 seconds and two minutes. Unlock and compare wake counts and timestamps.
   Background app state is logged; the app cannot independently prove the phone
   was locked, so record your own observations.
5. Mark whether music stayed normal, degraded or stopped. If iOS stops the audio
   engine or interrupts it, restart listening explicitly and include that result.
6. Stop listening. Repeat using **iPhone microphone**. Check the actual input and
   output routes: iOS may still route differently than requested. Test whether the
   phone can hear you from your pocket. This is an alternative experiment, not
   a promise of hearing speech through the glasses' microphone.
7. In **Test music handoff**, try the search button while unlocked. This only
   tests link behavior; it is not autoplay.
8. Optional: inspect the Shortcuts app for YouTube Music actions actually available
   on your phone. If you can create a shortcut accepting text and starting the
   requested music, enter its exact name. Test the shortcut manually first, then
   the button, then enable **Run shortcut after Whis, play…**. The probe passes the
   song query as text input. It cannot create Siri requests or infer unavailable
   Shortcuts actions. Unlock/confirmation prompts or a browser opening count as
   a limitation, not successful hands-free control.
9. Mark the real playback result. Tap **Prepare report**, then **Share test report**.
   Reports include Bluetooth device names; inspect them before sharing. Clear
   removes the in-app log, transcript, and locally generated report file.

There is no voice acknowledgement sound in this probe, to avoid changing the
audio-routing test. The screen's counter and report show wake events.

## Decision after testing

The required experience is "whees, play [song] on YouTube Music" through the glasses
while the phone is locked. Full quality music plus a continuously active glasses
microphone is **unproven**. We must report a degraded-audio result honestly and
agree a workable alternative if the hardware/OS cannot meet both requirements.
Only after the wake/music path is demonstrated should we port the CJ backend to
Windows and connect an AI provider. API keys will be entered locally then.

## References

- [Original CJ project](https://github.com/GhanshyamPaunikar/rayban-meta-god-mode)
- [Meta iOS toolkit](https://github.com/facebook/meta-wearables-dat-ios)
- [On-device speech requests](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)
- [Apple Shortcuts URL scheme](https://support.apple.com/guide/shortcuts/run-a-shortcut-from-a-url-apd624386f42/ios)
- [GitHub macOS runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
