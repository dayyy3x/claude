import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct ImportTunnelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(TunnelManager.self) private var tunnelManager
    @Environment(Theme.self) private var theme

    enum Source { case chooser, qr, pasted, filePicker, manual }
    @State private var source: Source = .chooser
    @State private var pastedText = ""
    @State private var name = "Home"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground(intensity: 0.3)
                Group {
                    switch source {
                    case .chooser:    chooser
                    case .qr:         QRScannerSheet(onResult: handleScan)
                    case .pasted:     pasteForm
                    case .filePicker: fileImporter
                    case .manual:     ManualEntryView(onSave: finalize)
                    }
                }
            }
            .navigationTitle("Import tunnel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if source != .chooser {
                        Button("Back") { source = .chooser }
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .alert("Couldn’t import",
                   isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
                   actions: { Button("OK", role: .cancel) {} },
                   message: { Text(errorMessage ?? "") })
        }
    }

    private var chooser: some View {
        VStack(spacing: 14) {
            option("Scan QR code", systemImage: "qrcode.viewfinder") { source = .qr }
            option("Paste config", systemImage: "doc.on.clipboard") {
                if let s = UIPasteboard.general.string { pastedText = s }
                source = .pasted
            }
            option("Import .conf file", systemImage: "folder") { source = .filePicker }
            option("Manual entry (Tailscale/Headscale)", systemImage: "keyboard") { source = .manual }
            Spacer()
        }
        .padding(20)
    }

    private func option(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(theme.accent)
                    .frame(width: 32)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.bgElevated)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.stroke))
            }
        }
        .buttonStyle(.plain)
    }

    private var pasteForm: some View {
        Form {
            Section("Name") {
                TextField("Home", text: $name)
            }
            Section("Configuration") {
                TextEditor(text: $pastedText)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(minHeight: 180)
            }
            Button("Import") { saveText(pastedText) }
                .disabled(pastedText.isEmpty)
        }
        .scrollContentBackground(.hidden)
    }

    private var fileImporter: some View {
        FilePickerView { url in
            do {
                let text = try String(contentsOf: url)
                name = url.deletingPathExtension().lastPathComponent
                saveText(text)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Flow

    private func handleScan(_ payload: String) {
        pastedText = payload
        saveText(payload)
    }

    private func saveText(_ text: String) {
        do {
            let cfg = try WireGuardParser.parse(text)
            try finalize(name: name, config: cfg)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finalize(name: String, config: WireGuardConfig) throws {
        let record = TunnelRecord(
            name: name,
            keychainTag: UUID().uuidString,
            configJSON: try? JSONEncoder().encode(strippedConfig(config))
        )
        try KeychainService.shared.set(config.interface.privateKeyBase64, for: "\(record.keychainTag).privkey")
        for peer in config.peers {
            if let psk = peer.presharedKeyBase64 {
                try KeychainService.shared.set(psk, for: "\(record.keychainTag).psk.\(peer.id.uuidString)")
            }
            let peerRecord = PeerRecord(
                tunnelID: record.id,
                displayName: peer.displayName ?? peer.publicKeyBase64.prefix(6).description,
                publicKeyBase64: peer.publicKeyBase64,
                endpoint: peer.endpoint,
                allowedIPs: peer.allowedIPs,
                reachableIP: peer.allowedIPs.first?.components(separatedBy: "/").first,
                osGlyph: peer.displayName?.lowercased().contains("mac") == true ? "laptopcomputer" : "pc",
                isStreamHost: peer.displayName?.lowercased().contains("pc") == true
            )
            context.insert(peerRecord)
        }
        context.insert(record)
        try context.save()

        Task { @MainActor in
            try await tunnelManager.install(tunnel: record, config: config)
            dismiss()
        }
    }

    /// Strip private key material from the Codable config before storing it in SwiftData.
    private func strippedConfig(_ cfg: WireGuardConfig) -> WireGuardConfig {
        var stripped = cfg
        stripped.interface.privateKeyBase64 = ""
        stripped.peers = stripped.peers.map {
            var p = $0
            p.presharedKeyBase64 = nil
            return p
        }
        return stripped
    }
}

private struct FilePickerView: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [
            UTType(filenameExtension: "conf") ?? .text,
            .text,
            .plainText,
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            onPick(url)
        }
    }
}
