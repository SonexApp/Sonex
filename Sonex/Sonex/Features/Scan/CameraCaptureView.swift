//
//  CameraCaptureView.swift
//  Sonex
//
//  Created by Assistant on 4/14/26.
//

import SwiftUI
import UIKit
import AVFoundation

struct CameraCaptureView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> CameraCaptureViewController {
        let controller = CameraCaptureViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraCaptureViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraCaptureDelegate {
        let parent: CameraCaptureView
        
        init(_ parent: CameraCaptureView) {
            self.parent = parent
        }
        
        func didCaptureImage(_ image: UIImage) {
            parent.onImageCaptured(image)
            parent.isPresented = false
        }
        
        func didCancelCapture() {
            parent.isPresented = false
        }
    }
}

protocol CameraCaptureDelegate: AnyObject {
    func didCaptureImage(_ image: UIImage)
    func didCancelCapture()
}

class CameraCaptureViewController: UIViewController {
    weak var delegate: CameraCaptureDelegate?
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private let shutterButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let flashButton = UIButton(type: .system)
    private let cropOverlayView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
        
        // Listen for orientation changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func orientationChanged() {
        guard let connection = previewLayer?.connection,
              connection.isVideoOrientationSupported else { return }
        
        connection.videoOrientation = getCurrentVideoOrientation()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCamera()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        guard let captureSession = captureSession,
              let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Unable to access back camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            photoOutput = AVCapturePhotoOutput()
            
            if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                
                // Configure photo output for high quality
                if photoOutput.isHighResolutionCaptureEnabled {
                    photoOutput.isHighResolutionCaptureEnabled = true
                }
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            
            // Set the initial orientation
            if let connection = previewLayer?.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = getCurrentVideoOrientation()
            }
            
        } catch {
            print("Error setting up camera: \(error)")
        }
    }
    
    private func getCurrentVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIApplication.shared.statusBarOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return .portrait
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Preview layer
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        // Crop overlay to show capture area
        setupCropOverlay()
        
        // Cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        cancelButton.layer.cornerRadius = 8
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        // Flash button
        flashButton.setImage(UIImage(systemName: "bolt.slash"), for: .normal)
        flashButton.tintColor = .white
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        flashButton.layer.cornerRadius = 25
        flashButton.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)
        
        // Shutter button
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 35
        shutterButton.layer.borderWidth = 4
        shutterButton.layer.borderColor = UIColor.white.cgColor
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        
        // Add constraints
        view.addSubview(cancelButton)
        view.addSubview(flashButton)
        view.addSubview(shutterButton)
        view.addSubview(cropOverlayView)
        
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        cropOverlayView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Cancel button
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Flash button
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            flashButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            flashButton.widthAnchor.constraint(equalToConstant: 50),
            flashButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Shutter button
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70),
            
            // Crop overlay
            cropOverlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cropOverlayView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cropOverlayView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            cropOverlayView.heightAnchor.constraint(equalTo: cropOverlayView.widthAnchor)
        ])
    }
    
    private func setupCropOverlay() {
        cropOverlayView.backgroundColor = .clear
        cropOverlayView.layer.borderColor = UIColor.white.cgColor
        cropOverlayView.layer.borderWidth = 2
        cropOverlayView.layer.cornerRadius = 8
        cropOverlayView.isUserInteractionEnabled = false
        
        // Add corner indicators
        let cornerLength: CGFloat = 20
        let cornerWidth: CGFloat = 3
        
        for i in 0..<4 {
            let corner = UIView()
            corner.backgroundColor = .white
            cropOverlayView.addSubview(corner)
            corner.translatesAutoresizingMaskIntoConstraints = false
            
            let horizontal = UIView()
            let vertical = UIView()
            horizontal.backgroundColor = .white
            vertical.backgroundColor = .white
            corner.addSubview(horizontal)
            corner.addSubview(vertical)
            horizontal.translatesAutoresizingMaskIntoConstraints = false
            vertical.translatesAutoresizingMaskIntoConstraints = false
            
            switch i {
            case 0: // Top-left
                NSLayoutConstraint.activate([
                    corner.topAnchor.constraint(equalTo: cropOverlayView.topAnchor),
                    corner.leadingAnchor.constraint(equalTo: cropOverlayView.leadingAnchor),
                    corner.widthAnchor.constraint(equalToConstant: cornerLength),
                    corner.heightAnchor.constraint(equalToConstant: cornerLength),
                    
                    horizontal.topAnchor.constraint(equalTo: corner.topAnchor),
                    horizontal.leadingAnchor.constraint(equalTo: corner.leadingAnchor),
                    horizontal.widthAnchor.constraint(equalToConstant: cornerLength),
                    horizontal.heightAnchor.constraint(equalToConstant: cornerWidth),
                    
                    vertical.topAnchor.constraint(equalTo: corner.topAnchor),
                    vertical.leadingAnchor.constraint(equalTo: corner.leadingAnchor),
                    vertical.widthAnchor.constraint(equalToConstant: cornerWidth),
                    vertical.heightAnchor.constraint(equalToConstant: cornerLength)
                ])
            case 1: // Top-right
                NSLayoutConstraint.activate([
                    corner.topAnchor.constraint(equalTo: cropOverlayView.topAnchor),
                    corner.trailingAnchor.constraint(equalTo: cropOverlayView.trailingAnchor),
                    corner.widthAnchor.constraint(equalToConstant: cornerLength),
                    corner.heightAnchor.constraint(equalToConstant: cornerLength),
                    
                    horizontal.topAnchor.constraint(equalTo: corner.topAnchor),
                    horizontal.trailingAnchor.constraint(equalTo: corner.trailingAnchor),
                    horizontal.widthAnchor.constraint(equalToConstant: cornerLength),
                    horizontal.heightAnchor.constraint(equalToConstant: cornerWidth),
                    
                    vertical.topAnchor.constraint(equalTo: corner.topAnchor),
                    vertical.trailingAnchor.constraint(equalTo: corner.trailingAnchor),
                    vertical.widthAnchor.constraint(equalToConstant: cornerWidth),
                    vertical.heightAnchor.constraint(equalToConstant: cornerLength)
                ])
            case 2: // Bottom-left
                NSLayoutConstraint.activate([
                    corner.bottomAnchor.constraint(equalTo: cropOverlayView.bottomAnchor),
                    corner.leadingAnchor.constraint(equalTo: cropOverlayView.leadingAnchor),
                    corner.widthAnchor.constraint(equalToConstant: cornerLength),
                    corner.heightAnchor.constraint(equalToConstant: cornerLength),
                    
                    horizontal.bottomAnchor.constraint(equalTo: corner.bottomAnchor),
                    horizontal.leadingAnchor.constraint(equalTo: corner.leadingAnchor),
                    horizontal.widthAnchor.constraint(equalToConstant: cornerLength),
                    horizontal.heightAnchor.constraint(equalToConstant: cornerWidth),
                    
                    vertical.bottomAnchor.constraint(equalTo: corner.bottomAnchor),
                    vertical.leadingAnchor.constraint(equalTo: corner.leadingAnchor),
                    vertical.widthAnchor.constraint(equalToConstant: cornerWidth),
                    vertical.heightAnchor.constraint(equalToConstant: cornerLength)
                ])
            case 3: // Bottom-right
                NSLayoutConstraint.activate([
                    corner.bottomAnchor.constraint(equalTo: cropOverlayView.bottomAnchor),
                    corner.trailingAnchor.constraint(equalTo: cropOverlayView.trailingAnchor),
                    corner.widthAnchor.constraint(equalToConstant: cornerLength),
                    corner.heightAnchor.constraint(equalToConstant: cornerLength),
                    
                    horizontal.bottomAnchor.constraint(equalTo: corner.bottomAnchor),
                    horizontal.trailingAnchor.constraint(equalTo: corner.trailingAnchor),
                    horizontal.widthAnchor.constraint(equalToConstant: cornerLength),
                    horizontal.heightAnchor.constraint(equalToConstant: cornerWidth),
                    
                    vertical.bottomAnchor.constraint(equalTo: corner.bottomAnchor),
                    vertical.trailingAnchor.constraint(equalTo: corner.trailingAnchor),
                    vertical.widthAnchor.constraint(equalToConstant: cornerWidth),
                    vertical.heightAnchor.constraint(equalToConstant: cornerLength)
                ])
            default:
                break
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Ensure preview layer fills the view properly
        guard let previewLayer = previewLayer else { return }
        
        previewLayer.frame = view.bounds
        
        // Make sure the preview layer is behind other UI elements
        view.layer.insertSublayer(previewLayer, at: 0)
    }
    
    private func startCamera() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func stopCamera() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    @objc private func shutterTapped() {
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        // Set photo orientation to match current device orientation
        if let connection = photoOutput.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = getCurrentVideoOrientation()
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func cancelTapped() {
        delegate?.didCancelCapture()
    }
    
    @objc private func flashTapped() {
        // Toggle flash mode
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .off {
                device.torchMode = .on
                flashButton.setImage(UIImage(systemName: "bolt"), for: .normal)
            } else {
                device.torchMode = .off
                flashButton.setImage(UIImage(systemName: "bolt.slash"), for: .normal)
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Flash toggle error: \(error)")
        }
    }
}

extension CameraCaptureViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("Error capturing photo: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        // Crop the image to match the overlay and fit to screen
        let processedImage = cropImageToMatchOverlay(image)
        delegate?.didCaptureImage(processedImage)
    }
    
    private func cropImageToMatchOverlay(_ image: UIImage) -> UIImage {
        guard let previewLayer = previewLayer else { return image }
        
        // Get the preview layer bounds and the crop overlay frame
        let previewBounds = previewLayer.bounds
        let overlayFrame = cropOverlayView.frame
        
        // Convert overlay frame to preview layer coordinates
        let overlayInPreview = view.convert(overlayFrame, to: view)
        
        // Calculate the crop rectangle in image coordinates
        let imageSize = image.size
        let previewSize = previewBounds.size
        
        // Account for the preview layer's video gravity (aspect fill)
        let imageAspectRatio = imageSize.width / imageSize.height
        let previewAspectRatio = previewSize.width / previewSize.height
        
        var scaledImageSize: CGSize
        var imageOffset: CGPoint
        
        if imageAspectRatio > previewAspectRatio {
            // Image is wider than preview - scale by height
            let scaleFactor = previewSize.height / imageSize.height
            scaledImageSize = CGSize(width: imageSize.width * scaleFactor, height: previewSize.height)
            imageOffset = CGPoint(x: (previewSize.width - scaledImageSize.width) / 2, y: 0)
        } else {
            // Image is taller than preview - scale by width
            let scaleFactor = previewSize.width / imageSize.width
            scaledImageSize = CGSize(width: previewSize.width, height: imageSize.height * scaleFactor)
            imageOffset = CGPoint(x: 0, y: (previewSize.height - scaledImageSize.height) / 2)
        }
        
        // Calculate crop rectangle relative to the scaled image
        let cropX = (overlayInPreview.origin.x - imageOffset.x) / scaledImageSize.width
        let cropY = (overlayInPreview.origin.y - imageOffset.y) / scaledImageSize.height
        let cropWidth = overlayInPreview.size.width / scaledImageSize.width
        let cropHeight = overlayInPreview.size.height / scaledImageSize.height
        
        // Convert to image pixel coordinates
        let pixelCropRect = CGRect(
            x: cropX * imageSize.width,
            y: cropY * imageSize.height,
            width: cropWidth * imageSize.width,
            height: cropHeight * imageSize.height
        )
        
        // Ensure crop rect is within image bounds
        let clampedCropRect = CGRect(
            x: max(0, min(pixelCropRect.origin.x, imageSize.width - 1)),
            y: max(0, min(pixelCropRect.origin.y, imageSize.height - 1)),
            width: min(pixelCropRect.size.width, imageSize.width - pixelCropRect.origin.x),
            height: min(pixelCropRect.size.height, imageSize.height - pixelCropRect.origin.y)
        )
        
        // Perform the crop
        guard let cgImage = image.cgImage?.cropping(to: clampedCropRect) else {
            return image // Return original if cropping fails
        }
        
        let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        
        // Scale the image to fit screen if needed
        return scaleImageToFitScreen(croppedImage)
    }
    
    private func scaleImageToFitScreen(_ image: UIImage) -> UIImage {
        let screenSize = UIScreen.main.bounds.size
        let imageSize = image.size
        
        // Calculate scale factor to fit screen while maintaining aspect ratio
        let widthScale = screenSize.width / imageSize.width
        let heightScale = screenSize.height / imageSize.height
        let scaleFactor = min(widthScale, heightScale)
        
        // Don't scale up small images, only scale down large ones
        guard scaleFactor < 1.0 else { return image }
        
        let newSize = CGSize(
            width: imageSize.width * scaleFactor,
            height: imageSize.height * scaleFactor
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        guard let scaledImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return image
        }
        
        return scaledImage
    }
}
