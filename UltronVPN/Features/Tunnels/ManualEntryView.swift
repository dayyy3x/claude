import SwiftUI

/// Manual entry form — intentionally shaped like a Tailscale/Headscale peering
/// since that's the most common "I already have keys" path for personal use.
struct ManualEntryView: View {
    @Environment(Theme.self) private var theme
    var onSave: (String, WireGuardConfig) throws -> Void

    @State private var name = "Tailnet"
    @State private var interfacePrivateKey = ""
    @State private var interfaceAddress = "100.64.0.2/32"
    @State private var interfaceDNS = "100.100.100.100"

    @State private var peerPublicKey = ""
    @State private var peerEndpoint = ""
    @State private var peerAllowedIPs = "100.64.0.0/10"
    @State private var peerKeepalive = "25"
    @State private var peerPSK = ""

    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Interface") {
                TextField("Name", text: $name)
                TextField("Private key (base64)", text: $interfacePrivateKey)
                    .textInputAutocapitalization(.never)
                    .font(.system(.footnote, design: .monospaced))
                TextField("Address (CIDR)", text: $interfaceAddress)
                    .font(theme.monoCaption)
                TextField("DNS", text: $interfaceDNS)
                    .font(theme.monoCaption)
            }

            Section("Peer") {
                TextField("Public key (base64)", text: $peerPublicKey)
                    .textInputAutocapitalization(.never)
                    .font(.system(.footnote, design: .monospaced))
                TextField("Endpoint (host:port)", text: $peerEndpoint)
                    .font(theme.monoCaption)
                TextField("Allowed IPs", text: $peerAllowedIPs)
                    .font(theme.monoCaption)
                TextField("Keepalive (s)", text: $peerKeepalive)
                    .keyboardType(.numberPad)
                TextField("Preshared key (optional)", text: $peerPSK)
                    .textInputAutocapitalization(.never)
                    .font(.system(.footnote, design: .monospaced))
            }

            Button("Save tunnel", action: save)
                .disabled(interfacePrivateKey.isEmpty || peerPublicKey.isEmpty)
        }
        .scrollContentBackground(.hidden)
        .alert("Invalid configuration",
               isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        do {
            let config = WireGuardConfig(
                interface: .init(
                    privateKeyBase64: interfacePrivateKey.trimmingCharacters(in: .whitespacesAndNewlines),
                    addresses: splitCSV(interfaceAddress),
                    dns: splitCSV(interfaceDNS),
                    mtu: nil, listenPort: nil
                ),
                peers: [
                    .init(
                        publicKeyBase64: peerPublicKey.trimmingCharacters(in: .whitespacesAndNewlines),
                        presharedKeyBase64: peerPSK.isEmpty ? nil : peerPSK,
                        endpoint: peerEndpoint.isEmpty ? nil : peerEndpoint,
                        allowedIPs: splitCSV(peerAllowedIPs),
                        persistentKeepalive: Int(peerKeepalive),
                        displayName: name,
                        note: nil
                    )
                ]
            )
            // Re-run through the validator.
            _ = try WireGuardParser.parse(config.toWGQuickText())
            try onSave(name, config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func splitCSV(_ s: String) -> [String] {
        s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
