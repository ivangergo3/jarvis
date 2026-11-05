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
    let mission: Mission?
    let sourceUnavailable: Bool
    let motion: Bool
    @StateObject private var ui = CompanionPanelState()

    var body: some View {
        VStack(spacing: 12) {
            channelHeader
            VStack(alignment: .leading, spacing: 4) {
                if chat.phase != .ready && chat.phase != .complete {
                    Text(chat.phase.label).font(HUD.mono(9)).foregroundStyle(HUD.gold)
                }
                if chat.scope?.threadID != proposedScope.threadID, proposedScope.threadID != nil {
                    Text(
                        "Draft stays with \(chat.scope?.name ?? "its original chat"). Use the reconnect button to switch to \(proposedScope.name)."
                    )
                    .font(.system(size: 10)).foregroundStyle(HUD.gold)
                }
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
        .task(id: proposedScope) {
            if !voice.recording {
                voice.stopAudio()
                await chat.follow(proposedScope)
            }
        }
        .onChange(of: chat.phase) { _, phase in
            if !phase.busy, !voice.recording, chat.scope?.threadID != proposedScope.threadID {
                Task { await chat.follow(proposedScope) }
            }
        }
        .onChange(of: chat.importingImage) { _, importing in
            if !importing, !voice.recording, chat.scope?.threadID != proposedScope.threadID {
                Task { await chat.follow(proposedScope) }
            }
        }
        .sheet(isPresented: $ui.settings) {
            CompanionSettings(voice: voice, mission: mission, sourceUnavailable: sourceUnavailable)
        }
        .confirmationDialog(
            "Switch or reconnect to \(proposedScope.name)? This discards the unsent draft. Previously queued messages stay with their original chat.",
            isPresented: $ui.confirmNew
        ) {
            Button("Use selected chat") {
                Task { await chat.follow(proposedScope, discardDraft: true) }
            }
        }
        .onChange(of: chat.draft) { _, text in
            if !text.isEmpty { chat.pinScope(proposedScope) }
        }
        .onAppear {
            voice.onTranscript = { text in
                chat.draft = String(
                    (chat.draft + (chat.draft.isEmpty ? "" : "\n") + text).prefix(16_000))
            }
        }
        .onDisappear {
            voice.cancel()
            voice.stopAudio()
            voice.onTranscript = nil
        }
    }

    private var channelHeader: some View {
        let status = sourceUnavailable ? MissionStatus.unknown : mission?.status ?? .unknown
        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(mission?.role ?? "CHANNEL").font(HUD.mono(8)).tracking(2)
                    .foregroundStyle(HUD.gold.opacity(0.85)).lineLimit(1)
                Spacer(minLength: 12)
                HStack(spacing: 6) {
                    Circle().fill(HUD.color(status)).frame(width: 4, height: 4)
                    Text(status.label).font(HUD.mono(8)).tracking(1)
                }.foregroundStyle(HUD.color(status))
            }
            HStack(spacing: 12) {
                Image(systemName: "hexagon").font(.system(size: 35, weight: .ultraLight))
                    .overlay {
                        Image(systemName: mission?.symbol ?? "bubble.left.and.bubble.right")
                            .font(.system(size: 14, weight: .light))
                    }
                    .foregroundStyle(HUD.cyan.opacity(0.8)).accessibilityHidden(true)
                Text((chat.scope ?? proposedScope).name)
                    .font(.system(size: 21, weight: .light, design: .monospaced))
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            }
            Rectangle().fill(HUD.line).frame(height: 1)
            HStack(spacing: 8) {
                Button { openLinkedChat() } label: {
                    Label("Open in Codex", systemImage: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .medium))
                }
                .disabled(chat.scope?.threadID == nil)
                .accessibilityIdentifier("companion.openLinkedChat")
                Spacer(minLength: 8)
                Button { ui.confirmNew = true } label: {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12))
                }
                .disabled(chat.phase.busy || voice.recording)
                .help("Reconnect to selected chat")
                .accessibilityLabel("Switch or reconnect to the selected Codex chat")
                .accessibilityIdentifier("companion.newChat")
                Button { ui.settings = true } label: {
                    Image(systemName: "gearshape").font(.system(size: 12))
                }
                .help("Connection, voice and subagents")
                .accessibilityLabel("Codex connection settings")
                .accessibilityIdentifier("companion.settings")
            }.buttonStyle(HUDControlStyle())
        }
        .padding(14)
        .background(HUD.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
        .overlay(HeaderActivityBorder(active: status == .working, motion: motion)
            .allowsHitTesting(false).accessibilityHidden(true))
    }

    private func openLinkedChat() {
        guard let id = chat.scope?.threadID else { return }
        var destination = URLComponents()
        destination.scheme = "codex"
        destination.host = "threads"
        destination.path = "/" + id
        if let url = destination.url { NSWorkspace.shared.open(url) }
    }

    private var conversation: some View {
        GeometryReader { geometry in
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if chat.messages.isEmpty {
                        Text("This is the same chat.")
                            .font(.system(size: 18, weight: .light)).padding(.top, 12)
                        Text(
                            "Select a chat to read recent saved messages. Typed and dictated messages go to that chat when you choose Send. Approvals are handled in Codex."
                        )
                        .font(.system(size: 12)).foregroundStyle(HUD.muted).lineSpacing(4)
                    }
                    ForEach(chat.messages) { message in
                        messageBubble(message, maxWidth: min(760, geometry.size.width * 0.8))
                            .id(message.id)
                    }
                    Color.clear.frame(height: 1).id("chat-bottom")
                }
            }
            .defaultScrollAnchor(.bottom)
            .onAppear { proxy.scrollTo("chat-bottom", anchor: .bottom) }
            .onChange(of: chat.messages.last?.text) { _, _ in
                proxy.scrollTo("chat-bottom", anchor: .bottom)
            }
        }.accessibilityIdentifier("companion.conversation")
        }
    }

    private func messageBubble(_ message: CompanionMessage, maxWidth: CGFloat) -> some View {
        let outgoing = message.role == .user
        let accent = outgoing ? HUD.gold : HUD.cyan

        return VStack(alignment: .leading, spacing: 7) {
            Label(
                outgoing ? (message.queued ? "YOU · QUEUED" : "YOU") : "CODEX",
                systemImage: outgoing ? "arrow.up.right" : "arrow.down.left"
            )
            .font(HUD.mono(9)).foregroundStyle(accent)
            if !message.attachments.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 150))], alignment: .leading) {
                    ForEach(message.attachments) { file in AttachmentTile(file: file) }
                }
            }
            if !message.text.isEmpty { ChatMarkdownView(text: message.text).equatable() }
        }
        .padding(12)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .background(accent.opacity(outgoing ? 0.13 : 0.07), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10).strokeBorder(accent.opacity(0.4), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: outgoing ? .trailing : .leading)
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
            if !chat.draftImages.isEmpty {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(chat.draftImages) { image in
                            VStack(spacing: 4) {
                                AttachmentTile(file: image).frame(width: 110)
                                Button { chat.removeDraftImage(image.id) } label: {
                                    Label("Remove", systemImage: "xmark.circle")
                                }
                                .font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(HUD.muted)
                                .disabled(chat.phase.busy || chat.phase == .outcomeUnknown)
                                .accessibilityLabel("Remove pasted image")
                            }
                        }
                    }
                }
            }
            if chat.importingImage {
                Text("Preparing image…").font(HUD.mono(10)).foregroundStyle(HUD.cyan)
            }
            ComposerEditor(text: $chat.draft,
                editable: !chat.phase.busy && !voice.recording && chat.phase != .outcomeUnknown && chat.scope?.threadID != nil,
                pasteImage: { chat.pasteImage($0) })
                .frame(height: 76).padding(7)
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(HUD.cyan.opacity(0.5), lineWidth: 1))
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
                .disabled(
                    chat.phase.busy || chat.phase == .outcomeUnknown || chat.scope?.threadID == nil
                )
                .accessibilityLabel(
                    voice.recording
                        ? "Stop dictation and review transcript" : "Dictate a message on this Mac"
                )
                .accessibilityIdentifier("companion.microphone")
                Toggle(isOn: $voice.completionChime) {
                    Label("Completion chime", systemImage: voice.completionChime ? "bell.fill" : "bell.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(voice.completionChime ? HUD.cyan : HUD.muted)
                }
                .toggleStyle(.button)
                .help(voice.completionChime ? "Mute completion chime" : "Enable completion chime")
                .accessibilityIdentifier("companion.completionChime")
                .onChange(of: voice.completionChime) { _, enabled in
                    if !enabled { voice.stopAudio() }
                }
                Toggle(isOn: $voice.readReplies) {
                    Label("Read reply", systemImage: voice.readReplies ? "speaker.wave.2.fill" : "speaker.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(voice.readReplies ? HUD.cyan : HUD.muted)
                }
                .toggleStyle(.button)
                .help(voice.readReplies ? "Disable read-aloud" : "Read completed replies aloud")
                .accessibilityIdentifier("companion.readReplies")
                Spacer(minLength: 0)
                if chat.phase.busy && chat.scope?.threadID == nil {
                    Button("Stop") { Task { await chat.interrupt() } }.accessibilityIdentifier(
                        "companion.stop")
                } else {
                    Button("Send") { chat.send(in: proposedScope) }
                        .disabled(!chat.canSend || voice.recording || chat.scope?.threadID == nil
                            || chat.scope?.threadID != proposedScope.threadID)
                        .keyboardShortcut(
                            .return, modifiers: .command
                        )
                        .accessibilityIdentifier("companion.send")
                }
            }.buttonStyle(.plain).foregroundStyle(HUD.cyan)
            Text("⌘ V to paste text or an image · ⌘ Return to send")
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
    let mission: Mission?
    let sourceUnavailable: Bool
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ui = ConnectionSettingsState()

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape").font(.system(size: 24, weight: .light))
                    .foregroundStyle(HUD.cyan)
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "JARVIS / PREFERENCES", color: HUD.gold)
                    Text("Connection & voice").font(.system(size: 23, weight: .light))
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(HUDControlStyle()).keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close settings")
            }
            Rectangle().fill(HUD.line).frame(height: 1)
            VStack(alignment: .leading, spacing: 13) {
                Label("CODEX CONNECTION", systemImage: "link")
                    .font(HUD.mono(10)).foregroundStyle(HUD.cyan)
                Text("Uses your installed Codex and its existing sign-in. No API key is copied into Jarvis.")
                    .font(.system(size: 12)).lineSpacing(4)
                Text(ui.executable).font(HUD.mono(11)).foregroundStyle(HUD.muted)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Button("Choose Codex executable…") { chooseExecutable() }
                    .font(.system(size: 11)).buttonStyle(HUDControlStyle())
                Text("A different executable applies when you reconnect. Sign in through Codex itself.")
                    .font(.system(size: 11)).foregroundStyle(HUD.muted)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).modifier(HUDPanel())
            VStack(alignment: .leading, spacing: 13) {
                Label("VOICE", systemImage: "waveform")
                    .font(HUD.mono(10)).foregroundStyle(HUD.cyan)
                Picker("Dictation language", selection: $voice.language) {
                    Text("English (UK)").tag("en-GB")
                    Text("English (US)").tag("en-US")
                    Text("French").tag("fr-FR")
                    Text("Hungarian").tag("hu-HU")
                }.disabled(voice.recording).tint(HUD.cyan)
                Text("Dictation runs on this Mac when the language is supported. Review the text before sending; there is no cloud audio fallback.")
                    .font(.system(size: 12)).lineSpacing(4)
                Text("Completion chime and read-aloud can be enabled separately. With both on, the chime plays first. Read-aloud uses macOS speech.")
                    .font(.system(size: 11)).foregroundStyle(HUD.muted)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).modifier(HUDPanel())
            if let mission {
                VStack(alignment: .leading, spacing: 13) {
                    Label("SUBAGENTS / \(mission.name)", systemImage: "person.3")
                        .font(HUD.mono(10)).foregroundStyle(HUD.cyan)
                    if mission.agents.isEmpty {
                        Text("No delegated agents recorded.").font(.system(size: 12))
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(mission.agents) { agent in
                                    HStack {
                                        Text(agent.name).font(HUD.mono(11))
                                        Spacer()
                                        StatusBadge(status: sourceUnavailable ? .unknown : agent.status)
                                    }
                                }
                            }
                        }.frame(height: min(140, CGFloat(mission.agents.count) * 32))
                    }
                    Divider().overlay(HUD.line)
                    HStack {
                        Text("Last activity").font(.system(size: 11)).foregroundStyle(HUD.muted)
                        Spacer()
                        Text(mission.updated, format: .dateTime.day().month(.abbreviated).hour().minute())
                            .font(HUD.mono(10))
                    }
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading).modifier(HUDPanel())
            }
            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                Text("LOCAL CONNECTION / YOUR MAC")
            }.font(HUD.mono(9)).foregroundStyle(HUD.muted)
        }
        .padding(28)
        }
        .frame(width: 530, height: min(780, max(400,
            (NSApp.keyWindow?.screen?.visibleFrame.height ?? 900) - 100)))
        .foregroundStyle(HUD.text).background(HUD.background)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUD.cyan.opacity(0.25), lineWidth: 1))
        .preferredColorScheme(.dark)
    }

    private func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, CodexExecutable.isValid(url) {
            UserDefaults.standard.set(url.path, forKey: "codexExecutable")
            ui.executable = url.path
        }
    }
}
