@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct BarcodeScannerView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase

  let onCodeScanned: (String) -> Void

  @State private var cameraState: BarcodeCameraState = .checking

  init(_ onCodeScanned: @escaping (String) -> Void) {
    self.onCodeScanned = onCodeScanned
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      switch cameraState {
      case .checking:
        ProgressView()
          .controlSize(.large)
          .tint(.white)

      case .authorized:
        BarcodeCameraPreview { code in
          onCodeScanned(code)
          dismiss()
        }
        .ignoresSafeArea()

      case .denied:
        permissionDeniedView

      case .unavailable:
        cameraUnavailableView
      }

      if cameraState == .authorized {
        VStack {
          Spacer()

          Button {
            dismiss()
          } label: {
            Label("Chiudi scanner", systemImage: "xmark")
              .font(.headline)
              .foregroundStyle(PantryTheme.ink)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(
                PantryTheme.cream,
                in: RoundedRectangle(cornerRadius: 19)
              )
          }
          .buttonStyle(.plain)
          .padding(.horizontal, 22)
          .padding(.bottom, 18)
        }
      }
    }
    .task {
      await updateCameraPermission()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        Task {
          await updateCameraPermission()
        }
      }
    }
  }

  private var permissionDeniedView: some View {
    VStack(spacing: 18) {
      Image(systemName: "camera.fill")
        .font(.system(size: 42))
        .foregroundStyle(PantryTheme.gold)

      Text("Accesso alla fotocamera necessario")
        .font(.title3.bold())
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)

      Text(
        "Per scansionare un codice a barre, abilita la fotocamera nelle Impostazioni di iPhone."
      )
      .font(.subheadline)
      .foregroundStyle(.white.opacity(0.72))
      .multilineTextAlignment(.center)

      Button {
        openAppSettings()
      } label: {
        Label("Apri Impostazioni", systemImage: "gearshape.fill")
          .font(.headline)
          .foregroundStyle(PantryTheme.ink)
          .frame(maxWidth: .infinity)
          .frame(height: 54)
          .background(
            PantryTheme.cream,
            in: RoundedRectangle(cornerRadius: 18)
          )
      }
      .buttonStyle(.plain)

      Button("Annulla") {
        dismiss()
      }
      .font(.headline)
      .foregroundStyle(.white)
    }
    .padding(24)
    .frame(maxWidth: 420)
  }

  private var cameraUnavailableView: some View {
    VStack(spacing: 18) {
      Image(systemName: "camera.fill.badge.exclamationmark")
        .font(.system(size: 42))
        .foregroundStyle(PantryTheme.gold)

      Text("Fotocamera non disponibile")
        .font(.title3.bold())
        .foregroundStyle(.white)

      Text("Prova su un iPhone oppure chiudi e riapri l’app.")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.72))
        .multilineTextAlignment(.center)

      Button("Chiudi") {
        dismiss()
      }
      .font(.headline)
      .foregroundStyle(PantryTheme.ink)
      .frame(maxWidth: .infinity)
      .frame(height: 54)
      .background(
        PantryTheme.cream,
        in: RoundedRectangle(cornerRadius: 18)
      )
      .buttonStyle(.plain)
    }
    .padding(24)
    .frame(maxWidth: 420)
  }

  @MainActor
  private func updateCameraPermission() async {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      cameraState = .unavailable
      return
    }

    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      cameraState = .authorized

    case .notDetermined:
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      cameraState = granted ? .authorized : .denied

    case .denied, .restricted:
      cameraState = .denied

    @unknown default:
      cameraState = .denied
    }
  }

  private func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      return
    }

    UIApplication.shared.open(url)
  }
}

private enum BarcodeCameraState: Equatable {
  case checking
  case authorized
  case denied
  case unavailable
}

private struct BarcodeCameraPreview: UIViewControllerRepresentable {
  let onCodeScanned: (String) -> Void

  func makeUIViewController(context: Context) -> BarcodeCameraViewController {
    BarcodeCameraViewController(onCodeScanned: onCodeScanned)
  }

  func updateUIViewController(
    _ uiViewController: BarcodeCameraViewController,
    context: Context
  ) {}
}

private final class BarcodeCameraViewController: UIViewController,
  AVCaptureMetadataOutputObjectsDelegate
{
  private let captureSession = AVCaptureSession()

  private let sessionQueue = DispatchQueue(
    label: "PantryBuddy.BarcodeScanner.Session"
  )

  private let onCodeScanned: (String) -> Void

  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var hasFinished = false

  init(onCodeScanned: @escaping (String) -> Void) {
    self.onCodeScanned = onCodeScanned
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .black
    configureCamera()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    startScanning()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    stopScanning()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    previewLayer?.frame = view.bounds

    if let connection = previewLayer?.connection,
      connection.isVideoRotationAngleSupported(90)
    {
      connection.videoRotationAngle = 90
    }
  }

  private func configureCamera() {
    captureSession.beginConfiguration()
    captureSession.sessionPreset = .high

    defer {
      captureSession.commitConfiguration()
    }

    guard
      let camera = AVCaptureDevice.default(
        .builtInWideAngleCamera,
        for: .video,
        position: .back
      ),
      let input = try? AVCaptureDeviceInput(device: camera),
      captureSession.canAddInput(input)
    else {
      return
    }

    captureSession.addInput(input)

    let metadataOutput = AVCaptureMetadataOutput()

    guard captureSession.canAddOutput(metadataOutput) else {
      return
    }

    captureSession.addOutput(metadataOutput)

    metadataOutput.setMetadataObjectsDelegate(
      self,
      queue: .main
    )

    let supportedTypes: [AVMetadataObject.ObjectType] = [
      .ean8,
      .ean13,
      .upce,
      .code39,
      .code93,
      .code128,
      .interleaved2of5,
      .itf14
    ]

    metadataOutput.metadataObjectTypes = supportedTypes.filter {
      metadataOutput.availableMetadataObjectTypes.contains($0)
    }

    let previewLayer = AVCaptureVideoPreviewLayer(
      session: captureSession
    )

    previewLayer.videoGravity = .resizeAspectFill

    view.layer.insertSublayer(
      previewLayer,
      at: 0
    )

    self.previewLayer = previewLayer
  }

  private func startScanning() {
    hasFinished = false

    let session = captureSession

    sessionQueue.async {
      guard !session.isRunning else {
        return
      }

      session.startRunning()
    }
  }

  private func stopScanning() {
    let session = captureSession

    sessionQueue.async {
      guard session.isRunning else {
        return
      }

      session.stopRunning()
    }
  }

  nonisolated func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard
      let object =
        metadataObjects.first
        as? AVMetadataMachineReadableCodeObject,
      let code = object.stringValue,
      !code.isEmpty
    else {
      return
    }

    Task { @MainActor [weak self] in
      guard let self, !self.hasFinished else {
        return
      }

      self.hasFinished = true
      self.stopScanning()

      UINotificationFeedbackGenerator()
        .notificationOccurred(.success)

      self.onCodeScanned(code)
    }
  }
}
