import SwiftUI
import AppKit

@MainActor final class DashboardState: ObservableObject {
    @Published var selection: String?
    @Published var projectID: String? {
        didSet { UserDefaults.standard.set(projectID ?? "__all__", forKey: "selectedProject") }
    }
    @Published var tab = "Overview"
    @Published var motion = true
    @Published var board = false
    @Published var copied = false
    @Published var hoveredNodeID: String?
    @Published var showCompanion = true
    init() {
        let stored = UserDefaults.standard.string(forKey: "selectedProject")
        projectID = stored == "__all__" ? nil : stored
    }
}

struct Dashboard: View {
    @ObservedObject var companion: CompanionModel
    @ObservedObject var voice: LocalVoice
    @StateObject private var store = FleetStore()
    @StateObject private var ui = DashboardState()
    private var selection: String? { get { ui.selection } nonmutating set { ui.selection = newValue } }
    private var tab: String { get { ui.tab } nonmutating set { ui.tab = newValue } }
    private var motion: Bool { get { ui.motion } nonmutating set { ui.motion = newValue } }
    private var board: Bool { get { ui.board } nonmutating set { ui.board = newValue } }
    private var copied: Bool { get { ui.copied } nonmutating set { ui.copied = newValue } }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var projects: [WorkspaceProject] { store.snapshot?.projects ?? [] }
    private var rootProjects: [WorkspaceProject] { projects.filter { !$0.isUnassigned } }
    private var project: WorkspaceProject? { projects.first { $0.id == ui.projectID } }
    private var isGlobal: Bool { project == nil }
    private var scopeName: String { project?.name ?? "All projects" }
    private var allMissions: [Mission] { store.snapshot?.missions ?? [] }
    private var missions: [Mission] { project.map { p in allMissions.filter { $0.projectID == p.id } } ?? allMissions }
    private var graphMissions: [Mission] {
        missions.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }
    private var selected: Mission? { missions.first { $0.id == selection } ?? missions.first }
    private var activeCount: Int { missions.filter { $0.status == .working }.count }
    private var agentCount: Int { missions.flatMap(\.agents).filter { $0.status == .working }.count }
    private var nodeCount: Int { isGlobal ? rootProjects.count : missions.count }
    private var graphActive: [Bool] {
        guard store.error == nil else { return Array(repeating: false, count: nodeCount) }
        return isGlobal ? rootProjects.map { p in allMissions.contains { $0.projectID == p.id && $0.status == .working } } : graphMissions.map { $0.status == .working }
    }
    private var graphFocused: [Bool] {
        isGlobal ? rootProjects.map { $0.id == ui.hoveredNodeID } : graphMissions.map { $0.id == ui.hoveredNodeID || $0.id == selected?.id }
    }

    private func chooseProject(_ id: String?) {
        ui.projectID = id; selection = nil; copied = false; ui.hoveredNodeID = nil; tab = "Overview"
    }
    private func chooseMission(_ mission: Mission) {
        if isGlobal { ui.projectID = mission.projectID }
        selection = mission.id; copied = false
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 215)
            Rectangle().fill(HUD.line).frame(width: 1)
            VStack(spacing: 0) {
                header
                Rectangle().fill(HUD.line).frame(height: 1)
                HStack(spacing: 0) {
                    mainContent.frame(maxWidth: .infinity, maxHeight: .infinity)
                    Rectangle().fill(HUD.line).frame(width: 1)
                    VStack(spacing: 0) {
                        Picker("Right panel", selection: $ui.showCompanion) {
                            Text("Jarvis chat").tag(true)
                            Text("Task details").tag(false)
                        }.pickerStyle(.segmented).padding(12).accessibilityIdentifier("dashboard.rightPanel")
                        if ui.showCompanion {
                            CompanionPanel(chat: companion, voice: voice,
                                proposedScope: ConversationScope(projectID: project?.id,
                                    name: project?.name ?? "Jarvis", directory: project?.roots.first), motion: motion)
                        } else { detail }
                    }.frame(width: 380)
                }
                footer
            }
        }
        .background(HUD.background).foregroundStyle(HUD.text).preferredColorScheme(.dark)
        .frame(minWidth: 1180, minHeight: 760)
        .task {
            await store.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if Task.isCancelled { break }
                await store.refresh()
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "diamond.inset.filled").font(.system(size: 25, weight: .ultraLight)).foregroundStyle(HUD.gold)
                VStack(alignment: .leading, spacing: 3) {
                    Text("JARVIS").font(.system(size: 21, weight: .light, design: .monospaced)).tracking(5)
                    Text("PERSONAL COMMAND").font(HUD.mono(7)).tracking(1.2).foregroundStyle(HUD.gold.opacity(0.7)).fixedSize()
                }
            }.padding(.bottom, 28)
            projectSelector.padding(.bottom, 28)
            Eyebrow(text: "WORKSPACE").padding(.bottom, 16)
            ForEach([("Overview", "square.grid.2x2"), ("Activity", "waveform.path")], id: \.0) { name, icon in
                Button { tab = name } label: {
                    HStack(spacing: 12) {
                        Image(systemName: icon).frame(width: 18)
                        Text(name).font(.system(size: 13, weight: .medium))
                        Spacer()
                        if tab == name { RoundedRectangle(cornerRadius: 1).fill(HUD.cyan).frame(width: 3, height: 16) }
                    }.foregroundStyle(tab == name ? HUD.cyan : HUD.muted)
                        .padding(.horizontal, 12).padding(.vertical, 13)
                        .background(tab == name ? HUD.cyan.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 7))
                }.buttonStyle(.plain).padding(.horizontal, -10)
            }
            Rectangle().fill(HUD.line).frame(height: 1).padding(.vertical, 28)
            HStack { Eyebrow(text: isGlobal ? "PROJECTS" : "PROJECT TEAM"); Spacer(); Text(String(format: "%02d", nodeCount)).font(HUD.mono(10)).foregroundStyle(HUD.muted) }.padding(.bottom, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isGlobal {
                        ForEach(projects) { p in
                            Button { chooseProject(p.id) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: p.isUnassigned ? "tray" : "folder").foregroundStyle(HUD.gold).frame(width: 12)
                                    Text(p.name).font(.system(size: 12)).lineLimit(2).multilineTextAlignment(.leading)
                                    Spacer()
                                    Text("\(allMissions.filter { $0.projectID == p.id }.count)").font(HUD.mono(9))
                                }.foregroundStyle(HUD.muted).padding(.vertical, 10)
                            }.buttonStyle(.plain)
                        }
                    } else {
                        ForEach(missions) { mission in
                            Button { chooseMission(mission); tab = "Overview" } label: {
                                HStack(spacing: 10) {
                                    Circle().fill(HUD.color(mission.status)).frame(width: 5, height: 5)
                                    Text(mission.name).font(.system(size: 12)).foregroundStyle(selected?.id == mission.id ? HUD.text : HUD.muted).lineLimit(2).multilineTextAlignment(.leading)
                                    Spacer()
                                }.padding(.vertical, 10)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) { Image(systemName: "lock.shield"); Text("LOCAL CONNECTION") }.font(HUD.mono(9)).tracking(0.5).foregroundStyle(HUD.cyan.opacity(0.8))
                Text("Your Mac. Your workspace.").font(.system(size: 11)).foregroundStyle(HUD.muted)
                Text("TEAM VIEW ONLY   /   v0.3").font(HUD.mono(8)).tracking(1.2).foregroundStyle(HUD.muted.opacity(0.7))
            }
        }.padding(.horizontal, 27).padding(.top, 32).padding(.bottom, 27).background(Color.black.opacity(0.15))
    }

    private var projectSelector: some View {
        Menu {
            Button("All projects · Jarvis overview") { chooseProject(nil) }
            Divider()
            ForEach(projects) { p in
                Button { chooseProject(p.id) } label: {
                    if project?.id == p.id { Label(p.name, systemImage: "checkmark") }
                    else { Text(p.name) }
                }
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isGlobal ? "square.stack.3d.up" : "folder").foregroundStyle(HUD.gold)
                Text(scopeName).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").font(.system(size: 9))
            }.foregroundStyle(HUD.text).padding(11).background(HUD.gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(HUD.gold.opacity(0.20), lineWidth: 0.7))
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Project selector: \(scopeName)").help("Choose a Codex project or the Jarvis overview")
    }

    private var header: some View {
        HStack(spacing: 18) {
            HStack(spacing: 9) { Rectangle().fill(HUD.gold).frame(width: 3, height: 16); Eyebrow(text: "MISSION CONTROL", color: HUD.text) }
            Text("/  \(scopeName)").font(HUD.mono(10)).lineLimit(1).foregroundStyle(HUD.muted)
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date, format: .dateTime.hour().minute().second()).font(HUD.mono(11)).monospacedDigit().foregroundStyle(HUD.muted)
            }
            Rectangle().fill(HUD.line).frame(width: 1, height: 18)
            Button { motion.toggle() } label: { Image(systemName: motion ? "pause" : "play").frame(width: 20) }.buttonStyle(.plain).help(motion ? "Pause ambient animation" : "Resume ambient animation").accessibilityLabel("Toggle ambient animation")
            Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise").frame(width: 20) }.buttonStyle(.plain).keyboardShortcut("r", modifiers: .command).help("Refresh local activity")
            Button { (NSApp.keyWindow ?? NSApp.windows.first { $0.title == "Jarvis — Mission Control" })?.toggleFullScreen(nil) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 20) }.buttonStyle(.plain).keyboardShortcut("f", modifiers: [.command, .shift]).help("Toggle full screen")
        }.foregroundStyle(HUD.muted).padding(.horizontal, 30).frame(height: 76)
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 9) {
                    Eyebrow(text: "GOOD TO SEE YOU, GREG", color: HUD.gold)
                    Text(tab == "Overview" ? (isGlobal ? "Every project. One view." : "Your team. One view.") : "The latest signals.").font(.system(size: 31, weight: .light)).tracking(-0.7)
                    Text(isGlobal ? "Jarvis at the centre. Your projects, connected." : "\(scopeName) · all chats in this project").font(.system(size: 12)).foregroundStyle(HUD.muted)
                }
                Spacer()
                if tab == "Overview" {
                    HStack(spacing: 2) {
                        modeButton("point.3.connected.trianglepath.dotted", selected: !board) { board = false }
                        modeButton("rectangle.grid.1x2", selected: board) { board = true }
                    }.padding(4).background(HUD.panel, in: RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(HUD.line, lineWidth: 0.6))
                }
            }.padding(.top, 29).padding(.horizontal, 30).padding(.bottom, 24)
            HStack(spacing: 0) {
                stat(String(format: "%02d", isGlobal ? rootProjects.count : missions.count), isGlobal ? "PROJECTS" : "CONNECTED CHATS", HUD.text)
                stat(store.error == nil ? String(format: "%02d", activeCount) : "—", "IN PROGRESS", HUD.cyan)
                stat(store.error == nil ? String(format: "%02d", agentCount) : "—", "ACTIVE SUBAGENTS", HUD.gold)
            }.padding(.horizontal, 30).padding(.bottom, 16)
            if let error = store.error {
                Label("Connection unavailable · \(error)", systemImage: "exclamationmark.triangle").font(.system(size: 11)).foregroundStyle(HUD.gold).padding(12).background(HUD.gold.opacity(0.06)).padding(.horizontal, 30)
            } else if let notices = store.snapshot?.notices, !notices.isEmpty {
                Label(notices.joined(separator: " "), systemImage: "exclamationmark.triangle").font(.system(size: 11)).foregroundStyle(HUD.gold).padding(.horizontal, 30).padding(.bottom, 12)
            }
            if store.snapshot == nil || (!isGlobal && missions.isEmpty) {
                Spacer(); VStack(spacing: 15) { Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 28, weight: .ultraLight)); Text(store.snapshot == nil ? "Connecting to your workspace…" : "No active chats in this project yet.").font(.system(size: 15)) }.foregroundStyle(HUD.muted).frame(maxWidth: .infinity); Spacer()
            } else if tab == "Activity" { activityView }
            else if board { boardView }
            else { networkView }
        }
    }

    private func modeButton(_ icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 12)).foregroundStyle(selected ? HUD.cyan : HUD.muted).frame(width: 30, height: 26).background(selected ? HUD.cyan.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 4)) }.buttonStyle(.plain).help(icon.contains("triangle") ? "Team map" : "Card view")
    }
    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) { Text(value).font(.system(size: 27, weight: .light, design: .monospaced)).foregroundStyle(color); Eyebrow(text: label).tracking(0).lineLimit(2) }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var networkView: some View {
        GeometryReader { geometry in
            let layout = TeamGraphLayout(count: nodeCount, viewport: geometry.size)
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    GridBackdrop().mask(LinearGradient(colors: [.clear, .white, .white, .clear], startPoint: .top, endPoint: .bottom))
                    TopologyLines(active: graphActive, highlighted: graphFocused, motion: motion && !reduceMotion, connections: layout.connections)
                    if isGlobal {
                        ForEach(Array(rootProjects.enumerated()), id: \.element.id) { index, p in
                            projectCard(p).frame(width: layout.cardWidth)
                                .modifier(destination(index: index, layout: layout))
                                .onHover { hoverNode(p.id, inside: $0) }
                                .position(layout.nodes[index])
                        }
                    } else {
                        ForEach(Array(graphMissions.enumerated()), id: \.element.id) { index, mission in
                            missionCard(mission).frame(width: layout.cardWidth)
                                .modifier(destination(index: index, layout: layout))
                                .onHover { hoverNode(mission.id, inside: $0) }
                                .position(layout.nodes[index])
                        }
                    }
                    VStack(spacing: 0) {
                        Reactor(motion: motion).frame(width: min(270, layout.size.height * 0.55), height: min(270, layout.size.height * 0.55))
                        Text("J.A.R.V.I.S.").font(HUD.mono(13, weight: .light)).tracking(5).foregroundStyle(HUD.cyan).padding(.top, -17)
                        Eyebrow(text: isGlobal ? "GLOBAL OVERVIEW" : "PROJECT OVERVIEW").scaleEffect(0.8).padding(.top, 8)
                    }.position(layout.center)
                }.frame(width: layout.size.width, height: layout.size.height)
            }.id(project?.id ?? "__all__")
                .overlay(alignment: .topTrailing) {
                    if nodeCount > 4 {
                        Label("\(nodeCount) \(isGlobal ? "projects" : "chats") · scroll to explore", systemImage: "arrow.up.and.down")
                            .font(HUD.mono(9)).foregroundStyle(HUD.muted).padding(10)
                            .background(HUD.background.opacity(0.9), in: RoundedRectangle(cornerRadius: 6)).padding(8)
                    }
                }
        }.padding(.horizontal, 12).padding(.bottom, 10)
    }

    private func destination(index: Int, layout: TeamGraphLayout) -> GraphDestination {
        GraphDestination(active: graphActive[index], highlighted: graphFocused[index], motion: motion && !reduceMotion,
                         index: index, left: layout.nodes[index].x < layout.center.x)
    }
    private func hoverNode(_ id: String, inside: Bool) {
        if inside { ui.hoveredNodeID = id }
        else if ui.hoveredNodeID == id { ui.hoveredNodeID = nil }
    }

    private var boardView: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 22) {
                    Reactor(motion: motion).frame(width: 125, height: 125)
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: isGlobal ? "JARVIS · GLOBAL OVERVIEW" : "JARVIS · PROJECT OVERVIEW", color: HUD.cyan)
                        Text(scopeName).font(.system(size: 22, weight: .light))
                        Text(isGlobal ? "Select a project to see its team." : "Every chat in this project, with no hidden cards.").font(.system(size: 12)).foregroundStyle(HUD.muted)
                    }
                    Spacer()
                    if !isGlobal { Button("All projects") { chooseProject(nil) }.buttonStyle(.plain).foregroundStyle(HUD.gold).font(HUD.mono(10)) }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                    if isGlobal { ForEach(rootProjects) { p in projectCard(p) } }
                    else { ForEach(missions) { mission in missionCard(mission) } }
                }
            }.padding(.horizontal, 30).padding(.bottom, 24)
        }
    }

    private func projectCard(_ p: WorkspaceProject) -> some View {
        let team = allMissions.filter { $0.projectID == p.id }
        let active = team.filter { $0.status == .working }.count
        return Button { chooseProject(p.id) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "folder").font(.system(size: 17, weight: .light)).foregroundStyle(HUD.gold)
                    Spacer()
                    StatusBadge(status: store.error != nil ? .unknown : active > 0 ? .working : team.contains { $0.status == .unknown } ? .unknown : .standby)
                }
                Text(p.name).font(.system(size: 18, weight: .medium)).foregroundStyle(HUD.text).lineLimit(1)
                Text("\(team.count) chats · \(active) in progress").font(.system(size: 12)).foregroundStyle(HUD.muted)
                HStack { Eyebrow(text: "VIEW PROJECT TEAM").scaleEffect(0.72, anchor: .leading); Spacer(minLength: 0); Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(HUD.cyan) }
            }.padding(18).modifier(HUDPanel())
        }.buttonStyle(.plain).accessibilityLabel("Open project \(p.name), \(team.count) chats, \(active) in progress")
    }

    private func missionCard(_ mission: Mission) -> some View {
        Button { chooseMission(mission) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: mission.symbol).font(.system(size: 16, weight: .light)).foregroundStyle(HUD.cyan)
                    Spacer(); StatusBadge(status: store.error == nil ? mission.status : .unknown)
                }
                Text(mission.name).font(.system(size: 17, weight: .medium)).foregroundStyle(HUD.text).lineLimit(2)
                Text(taskPreview(mission.task)).font(.system(size: 11)).foregroundStyle(HUD.muted).lineLimit(2).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Eyebrow(text: mission.role).scaleEffect(0.72, anchor: .leading).frame(height: 10)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(HUD.muted)
                }
            }.padding(16).modifier(HUDPanel(selected: selected?.id == mission.id))
        }.buttonStyle(.plain).accessibilityLabel("\(mission.name), \(mission.status.label), \(String(taskPreview(mission.task).prefix(140)))")
    }

    private func taskPreview(_ task: String) -> String {
        let lines = task.components(separatedBy: .newlines).filter {
            let line = $0.trimmingCharacters(in: .whitespaces)
            return !line.isEmpty && !line.hasPrefix("[https://") && !line.hasPrefix("https://")
        }
        return lines.isEmpty ? task : lines.joined(separator: " ")
    }

    private var activityView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "LAST OBSERVED ACTIVITY · BY CHAT")
                ForEach(missions.sorted { $0.updated > $1.updated }) { mission in
                    Button { chooseMission(mission) } label: {
                        HStack(alignment: .top, spacing: 18) {
                            Image(systemName: mission.symbol).foregroundStyle(HUD.cyan).frame(width: 22)
                            VStack(alignment: .leading, spacing: 9) {
                                HStack { Text(mission.name).font(.system(size: 14, weight: .medium)); Spacer(); StatusBadge(status: mission.status) }
                                Text(mission.task).font(.system(size: 12)).foregroundStyle(HUD.muted).lineLimit(3).multilineTextAlignment(.leading)
                                Text(mission.updated, style: .relative).font(HUD.mono(9)).foregroundStyle(HUD.muted)
                            }
                        }.padding(18).modifier(HUDPanel(selected: selected?.id == mission.id))
                    }.buttonStyle(.plain)
                }
            }.padding(30)
        }
    }

    private var globalBrief: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "square.stack.3d.up").font(.system(size: 28, weight: .ultraLight)).foregroundStyle(HUD.cyan)
                Spacer()
                Eyebrow(text: "OVERVIEW", color: HUD.gold)
            }
            Text("Jarvis").font(.system(size: 30, weight: .light))
            Eyebrow(text: "ABOVE EVERY PROJECT", color: HUD.gold)
            Rectangle().fill(HUD.line).frame(height: 1).padding(.vertical, 8)
            Text("One place to see the whole picture.").font(.system(size: 18, weight: .light)).lineSpacing(4)
            Text("Choose a project to see its team, tasks and activity. The counters here cover all your local chats.").font(.system(size: 12)).lineSpacing(5).foregroundStyle(HUD.muted)
            VStack(alignment: .leading, spacing: 15) {
                Eyebrow(text: "THE BIG PICTURE")
                Label("You · direction", systemImage: "person.crop.circle").foregroundStyle(HUD.text)
                Label("Jarvis · workspace overview", systemImage: "circle.hexagongrid").foregroundStyle(HUD.cyan).padding(.leading, 12)
                Label("Projects · focused teams", systemImage: "folder").foregroundStyle(HUD.gold).padding(.leading, 24)
                Label("Chats & recorded subagents", systemImage: "bubble.left.and.bubble.right").foregroundStyle(HUD.muted).padding(.leading, 36)
            }.font(.system(size: 11)).padding(.vertical, 12)
            Text("Jarvis is observing for now. A coordinating agent that delegates work can come next.").font(.system(size: 11)).lineSpacing(4).foregroundStyle(HUD.muted)
            Spacer(minLength: 16)
            if let loose = projects.first(where: \.isUnassigned) {
                Button { chooseProject(loose.id) } label: {
                    Label("\(allMissions.filter { $0.projectID == loose.id }.count) unassigned chats", systemImage: "tray").font(.system(size: 11)).foregroundStyle(HUD.gold)
                }.buttonStyle(.plain)
            }
            Eyebrow(text: "\(rootProjects.count) PROJECTS · \(allMissions.count) CHATS")
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Eyebrow(text: "MISSION BRIEF"); Spacer(); Image(systemName: "viewfinder").foregroundStyle(HUD.cyan.opacity(0.6)) }.padding(.bottom, 30)
            if isGlobal {
                globalBrief
            } else if let mission = selected {
                HStack { Image(systemName: mission.symbol).font(.system(size: 25, weight: .ultraLight)).foregroundStyle(HUD.cyan); Spacer(); StatusBadge(status: store.error == nil ? mission.status : .unknown) }.padding(.bottom, 20)
                Text(mission.name).font(.system(size: 25, weight: .light)).padding(.bottom, 8)
                Eyebrow(text: mission.role, color: HUD.gold).scaleEffect(0.85, anchor: .leading).padding(.bottom, 26)
                Rectangle().fill(HUD.line).frame(height: 1).padding(.bottom, 23)
                Eyebrow(text: mission.sourceLabel == "SESSION LOG" ? "LATEST REQUEST" : "LATEST SAVED REQUEST").padding(.bottom, 12)
                if mission.sourceLabel != "SESSION LOG" {
                    Text("Saved history · live session unavailable").font(.system(size: 10)).foregroundStyle(HUD.gold).padding(.bottom, 12)
                }
                ScrollView {
                    Text(mission.task).font(.system(size: 13)).lineSpacing(6).foregroundStyle(HUD.text.opacity(0.86)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }.frame(maxHeight: .infinity)
                Button {
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(mission.task, forType: .string); copied = true
                } label: { Label(copied ? "Copied" : "Copy request", systemImage: copied ? "checkmark" : "doc.on.doc").font(.system(size: 11)).foregroundStyle(HUD.cyan).padding(.vertical, 10).frame(maxWidth: .infinity).background(HUD.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 6)) }.buttonStyle(.plain).padding(.vertical, 16)
                Rectangle().fill(HUD.line).frame(height: 1).padding(.bottom, 18)
                HStack { Eyebrow(text: "SUBAGENTS"); Spacer(); Text("\(mission.agents.count)").font(HUD.mono(11)).foregroundStyle(HUD.gold) }.padding(.bottom, 10)
                if mission.agents.isEmpty {
                    Text("No delegated agents recorded.").font(.system(size: 11)).foregroundStyle(HUD.muted)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 9) {
                            ForEach(mission.agents) { agent in
                                HStack { Circle().fill(HUD.color(agent.status)).frame(width: 4, height: 4); Text(agent.name).font(HUD.mono(10)); Spacer(); Text(agent.status.label).font(HUD.mono(7)).foregroundStyle(HUD.color(agent.status)) }
                            }
                        }
                    }.frame(maxHeight: 85)
                }
                Spacer(minLength: 20)
                Text("Last activity").font(.system(size: 10)).foregroundStyle(HUD.muted)
                Text(mission.updated, format: .dateTime.day().month(.abbreviated).hour().minute()).font(HUD.mono(10)).foregroundStyle(HUD.text).padding(.top, 6)
            } else { Text("Choose a chat to see its task.").font(.system(size: 13)).foregroundStyle(HUD.muted); Spacer() }
        }.padding(26).background(HUD.panel.opacity(0.28))
    }

    private var footer: some View {
        HStack(spacing: 9) {
            Circle().fill(store.error == nil && store.snapshot != nil ? HUD.cyan : HUD.gold).frame(width: 4, height: 4)
            Text(store.error != nil ? "CONNECTION LOST · SHOWING LAST SNAPSHOT" : store.snapshot == nil ? "CONNECTING" : "LOCAL RECORDS CONNECTED").font(HUD.mono(8)).tracking(1).foregroundStyle(HUD.muted)
            Spacer()
            if let snapshot = store.snapshot {
                Text("SYNC \(snapshot.readAt.formatted(date: .omitted, time: .standard))   /   3s").font(HUD.mono(8)).foregroundStyle(HUD.muted)
            }
            Text("TEAM VIEW ONLY · JARVIS CHAT ENABLED").font(HUD.mono(8)).tracking(1).foregroundStyle(HUD.gold.opacity(0.7))
        }.padding(.horizontal, 30).frame(height: 34).overlay(alignment: .top) { Rectangle().fill(HUD.line).frame(height: 1) }
    }
}
