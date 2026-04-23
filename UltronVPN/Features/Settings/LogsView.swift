import SwiftUI

struct LogsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Theme.self) private var theme
    @State private var text = "Loading…"

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(theme.monoCaption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(theme.bg)
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { Task { await Log.ring.clear(); text = "" } }
                }
            }
            .task { text = await Log.ring.snapshot() }
        }
    }
}
