import SwiftUI

struct DashboardPopupHeader: View {
    let title: String
    let symbol: String
    let close: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(HUD.cyan)
            Eyebrow(text: title, color: HUD.text)
            Spacer()
            Button(action: close) { Image(systemName: "xmark").font(.system(size: 11)) }
                .buttonStyle(HUDControlStyle()).accessibilityLabel("Close \(title.lowercased())")
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(HUD.line).frame(height: 1) }
    }
}

struct GlobalSettingsPanel: View {
    @Binding var interval: RefreshInterval
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape").font(.system(size: 24, weight: .light))
                    .foregroundStyle(HUD.cyan)
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "JARVIS / PREFERENCES", color: HUD.gold)
                    Text("Global settings").font(.system(size: 23, weight: .light))
                }
                Spacer()
                Button(action: close) { Image(systemName: "xmark") }
                    .buttonStyle(HUDControlStyle()).keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close global settings")
            }
            Rectangle().fill(HUD.line).frame(height: 1)
            VStack(alignment: .leading, spacing: 14) {
                Label("WORKSPACE UPDATES", systemImage: "arrow.clockwise")
                    .font(HUD.mono(10)).foregroundStyle(HUD.cyan)
                HStack {
                    Text("Update every").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(interval.label).font(HUD.mono(11)).foregroundStyle(HUD.cyan)
                }
                HStack(spacing: 8) {
                    ForEach(RefreshInterval.allCases) { choice in
                        Button { interval = choice } label: {
                            Text("\(choice.rawValue)s").font(HUD.mono(11))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(HUDControlStyle(selected: interval == choice))
                        .accessibilityLabel("Update every \(choice.label)")
                        .accessibilityValue(interval == choice ? "Selected" : "")
                        .accessibilityAddTraits(interval == choice ? .isSelected : [])
                        .accessibilityIdentifier("settings.refresh.\(choice.rawValue)")
                    }
                }
                Text("Activity and chat updates across Jarvis. Updates slow down while hidden or inactive.")
                    .font(.system(size: 12)).foregroundStyle(HUD.muted)
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading).modifier(HUDPanel())
            Spacer(minLength: 0)
            Label("LOCAL PREFERENCES / ALL PROJECTS", systemImage: "lock.shield")
                .font(HUD.mono(9)).foregroundStyle(HUD.muted)
        }
        .padding(28).frame(width: 530, height: 440)
        .foregroundStyle(HUD.text).background(HUD.background)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUD.cyan.opacity(0.25), lineWidth: 1))
        .preferredColorScheme(.dark)
    }
}

struct ProjectChooser: View {
    let projects: [WorkspaceProject]
    let selectedID: String?
    let choose: (String?) -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardPopupHeader(title: "SELECT PROJECT", symbol: "folder", close: close)
            option("All projects", subtitle: "Jarvis overview", symbol: "square.stack.3d.up", id: nil)
            Rectangle().fill(HUD.line).frame(height: 1)
            if projects.isEmpty {
                Text("No projects available yet.").font(.system(size: 12)).foregroundStyle(HUD.muted)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(projects) { project in
                            option(project.name, subtitle: project.isUnassigned ? "Unassigned chats" : "Project team",
                                symbol: project.isUnassigned ? "tray" : "folder", id: project.id)
                        }
                    }
                }
                .frame(height: min(320, CGFloat(projects.count) * 62))
            }
        }
        .padding(16).frame(width: 300).foregroundStyle(HUD.text)
        .background(HUD.background).preferredColorScheme(.dark)
    }

    private func option(_ name: String, subtitle: String, symbol: String, id: String?) -> some View {
        Button { choose(id) } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(HUD.gold).frame(width: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.system(size: 13, weight: .medium)).lineLimit(2)
                    Text(subtitle).font(HUD.mono(9)).foregroundStyle(HUD.muted)
                }
                Spacer()
                if selectedID == id {
                    Image(systemName: "checkmark").foregroundStyle(HUD.cyan).font(.system(size: 11))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(HUDControlStyle(selected: selectedID == id))
        .accessibilityLabel("Select \(name)")
        .accessibilityValue(selectedID == id ? "Current project" : "")
        .accessibilityAddTraits(selectedID == id ? .isSelected : [])
        .accessibilityIdentifier("projectChoice.\(id ?? "__all__")")
    }
}
