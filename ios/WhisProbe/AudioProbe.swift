import AVFoundation
import Combine
import Speech
import UIKit

// The audio render callback is not on the main thread. Serializing replacement
// and append keeps a retiring recognition request from receiving new buffers.
private final class AudioFeed {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func replace(_ next: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        let previous = request
        request = next
        previous?.endAudio()
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        request?.append(buffer)
        lock.unlock()
    }
}

@MainActor
final class AudioProbe: ObservableObject {
    enum InputMode: String, CaseIterable, Identifiable {
        case glasses = "Glasses microphone"
        case phone = "iPhone microphone"
        var id: String { rawValue }
    }

    @Published var inputMode: InputMode = .glasses
    @Published var status = "Ready to test"
    @Published var isRunning = false
    @Published var isStarting = false
    @Published var transcript = ""
    @Published var route = ""
    @Published var wakeCount = 0
    @Published var musicQuery = ""
    @Published var events: [String] = []
    @Published var shortcutName = ""
    @Published var autoHandoff = false
    @Published var exportURL: URL?

    private let session = AVAudioSession.sharedInstance()
    private let engine = AVAudioEngine()
    private let feed = AudioFeed()
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var rotationTask: Task<Void, Never>?
    private var settleTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var generation = UUID()
    private var didWake = false
    private var tapInstalled = false

    init() {
        for name in [AVAudioSession.routeChangeNotification, AVAudioSession.interruptionNotification,
                     AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] notification in
                // Extract plain values before crossing actors; don't retain Notification.
                let eventName = notification.name.rawValue
                let kind = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.record(eventName + (kind.map { " type=\($0)" } ?? ""))
                    if eventName == AVAudioSession.mediaServicesWereResetNotification.rawValue {
                        self.stop(message: "Audio services reset. Stop and reopen the app before retrying.")
                    } else if eventName == AVAudioSession.interruptionNotification.rawValue,
                              kind == AVAudioSession.InterruptionType.began.rawValue {
                        self.stop(message: "Audio interrupted. Tap Start to try again.")
                    }
                    self.refreshRoute()
                }
            })
        }
        refreshRoute()
    }

    func start() async {
        guard !isRunning && !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        let micAllowed = await withCheckedContinuation { continuation in
            session.requestRecordPermission { continuation.resume(returning: $0) }
        }
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard micAllowed && speechAllowed else {
            status = "Allow Microphone and Speech Recognition in Settings, then retry."
            record(status)
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            status = "On-device English recognition is unavailable. Check language downloads and retry."
            record(status)
            return
        }
        self.recognizer = recognizer
        do {
            // No ducking: the test must reveal whether listening coexists with music.
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
            try session.setActive(true)
            let expected: AVAudioSession.Port = inputMode == .glasses ? .bluetoothHFP : .builtInMic
            guard let selected = session.availableInputs?.first(where: { $0.portType == expected }) else {
                throw ProbeError.message(inputMode == .glasses
                    ? "No Bluetooth headset microphone found. Connect your glasses in iPhone Bluetooth settings."
                    : "The iPhone microphone is unavailable.")
            }
            try session.setPreferredInput(selected)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 && format.channelCount > 0 else {
                throw ProbeError.message("The audio route has no usable input. Reconnect the glasses and retry.")
            }
            isRunning = true
            beginRecognition()
            let feed = self.feed
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                feed.append(buffer)
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            status = "Listening for whees"
            record("Started: \(inputMode.rawValue); on-device recognition only")
            refreshRoute()
            if session.currentRoute.inputs.first?.portType != expected {
                stop(message: "iOS selected a different microphone. Review the route and retry.")
            }
        } catch {
            stop(message: error.localizedDescription)
        }
    }

    func stop(message: String = "Stopped") {
        isRunning = false
        generation = UUID()
        rotationTask?.cancel()
        settleTask?.cancel()
        feed.replace(nil)
        recognitionTask?.cancel()
        recognitionTask = nil
        engine.stop()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        status = message
        record(message)
        refreshRoute()
    }

    private func beginRecognition() {
        guard isRunning, let recognizer else { return }
        let token = UUID()
        generation = token
        rotationTask?.cancel()
        settleTask?.cancel()
        feed.replace(nil)
        recognitionTask?.cancel()
        didWake = false
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.contextualStrings = ["Whis", "Whees", "YouTube Music"]
        feed.replace(request)
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal ?? false
            let failure = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, self.isRunning, self.generation == token else { return }
                if let text { self.handleTranscript(text, token: token) }
                if let failure {
                    self.stop(message: "Recognition stopped: \(failure)")
                } else if final {
                    self.finishUtterance()
                }
            }
        }
        // Rotate short-lived speech requests without closing the Bluetooth mic.
        // Whether this remains alive when locked is a hardware test, not assumed.
        rotationTask = Task { [weak self] in
            for _ in 0..<45 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, self.isRunning, self.generation == token else { return }
                self.refreshRoute()
                let expected: AVAudioSession.Port = self.inputMode == .glasses ? .bluetoothHFP : .builtInMic
                guard self.engine.isRunning,
                      self.session.currentRoute.inputs.first?.portType == expected else {
                    self.stop(message: "Audio stopped or the microphone changed. Review the route and tap Start to retry.")
                    return
                }
            }
            guard !Task.isCancelled, let self, self.isRunning, self.generation == token else { return }
            self.record("Rotating on-device recognition request")
            self.beginRecognition()
        }
    }

    private func handleTranscript(_ text: String, token: UUID) {
        transcript = text
        guard let match = WakePhrase.match(text) else { return }
        if !didWake {
            didWake = true
            wakeCount += 1
            record("Wake detected as '\(match.heardName)' in \(UIApplication.shared.applicationState == .active ? "foreground" : "background")")
        }
        musicQuery = WakePhrase.musicQuery(match.command) ?? ""
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled, let self, self.isRunning, self.generation == token else { return }
            self.finishUtterance()
        }
    }

    private func finishUtterance() {
        let query = didWake ? musicQuery : ""
        beginRecognition()
        if autoHandoff && !query.isEmpty { runShortcut(query: query) }
    }

    func refreshRoute() {
        let current = session.currentRoute
        let inputs = current.inputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(separator: ", ")
        let outputs = current.outputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(separator: ", ")
        let next = "Input: \(inputs.isEmpty ? "none" : inputs)\nOutput: \(outputs.isEmpty ? "none" : outputs)\n\(Int(session.sampleRate)) Hz"
        if next != route {
            route = next
            record("Route: " + next.replacingOccurrences(of: "\n", with: "; "))
        }
    }

    func openSearch() {
        guard let url = MusicHandoff.searchURL(query: musicQuery.isEmpty ? "lofi" : musicQuery) else { return }
        open(url, label: "YouTube Music search (does not confirm playback)")
    }

    func runShortcut(query: String? = nil) {
        guard let url = MusicHandoff.shortcutURL(name: shortcutName, query: query ?? musicQuery) else {
            record("Set the name of an existing shortcut first.")
            return
        }
        open(url, label: "Shortcut handoff (playback not verified)")
    }

    private func open(_ url: URL, label: String) {
        record("Attempt: \(label); app state=\(UIApplication.shared.applicationState.rawValue)")
        UIApplication.shared.open(url, options: [:]) { [weak self] accepted in
            Task { @MainActor [weak self] in
                self?.record("\(label): URL \(accepted ? "accepted" : "rejected"). Check actual result on phone.")
            }
        }
    }

    func record(_ event: String) {
        events.append("\(ISO8601DateFormatter().string(from: Date()))  \(event)")
        if events.count > 300 { events.removeFirst(events.count - 300) }
    }

    func exportReport() {
        let report: [String: Any] = [
            "appVersion": "0.1.0", "ios": UIDevice.current.systemVersion,
            "device": UIDevice.current.model, "inputMode": inputMode.rawValue,
            "wakeCount": wakeCount, "route": route, "events": events,
            "note": "No audio or full transcripts included. Bluetooth device names may appear."
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Whis-test-report.json")
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch { record("Could not export: \(error.localizedDescription)") }
    }

    func clearReport() {
        events.removeAll()
        transcript = ""
        musicQuery = ""
        wakeCount = 0
        exportURL = nil
        try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appendingPathComponent("Whis-test-report.json"))
    }
}

private enum ProbeError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
