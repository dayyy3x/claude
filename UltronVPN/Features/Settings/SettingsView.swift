import SwiftUI

struct SettingsView: View {
    @Environment(Theme.self) private var theme
    @Environment(TunnelManager.self) private var tunnel
    @AppStorage(SharedConstants.DefaultsKey.verboseLogging, store: SharedConstants.sharedDefaults)
    private var verboseLogging = false
    @AppStorage(SharedConstants.DefaultsKey.provisioningInstalledAt, store: SharedConstants.sharedDefaults)
    private var installedAtEpoch: Double = 0
    @State private var showLogs = false
    @State private var shareItem: ShareItem?

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground(intensity: 0.25)
                Form {
                    Section("Tunnel provider") {
                        LabeledContent("Status", value: tunnel.snapshot.status.rawValue.capitalized)
                        LabeledContent("Active tunnel", value: tunnel.snapshot.tunnelName ?? "—")
                        LabeledContent("Managers installed", value: "\(tunnel.managers.count)")
                    }
                    Section("Diagnostics") {
                        Toggle("Verbose logging", isOn: $verboseLogging)
                            .onChange(of: verboseLogging) { _, new in
                                Task { await forwardLoggingFlag(new) }
                            }
                        Button("View logs") { showLogs = true }
                        Button("Export logs to Files") { Task { await exportLogs() } }
                    }
                    Section("Sideload reminder") {
                        if installedAtEpoch == 0 {
                            Text("Install date is unset. Tap below after re-signing.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            let installed = Date(timeIntervalSince1970: installedAtEpoch)
                            LabeledContent("Last resigned", value: installed.formatted(date: .abbreviated, time: .shortened))
                        }
                        Button("Mark resigned now") {
                            installedAtEpoch = Date.now.timeIntervalSince1970
                        }
                    }
                    Section("About") {
                        LabeledContent("Version", value: Bundle.main.shortVersion)
                        LabeledContent("Build", value: Bundle.main.buildNumber)
                        Link("WireGuard is © Jason Donenfeld", destination: URL(string: "https://www.wireguard.com/")!)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showLogs) { LogsView() }
            .sheet(item: $shareItem) { item in
                ShareSheet(url: item.url)
            }
        }
    }

    private func forwardLoggingFlag(_ enabled: Bool) async {
        guard let session = tunnel.activeSession else { return }
        let msg = TunnelProviderMessage.setVerboseLogging(enabled).encoded
        try? session.sendProviderMessage(msg) { _ in }
    }

    private func exportLogs() async {
        let text = await Log.ring.snapshot()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ultron-\(Int(Date.now.timeIntervalSince1970)).log")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        shareItem = ShareItem(url: url)
    }
}

private extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "—" }
    var buildNumber:  String { infoDictionary?["CFBundleVersion"] as? String ?? "—" }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
