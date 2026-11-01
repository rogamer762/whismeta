import SwiftUI

struct ContentView: View {
    @ObservedObject var probe: AudioProbe

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Whis · pronounced whees").font(.headline)
                    Text("This is a hardware test, not the finished assistant. It tests hearing your wake word while YouTube Music plays. No AI key is needed.")
                        .font(.subheadline)
                }

                Section("1 · Listen") {
                    Picker("Microphone", selection: $probe.inputMode) {
                        ForEach(AudioProbe.InputMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .disabled(probe.isRunning || probe.isStarting)
                    Text("Glasses mode may change music quality. iPhone mode tests whether the phone can hear you while the glasses play music.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(probe.isRunning ? "Stop listening" : "Start listening") {
                        if probe.isRunning { probe.stop() }
                        else { Task { await probe.start() } }
                    }
                    .disabled(probe.isStarting)
                    Text(probe.status)
                    LabeledContent("Wake detections", value: String(probe.wakeCount))
                    Text("Say “whees” naturally, then “whees, play lofi on YouTube Music.” This version uses experimental on-device transcription, not a trained wake-word model.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !probe.transcript.isEmpty {
                        Text(probe.transcript).textSelection(.enabled)
                    }
                }

                Section("2 · Check the route") {
                    Text(probe.route).font(.caption.monospaced()).textSelection(.enabled)
                    Button("Refresh route") { probe.refreshRoute() }
                    Text("Start a song in YouTube Music. Return here, start listening, then lock the phone. Say whees with your phone in your pocket. Repeat after two minutes and check whether music sounds normal.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Mark: music sounds normal") { probe.record("User observation: music sounds normal") }
                    Button("Mark: music degraded or stopped") { probe.record("User observation: music degraded or stopped") }
                    Button("Mark: said whees while locked") { probe.record("User observation: attempted wake while locked (marked after returning)") }
                }

                Section("3 · Test music handoff") {
                    TextField("Song, artist, or playlist", text: $probe.musicQuery)
                        .textInputAutocapitalization(.never)
                    Button("Open YouTube Music search") { probe.openSearch() }
                    Text("Opening search is not an autoplay test. The link may open in a browser. Siri working with YouTube Music does not let this app silently invoke Siri.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Existing shortcut name (optional)", text: $probe.shortcutName)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Run named shortcut with this query") { probe.runShortcut() }
                        .disabled(probe.shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Toggle("Run shortcut after “Whis, play…”", isOn: $probe.autoHandoff)
                        .disabled(probe.shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("Optional experiment: create a shortcut using YouTube Music actions available on your phone. It must accept text input. This app does not create the shortcut or assume those actions exist. Test while unlocked first; iOS may require unlocking or confirmation.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Mark: requested track played") { probe.record("User observation: requested track played") }
                    Button("Mark: handoff failed or needed a tap") { probe.record("User observation: handoff failed or needed interaction") }
                }

                Section("4 · Share test results") {
                    Text("Audio is never saved. Live transcripts stay in memory. Reports include device names, route events, wake matches and your marked observations; no full transcripts or keys.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Prepare report") { probe.exportReport() }
                    if let url = probe.exportURL {
                        ShareLink("Share test report", item: url)
                        Text("Report is a snapshot. Tap Prepare report again to include newer events.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Clear report and transcript", role: .destructive) { probe.clearReport() }
                }

                Section("Recent events") {
                    ForEach(Array(probe.events.suffix(12).reversed().enumerated()), id: \.offset) { _, event in
                        Text(event).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Whis Probe")
        }
    }
}
