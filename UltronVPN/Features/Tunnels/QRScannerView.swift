import SwiftUI
import AVFoundation

struct QRScannerSheet: View {
    @Environment(Theme.self) private var theme
    var onResult: (String) -> Void

    var body: some View {
        ZStack {
            QRCameraView(onResult: onResult)
                .ignoresSafeArea()
            VStack {
                Spacer()
                Text("Point the camera at a WireGuard QR code")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
            }
            reticle
        }
    }

    private var reticle: some View {
        RoundedRectangle(cornerRadius: 24)
            .strokeBorder(theme.accent, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
            .frame(width: 240, height: 240)
            .shadow(color: theme.accent.opacity(0.6), radius: 20)
    }
}

private struct QRCameraView: UIViewControllerRepresentable {
    var onResult: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return vc }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = UIScreen.main.bounds
        vc.view.layer.addSublayer(preview)
        context.coordinator.preview = preview

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        context.coordinator.preview?.frame = vc.view.bounds
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        weak var session: AVCaptureSession?
        var preview: AVCaptureVideoPreviewLayer?
        var didFire = false
        let onResult: (String) -> Void
        init(onResult: @escaping (String) -> Void) { self.onResult = onResult }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !didFire,
                  let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            didFire = true
            session?.stopRunning()
            onResult(value)
        }
    }
}
