@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct ReceiptCameraView: View {
  @Environment(\.scenePhase)
  private var scenePhase

  let onImageCaptured: (UIImage) -> Void
  let onCancel: () -> Void

  @State
  private var cameraState: ReceiptCameraState = .checking

  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea()

      switch cameraState {
      case .checking:
        ProgressView()
          .controlSize(.large)
          .tint(.white)

      case .authorized:
        SystemReceiptCamera(
          onImageCaptured: onImageCaptured,
          onCancel: onCancel
        )
        .ignoresSafeArea()

      case .denied:
        permissionDeniedView

      case .unavailable:
        cameraUnavailableView
      }
    }
    .background(
      Color.black.ignoresSafeArea()
    )
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
      Image(
        systemName: "doc.text.viewfinder"
      )
      .font(.system(size: 44))
      .foregroundStyle(
        PantryTheme.gold
      )

      Text(
        "Fotocamera non autorizzata"
      )
      .font(.title3.bold())
      .foregroundStyle(.white)
      .multilineTextAlignment(.center)

      Text(
        """
        Per fotografare uno scontrino, consenti a PantryBuddy \
        di usare la fotocamera.
        """
      )
      .font(.subheadline)
      .foregroundStyle(
        .white.opacity(0.72)
      )
      .multilineTextAlignment(.center)

      Button {
        openAppSettings()
      } label: {
        Label(
          "Apri Impostazioni",
          systemImage: "gearshape.fill"
        )
        .font(.headline)
        .foregroundStyle(
          PantryTheme.ink
        )
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
          PantryTheme.cream,
          in: RoundedRectangle(
            cornerRadius: 18
          )
        )
      }
      .buttonStyle(.plain)

      Button("Annulla") {
        onCancel()
      }
      .font(.headline)
      .foregroundStyle(.white)
    }
    .padding(24)
    .frame(maxWidth: 420)
  }

  private var cameraUnavailableView: some View {
    VStack(spacing: 18) {
      Image(
        systemName:
          "camera.fill.badge.exclamationmark"
      )
      .font(.system(size: 44))
      .foregroundStyle(
        PantryTheme.gold
      )

      Text(
        "Fotocamera non disponibile"
      )
      .font(.title3.bold())
      .foregroundStyle(.white)

      Text(
        "La fotocamera non può essere aperta su questo dispositivo."
      )
      .font(.subheadline)
      .foregroundStyle(
        .white.opacity(0.72)
      )
      .multilineTextAlignment(.center)

      Button("Chiudi") {
        onCancel()
      }
      .font(.headline)
      .foregroundStyle(
        PantryTheme.ink
      )
      .frame(maxWidth: .infinity)
      .frame(height: 54)
      .background(
        PantryTheme.cream,
        in: RoundedRectangle(
          cornerRadius: 18
        )
      )
      .buttonStyle(.plain)
    }
    .padding(24)
    .frame(maxWidth: 420)
  }

  @MainActor
  private func updateCameraPermission() async {
    guard
      UIImagePickerController
        .isSourceTypeAvailable(.camera)
    else {
      cameraState = .unavailable
      return
    }

    switch AVCaptureDevice
      .authorizationStatus(for: .video)
    {
    case .authorized:
      cameraState = .authorized

    case .notDetermined:
      let granted =
        await AVCaptureDevice
        .requestAccess(for: .video)

      cameraState =
        granted
        ? .authorized
        : .denied

    case .denied,
      .restricted:
      cameraState = .denied

    @unknown default:
      cameraState = .denied
    }
  }

  private func openAppSettings() {
    guard
      let url = URL(
        string:
          UIApplication
          .openSettingsURLString
      )
    else {
      return
    }

    UIApplication.shared.open(url)
  }
}

private enum ReceiptCameraState: Equatable {
  case checking
  case authorized
  case denied
  case unavailable
}

private struct SystemReceiptCamera:
  UIViewControllerRepresentable
{
  let onImageCaptured: (UIImage) -> Void
  let onCancel: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(
      onImageCaptured: onImageCaptured,
      onCancel: onCancel
    )
  }

  func makeUIViewController(
    context: Context
  ) -> UIImagePickerController {
    let picker =
      UIImagePickerController()

    picker.delegate =
      context.coordinator

    picker.sourceType = .camera
    picker.cameraCaptureMode = .photo
    picker.cameraDevice = .rear
    picker.showsCameraControls = true
    picker.modalPresentationStyle =
      .fullScreen
    picker.view.backgroundColor =
      .black

    return picker
  }

  func updateUIViewController(
    _ uiViewController:
      UIImagePickerController,
    context: Context
  ) {
    uiViewController
      .view
      .backgroundColor = .black
  }

  final class Coordinator:
    NSObject,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
  {
    private var hasCompletedCapture = false

    private let onImageCaptured:
      (UIImage) -> Void

    private let onCancel: () -> Void

    init(
      onImageCaptured:
        @escaping (UIImage) -> Void,
      onCancel:
        @escaping () -> Void
    ) {
      self.onImageCaptured =
        onImageCaptured

      self.onCancel =
        onCancel
    }

    func imagePickerController(
      _ picker:
        UIImagePickerController,
      didFinishPickingMediaWithInfo info:
        [UIImagePickerController.InfoKey: Any]
    ) {
      guard !hasCompletedCapture else {
        return
      }

      hasCompletedCapture = true

      guard
        let image =
          info[.originalImage]
          as? UIImage
      else {
        DispatchQueue.main.async {
          self.onCancel()
        }
        return
      }

      let preparedImage =
        prepareForReceiptRecognition(
          image
        )

      // Lascia terminare il callback UIKit
      // prima di chiudere la schermata SwiftUI.
      DispatchQueue.main.async {
        self.onImageCaptured(
          preparedImage
        )
      }
    }

    func imagePickerControllerDidCancel(
      _ picker:
        UIImagePickerController
    ) {
      guard !hasCompletedCapture else {
        return
      }

      hasCompletedCapture = true

      DispatchQueue.main.async {
        self.onCancel()
      }
    }

    private func prepareForReceiptRecognition(
      _ image: UIImage
    ) -> UIImage {
      guard
        let sourceImage = image.cgImage
      else {
        return image
      }

      let maximumPixelDimension:
        CGFloat = 2_400

      let sourceWidth =
        CGFloat(sourceImage.width)

      let sourceHeight =
        CGFloat(sourceImage.height)

      let largestDimension = max(
        sourceWidth,
        sourceHeight
      )

      let needsResize =
        largestDimension
        > maximumPixelDimension

      let needsOrientationNormalization =
        image.imageOrientation != .up

      guard
        needsResize
          || needsOrientationNormalization
      else {
        return image
      }

      let scale = min(
        1,
        maximumPixelDimension
          / largestDimension
      )

      let targetSize = CGSize(
        width: max(
          1,
          (
            image.size.width
              * scale
          ).rounded()
        ),
        height: max(
          1,
          (
            image.size.height
              * scale
          ).rounded()
        )
      )

      let format =
        UIGraphicsImageRendererFormat()

      format.scale = 1
      format.opaque = true

      return UIGraphicsImageRenderer(
        size: targetSize,
        format: format
      ).image { _ in
        image.draw(
          in: CGRect(
            origin: .zero,
            size: targetSize
          )
        )
      }
    }
  }
}
