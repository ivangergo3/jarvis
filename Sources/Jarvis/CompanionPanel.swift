import AppKit
import SwiftUI

// ObservableObject keeps compatibility with the project's command-line SDK/toolchain.
@MainActor private final class CompanionPanelState: ObservableObject {
    @Published var settings = false
    @Published var confirmNew = false
}
@MainActor private final class ApprovalState: ObservableObject {
    @Published var answers: [String: String] = [:]
}
@MainActor private final class ConnectionSettingsState: ObservableObject {
    @Published var executable = CodexExecutable.locate()?.path ?? "Not found"
}

struct CompanionPanel: View {
    @ObservedObject var chat: CompanionModel
    @ObservedObject var voice: LocalVoice
    let proposedScope: ConversationScope
    let motion: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var ui = CompanionPanelState()
    @StateObject private var artwork = CompanionArtwork()

    var body: some View {
        VStack(spacing: 12) {
            companion
            HStack {
                Text(chat.phase.label).font(HUD.mono(9)).foregroundStyle(HUD.cyan)
                Spacer()
                Button {
                    ui.settings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Codex connection settings").accessibilityIdentifier(
                    "companion.settings")
                Button {
                    ui.confirmNew = true
                } label: {
                    Image(systemName: "plus.bubble")
                }
                .disabled(chat.phase.busy || voice.recording).accessibilityLabel(
                    "New Jarvis conversation"
                )
                .accessibilityIdentifier("companion.newChat")
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text("Jarvis chat · \((chat.scope ?? proposedScope).name)")
                    .font(.system(size: 12, weight: .medium)).lineLimit(2)
                Text(
                    chat.scope == nil
                        ? "Context locks when you start a draft."
                        : "Context locked for this conversation."
                )
                .font(.system(size: 10)).foregroundStyle(HUD.muted)
                Text("A separate Codex conversation. Team chats above stay view-only.")
                    .font(.system(size: 10)).foregroundStyle(HUD.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Divider().overlay(HUD.line)
            conversation
            if let approval = chat.approvals.first {
                CompanionApprovalView(approval: approval) { decision, answers in
                    Task { await chat.answer(approval, decision: decision, answers: answers) }
                }.id(approval.id).disabled(chat.answeringApproval)
            }
            if let notice = chat.notice {
                Text(notice).font(.system(size: 11)).foregroundStyle(HUD.gold).textSelection(
                    .enabled
                )
                .accessibilityIdentifier("companion.notice").fixedSize(
                    horizontal: false, vertical: true)
            }
            if chat.phase == .outcomeUnknown {
                Text(
                    "Do not resend automatically. Check the conversation in Codex before starting again."
                )
                .font(.system(size: 11)).foregroundStyle(HUD.gold)
            }
            composer
        }
        .padding(18).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HUD.panel.opacity(0.28))
        .task { await artwork.load() }
        .sheet(isPresented: $ui.settings) { CompanionSettings(voice: voice) }
        .confirmationDialog(
            "Start a new Jarvis chat? This clears the panel, not the saved Codex conversation.",
            isPresented: $ui.confirmNew
        ) {
            Button("Start new chat") { Task { await chat.newConversation() } }
        }
        .onChange(of: chat.draft) { _, text in
            if !text.isEmpty { chat.pinScope(proposedScope) }
        }
        .onChange(of: chat.completedReply) { _, text in if let text { voice.speak(text) } }
        .onAppear {
            voice.onTranscript = { text in
                chat.draft = String(
                    (chat.draft + (chat.draft.isEmpty ? "" : "\n") + text).prefix(16_000))
            }
        }
        .onDisappear {
            voice.cancel()
            voice.stopSpeaking()
            voice.onTranscript = nil
        }
    }

    private var companion: some View {
        TimelineView(
            .animation(
                minimumInterval: 0.25,
                paused: !motion || reduceMotion || scenePhase != .active)
        ) { context in
            let animating = motion && !reduceMotion && scenePhase == .active
            let time = animating ? context.date.timeIntervalSinceReferenceDate : 0
            Group {
                if !artwork.frames.isEmpty {
                    Image(nsImage: artwork.frames[Int(time * 4) % artwork.frames.count])
                        .resizable().interpolation(.high).scaledToFit()
                } else {
                    Image(systemName: "circle.hexagongrid").resizable().scaledToFit()
                        .foregroundStyle(HUD.cyan)
                }
            }.frame(width: 138, height: 138)
                .offset(y: animating ? sin(time * 0.65) * 2 : 0)
                .shadow(color: HUD.cyan.opacity(0.20), radius: 12)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
        }.frame(height: 142)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if chat.messages.isEmpty {
                        Text("Talk to Codex from here.")
                            .font(.system(size: 18, weight: .light)).padding(.top, 12)
                        Text(
                            "Type a request, or use the microphone to make an editable draft. Nothing is sent until you choose Send."
                        )
                        .font(.system(size: 12)).foregroundStyle(HUD.muted).lineSpacing(4)
                    }
                    ForEach(chat.messages) { message in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(message.role == .user ? "YOU" : "CODEX").font(HUD.mono(8))
                                .foregroundStyle(HUD.gold)
                            Text(message.text).font(.system(size: 12)).textSelection(.enabled)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(12).background(
                            HUD.cyan.opacity(message.role == .user ? 0.04 : 0.015),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .id(message.id)
                    }
                    Color.clear.frame(height: 1).id("chat-bottom")
                }
            }
            .onChange(of: chat.messages.last?.text) { _, _ in
                proxy.scrollTo("chat-bottom", anchor: .bottom)
            }
        }.accessibilityIdentifier("companion.conversation")
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 9) {
            if voice.recording {
                HStack {
                    Image(systemName: "mic.fill").foregroundStyle(HUD.gold)
                    Text(
                        voice.session.phase == .authorizing
                            ? "Waiting for permission…"
                            : voice.session.phase == .finishing
                                ? "Finishing transcript…" : "Listening · on this Mac")
                    Spacer()
                    Button("Cancel") { voice.cancel() }.buttonStyle(.plain)
                }.font(.system(size: 11)).foregroundStyle(HUD.gold)
                if !voice.session.transcript.isEmpty {
                    Text(voice.session.transcript).font(.system(size: 11)).lineLimit(3)
                        .foregroundStyle(HUD.muted)
                }
            }
            if let error = voice.error {
                Text(error).font(.system(size: 11)).foregroundStyle(HUD.gold)
            }
            TextEditor(text: $chat.draft).font(.system(size: 12)).scrollContentBackground(.hidden)
                .frame(height: 64).padding(7).background(
                    Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 7)
                )
                .disabled(chat.phase.busy || voice.recording || chat.phase == .outcomeUnknown)
                .accessibilityLabel("Message to Jarvis chat").accessibilityIdentifier(
                    "companion.draft")
            HStack(spacing: 14) {
                Button {
                    if voice.session.phase == .listening {
                        voice.finish()
                    } else if voice.recording {
                        voice.cancel()
                    } else {
                        chat.pinScope(proposedScope)
                        Task { await voice.start() }
                    }
                } label: {
                    Image(systemName: voice.recording ? "stop.circle.fill" : "mic")
                }
                .disabled(chat.phase.busy || chat.phase == .outcomeUnknown)
                .accessibilityLabel(
                    voice.recording
                        ? "Stop dictation and review transcript" : "Dictate a message on this Mac"
                )
                .accessibilityIdentifier("companion.microphone")
                Button {
                    voice.stopSpeaking()
                } label: {
                    Image(systemName: "speaker.slash")
                }
                .accessibilityLabel("Stop spoken reply")
                Toggle("Read replies", isOn: $voice.readReplies).toggleStyle(.checkbox).font(
                    .system(size: 10)
                )
                .onChange(of: voice.readReplies) { _, enabled in
                    if !enabled { voice.stopSpeaking() }
                }
                Spacer(minLength: 0)
                if chat.phase.busy {
                    Button("Stop") { Task { await chat.interrupt() } }.accessibilityIdentifier(
                        "companion.stop")
                } else {
                    Button("Send") { chat.send(in: proposedScope) }
                        .disabled(!chat.canSend || voice.recording).keyboardShortcut(
                            .return, modifiers: .command
                        )
                        .accessibilityIdentifier("companion.send")
                }
            }.buttonStyle(.plain).foregroundStyle(HUD.cyan)
            Text("⌘ Return to send · Codex uses your account/provider limits.")
                .font(.system(size: 9)).foregroundStyle(HUD.muted)
            if chat.draft.count > 16_000 {
                Text("Shorten the message to 16,000 characters before sending.").font(
                    .system(size: 10)
                ).foregroundStyle(HUD.gold)
            }
        }
    }
}

private struct CompanionApprovalView: View {
    let approval: CompanionApproval
    let respond: (String?, [String: String]) -> Void
    @StateObject private var ui = ApprovalState()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CODEX NEEDS YOUR INPUT").font(HUD.mono(9)).foregroundStyle(HUD.gold)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if approval.isQuestion {
                        ForEach(approval.questions.indices, id: \.self) { index in
                            let question = approval.questions[index]
                            let id = question["id"].text ?? "\(index)"
                            Text(question["question"].text ?? "Question").font(.system(size: 12))
                            ForEach(question["options"].values.indices, id: \.self) { option in
                                let value = question["options"].values[option]
                                Button(value["label"].text ?? "Option") {
                                    ui.answers[id] = value["label"].text
                                }
                                .help(value["description"].text ?? "")
                            }
                            if question["isSecret"] == .bool(true) {
                                SecureField("Your answer", text: answer(id))
                            } else {
                                TextField("Your answer", text: answer(id))
                            }
                        }
                    } else {
                        Text(
                            approval.method.contains("fileChange")
                                ? "File change approval" : "Command / network approval")
                        Text(
                            approval.details.isEmpty
                                ? "Codex supplied no further details." : approval.details
                        )
                        .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 190)
            if approval.isQuestion {
                Button("Send answer") { respond(nil, ui.answers) }.disabled(
                    approval.questions.contains {
                        guard let id = $0["id"].text else { return true }
                        return ui.answers[id]?.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty ?? true
                    })
            } else {
                HStack {
                    ForEach(approval.decisions, id: \.self) { decision in
                        Button(decision == "accept" ? "Allow once" : decision.capitalized) {
                            respond(decision, [:])
                        }
                    }
                }
            }
        }.padding(12).background(HUD.gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier("companion.approval")
    }

    private func answer(_ id: String) -> Binding<String> {
        Binding(get: { ui.answers[id] ?? "" }, set: { ui.answers[id] = $0 })
    }
}

private struct CompanionSettings: View {
    @ObservedObject var voice: LocalVoice
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ui = ConnectionSettingsState()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Jarvis connection").font(.title2)
            Text(
                "Uses the installed Codex App Server and its own sign-in/configuration. No API key is copied into Jarvis."
            )
            Text(ui.executable).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
            Button("Choose Codex executable…") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url, CodexExecutable.isValid(url) {
                    UserDefaults.standard.set(url.path, forKey: "codexExecutable")
                    ui.executable = url.path
                }
            }
            Text(
                "A changed executable applies to new conversations. Sign in through Codex itself if needed."
            ).font(.caption)
            Picker("Dictation language", selection: $voice.language) {
                Text("English (UK)").tag("en-GB")
                Text("English (US)").tag("en-US")
                Text("French").tag("fr-FR")
                Text("Hungarian").tag("hu-HU")
            }.disabled(voice.recording)
            Text(
                "Dictation requires on-device support for the selected language. There is no cloud audio fallback. Only the reviewed text you send goes to Codex. Spoken replies use macOS speech, not ChatGPT Live Voice."
            )
            .font(.caption)
            Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
        }.padding(28).frame(width: 450).fixedSize(horizontal: false, vertical: true)
    }
}
