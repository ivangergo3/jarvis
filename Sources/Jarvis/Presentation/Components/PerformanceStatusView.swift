import SwiftUI

struct PerformanceStatusView: View {
    @ObservedObject var progress: PerformanceProgress
    let manual: Bool
    let start: () -> Void
    var body: some View {
        VStack(spacing: 4) {
            Text(
                progress.stage == "manual-pointer"
                    ? "Recording cursor movement — 60 seconds" : progress.stage
            ).font(HUD.mono(10))
            if progress.cursorFinished, !progress.stage.hasPrefix("Performance recording") {
                Text("Your mouse part is complete — automatic checks are running").font(HUD.mono(9))
            }
            if manual, progress.stage.hasPrefix("Ready") {
                Button("Start 60-second cursor recording") { start() }
                    .accessibilityIdentifier("performance.startManual")
            }
        }.padding(8).foregroundStyle(HUD.gold).background(HUD.background)
    }
}
