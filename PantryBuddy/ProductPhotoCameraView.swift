@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct ProductPhotoCameraView: View {

    @Environment(\.scenePhase)
    private var scenePhase

    let onImageCaptured: (UIImage) -> Void
    let onCancel: () -> Void

    @State
    private var cameraState: ProductPhotoCameraState = .checking

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
                ProductSystemCamera(
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

    // MARK: - Permesso negato

    private var permissionDeniedView: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(PantryTheme.gold)

            Text("Fotocamera non autorizzata")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(
                "Consenti a PantryBuddy di usare la fotocamera per aggiungere la foto del prodotto."
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
                .foregroundStyle(PantryTheme.ink)
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

    // MARK: - Fotocamera non disponibile

    private var cameraUnavailableView: some View {
        VStack(spacing: 18) {
            Image(
                systemName: "camera.fill.badge.exclamationmark"
            )
            .font(.system(size: 44))
            .foregroundStyle(PantryTheme.gold)

            Text("Fotocamera non disponibile")
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
            .foregroundStyle(PantryTheme.ink)
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

    // MARK: - Autorizzazione

    @MainActor
    private func updateCameraPermission() async {
        guard UIImagePickerController
            .isSourceTypeAvailable(.camera)
        else {
            cameraState = .unavailable
            return
        }

        switch AVCaptureDevice.authorizationStatus(
            for: .video
        ) {
        case .authorized:
            cameraState = .authorized

        case .notDetermined:
            let granted =
                await AVCaptureDevice.requestAccess(
                    for: .video
                )

            cameraState =
                granted
                ? .authorized
                : .denied

        case .denied, .restricted:
            cameraState = .denied

        @unknown default:
            cameraState = .denied
        }
    }

    private func openAppSettings() {
        guard let url = URL(
            string: UIApplication.openSettingsURLString
        ) else {
            return
        }

        UIApplication.shared.open(url)
    }
}

// MARK: - Preparazione immagine

enum ProductPhotoStorage {

    static func compressedData(
        from image: UIImage
    ) -> Data? {
        /*
         La foto viene ridimensionata prima di essere salvata.

         Questo evita di conservare nel database una foto
         originale da molti megabyte.
         */
        let maximumDimension: CGFloat = 1_200
        let originalSize = image.size

        guard
            originalSize.width > 0,
            originalSize.height > 0
        else {
            return nil
        }

        let longestSide = max(
            originalSize.width,
            originalSize.height
        )

        let scale = min(
            1,
            maximumDimension / longestSide
        )

        let targetSize = CGSize(
            width: max(
                1,
                originalSize.width * scale
            ),
            height: max(
                1,
                originalSize.height * scale
            )
        )

        let format = UIGraphicsImageRendererFormat()

        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: targetSize,
            format: format
        )

        let resizedImage = renderer.image { context in
            UIColor.white.setFill()

            context.fill(
                CGRect(
                    origin: .zero,
                    size: targetSize
                )
            )

            image.draw(
                in: CGRect(
                    origin: .zero,
                    size: targetSize
                )
            )
        }

        return resizedImage.jpegData(
            compressionQuality: 0.82
        )
    }
}

// MARK: - Stato fotocamera

private enum ProductPhotoCameraState: Equatable {
    case checking
    case authorized
    case denied
    case unavailable
}

// MARK: - Fotocamera di sistema

private struct ProductSystemCamera:
    UIViewControllerRepresentable {

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
        let picker = UIImagePickerController()

        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        picker.showsCameraControls = true
        picker.modalPresentationStyle = .fullScreen
        picker.view.backgroundColor = .black

        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {
        uiViewController
            .view
            .backgroundColor = .black
    }

    final class Coordinator:
        NSObject,
        UIImagePickerControllerDelegate,
        UINavigationControllerDelegate {

        private var hasCompleted = false

        private let onImageCaptured: (UIImage) -> Void
        private let onCancel: () -> Void

        init(
            onImageCaptured: @escaping (UIImage) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onImageCaptured = onImageCaptured
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info:
                [UIImagePickerController.InfoKey: Any]
        ) {
            guard
                !hasCompleted,
                let image =
                    info[.originalImage] as? UIImage
            else {
                return
            }

            hasCompleted = true

            DispatchQueue.main.async {
                [onImageCaptured] in

                onImageCaptured(image)
            }
        }

        func imagePickerControllerDidCancel(
            _ picker: UIImagePickerController
        ) {
            guard !hasCompleted else {
                return
            }

            hasCompleted = true

            DispatchQueue.main.async {
                [onCancel] in

                onCancel()
            }
        }
    }
}
