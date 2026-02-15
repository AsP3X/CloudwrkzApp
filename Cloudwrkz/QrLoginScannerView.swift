//
//  QrLoginScannerView.swift
//  Cloudwrkz
//
//  Camera scanner for QR login. Parses URL from QR (e.g. https://domain/qr-login?r=REQUEST_ID) and calls approve API.
//

import SwiftUI
import AVFoundation

struct QrLoginScannerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSuccess: (() -> Void)?
    var onDismiss: (() -> Void)?

    @State private var status: Status = .scanning
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var scannerKey = 0

    private let config = ServerConfig.load()

    enum Status {
        case scanning
        case processing
        case success
        case failure
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    if status == .scanning || status == .processing {
                        QrCameraView(
                            onCodeScanned: { urlString in
                                guard status == .scanning else { return }
                                handleScannedCode(urlString)
                            }
                        )
                        .id(scannerKey)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(CloudwrkzColors.primary500.opacity(0.3), lineWidth: 2)
                        )
                        .padding(.horizontal, 24)

                        if status == .processing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: CloudwrkzColors.primary400))
                                .scaleEffect(1.2)
                            Text("Signing in…")
                                .font(.subheadline)
                                .foregroundStyle(CloudwrkzColors.neutral400)
                        } else {
                            Text("Point your camera at the QR code on the website")
                                .font(.subheadline)
                                .foregroundStyle(CloudwrkzColors.neutral400)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    } else if status == .success {
                        Group {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(CloudwrkzColors.success500)
                            if let msg = successMessage {
                                Text(msg)
                                    .font(.headline)
                                    .foregroundStyle(CloudwrkzColors.neutral100)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .onAppear {
                            onSuccess?()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                            }
                        }
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(CloudwrkzColors.error500)
                        if let msg = errorMessage {
                            Text(msg)
                                .font(.subheadline)
                                .foregroundStyle(CloudwrkzColors.neutral400)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Button("Try again") {
                            errorMessage = nil
                            scannerKey += 1
                            status = .scanning
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CloudwrkzColors.primary500)
                    }
                }
                .padding(.vertical, 32)
            }
            .navigationTitle("Login with QR code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss?()
                        dismiss()
                    }
                    .foregroundStyle(CloudwrkzColors.primary400)
                }
            }
        }
    }

    private func handleScannedCode(_ urlString: String) {
        status = .processing

        guard let requestId = requestIdFromQrPayload(urlString) else {
            status = .failure
            errorMessage = "This doesn’t look like a Cloudwrkz login QR code. Open the website login page and choose “Sign in with QR code”."
            return
        }

        Task { @MainActor in
            switch await QrLoginService.approve(requestId: requestId, config: config) {
            case .success:
                status = .success
                successMessage = "The browser will sign you in shortly."
            case .failure(let err):
                status = .failure
                errorMessage = messageForFailure(err)
            }
        }
    }

    private func requestIdFromQrPayload(_ payload: String) -> String? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name.lowercased() == "r" })?.value
    }

    private func messageForFailure(_ err: QrLoginApproveFailure) -> String {
        switch err {
        case .noServerURL:
            return "Server URL is not configured."
        case .noToken:
            return "You must be signed in in the app first."
        case .invalidRequestId:
            return "Invalid QR code."
        case .unauthorized:
            return "Session expired. Please sign in again in the app."
        case .requestNotFoundOrExpired:
            return "This QR code has expired. Please show a new one on the website."
        case .requestAlreadyUsedOrExpired:
            return "This QR code was already used."
        case .requestExpired:
            return "This QR code has expired. Please show a new one on the website."
        case .serverError(let message):
            return message
        case .networkError(let description):
            return "Network error: \(description)"
        }
    }
}

// MARK: - Camera capture for QR

private struct QrCameraView: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QrCameraViewController {
        let vc = QrCameraViewController()
        vc.onCodeScanned = onCodeScanned
        return vc
    }

    func updateUIViewController(_ uiViewController: QrCameraViewController, context: Context) {}
}

private final class QrCameraViewController: UIViewController {
    var onCodeScanned: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasReported = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let session = AVCaptureSession()
        self.captureSession = session

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.metadataObjectTypes = [.qr]
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        self.previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}

extension QrCameraViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasReported,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let str = obj.stringValue, !str.isEmpty else {
            return
        }
        hasReported = true
        captureSession?.stopRunning()
        onCodeScanned?(str)
    }
}
