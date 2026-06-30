//
//  AlbumCoverCameraView.swift
//  Sonex
//
//  Created by Assistant on 4/21/26.
//

import SwiftUI
import UIKit
import AVFoundation

struct AlbumCoverCameraView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let cameraController = AlbumCoverCameraViewController()
        cameraController.delegate = context.coordinator
        let navigationController = UINavigationController(rootViewController: cameraController)
        navigationController.modalPresentationStyle = .fullScreen
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AlbumCoverCameraDelegate, PhotoCropDelegate {
        let parent: AlbumCoverCameraView
        
        init(_ parent: AlbumCoverCameraView) {
            self.parent = parent
        }
        
        func didCaptureRawImage(_ image: UIImage, from viewController: AlbumCoverCameraViewController) {
            print("Coordinator: didCaptureRawImage called with image size: \(image.size)")
            
            guard let navigationController = viewController.navigationController else {
                print("Coordinator: Failed to get navigation controller from view controller")
                return
            }
            
            print("Coordinator: Successfully got navigation controller, creating crop view controller")
            
            let cropViewController = PhotoCropViewController()
            cropViewController.originalImage = image
            cropViewController.delegate = self
            
            print("Coordinator: About to push crop view controller")
            navigationController.pushViewController(cropViewController, animated: true)
            print("Coordinator: Crop view controller push initiated")
        }
        
        func didFinalizeCroppedImage(_ image: UIImage) {
            parent.onImageCaptured(image)
            parent.isPresented = false
        }
        
        func didCancelCapture() {
            parent.isPresented = false
        }
        
        func didCancelCrop() {
            parent.isPresented = false
        }
    }
}


protocol AlbumCoverCameraDelegate: AnyObject {
    func didCaptureRawImage(_ image: UIImage, from viewController: AlbumCoverCameraViewController)
    func didCancelCapture()
}

protocol PhotoCropDelegate: AnyObject {
    func didFinalizeCroppedImage(_ image: UIImage)
    func didCancelCrop()
}

class AlbumCoverCameraViewController: UIViewController {
    weak var delegate: AlbumCoverCameraDelegate?
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private let shutterButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let flashButton = UIButton(type: .system)
    private let instructionLabel = UILabel()
    
    private var isFlashOn = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        requestCameraPermission()
        setupUI()
        setupInstructions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCamera()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopCamera()
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.isHidden = true
    }
    
    private func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showCameraPermissionAlert()
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionAlert()
        @unknown default:
            showCameraPermissionAlert()
        }
    }
    
    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "Please allow camera access in Settings to take photos.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.delegate?.didCancelCapture()
        })
        
        present(alert, animated: true)
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        // Use the highest quality preset available
        if captureSession?.canSetSessionPreset(.photo) == true {
            captureSession?.sessionPreset = .photo
        } else if captureSession?.canSetSessionPreset(.high) == true {
            captureSession?.sessionPreset = .high
        }
        
        guard let captureSession = captureSession,
              let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Unable to access back camera")
            DispatchQueue.main.async { [weak self] in
                self?.showCameraSetupError()
            }
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                throw CameraError.cannotAddInput
            }
            
            photoOutput = AVCapturePhotoOutput()
            
            guard let photoOutput = photoOutput else {
                throw CameraError.cannotCreatePhotoOutput
            }
            
            // Enable high resolution photo capture
            photoOutput.isHighResolutionCaptureEnabled = true
            
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            } else {
                throw CameraError.cannotAddOutput
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill  // Keep fill for camera preview
            
            DispatchQueue.main.async { [weak self] in
                self?.setupPreviewLayer()
            }
            
        } catch {
            print("Error setting up camera: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.showCameraSetupError()
            }
        }
    }
    
    private func setupPreviewLayer() {
        guard let previewLayer = previewLayer else { return }
        view.layer.insertSublayer(previewLayer, at: 0)
        previewLayer.frame = view.bounds
    }
    
    private func showCameraSetupError() {
        let alert = UIAlertController(
            title: "Camera Error",
            message: "Unable to set up the camera. Please try again.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.delegate?.didCancelCapture()
        })
        
        present(alert, animated: true)
    }
    
    private enum CameraError: Error {
        case cannotAddInput
        case cannotCreatePhotoOutput
        case cannotAddOutput
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        cancelButton.layer.cornerRadius = 8
        cancelButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        // Flash button
        updateFlashButtonAppearance()
        flashButton.tintColor = .white
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        flashButton.layer.cornerRadius = 25
        flashButton.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)
        
        // Shutter button
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 35
        shutterButton.layer.borderWidth = 4
        shutterButton.layer.borderColor = UIColor.lightGray.cgColor
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        
        // Add button press animation
        shutterButton.addTarget(self, action: #selector(shutterButtonPressed), for: .touchDown)
        shutterButton.addTarget(self, action: #selector(shutterButtonReleased), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        // Add to view
        view.addSubview(cancelButton)
        view.addSubview(flashButton)
        view.addSubview(shutterButton)
        
        setupConstraints()
    }
    
    private func setupInstructions() {
        instructionLabel.text = "  Take a photo of the album cover  "
        instructionLabel.textColor = .white
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        instructionLabel.layer.cornerRadius = 8
        instructionLabel.clipsToBounds = true
        instructionLabel.numberOfLines = 1
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            instructionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            instructionLabel.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupConstraints() {
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Cancel button
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Flash button
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            flashButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            flashButton.widthAnchor.constraint(equalToConstant: 50),
            flashButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Shutter button
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70)
        ])
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
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
    
    private func updateFlashButtonAppearance() {
        let imageName = isFlashOn ? "bolt.fill" : "bolt.slash"
        flashButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    @objc private func shutterButtonPressed() {
        UIView.animate(withDuration: 0.1) {
            self.shutterButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
    }
    
    @objc private func shutterButtonReleased() {
        UIView.animate(withDuration: 0.1) {
            self.shutterButton.transform = .identity
        }
    }
    
    @objc private func shutterTapped() {
        print("Shutter button tapped")
        
        // Check if photo output is available
        guard let photoOutput = photoOutput else {
            print("Photo output is nil")
            return
        }
        
        // Check if capture session is running
        guard let captureSession = captureSession, captureSession.isRunning else {
            print("Capture session is not running")
            return
        }
        
        // Disable the shutter button temporarily
        shutterButton.isEnabled = false
        
        // Provide haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.impactOccurred()
        
        // Create photo settings for full resolution capture
        var settings = AVCapturePhotoSettings()
        
        // Configure flash
        if isFlashOn && photoOutput.supportedFlashModes.contains(.on) {
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }
        
        // Ensure we capture at full resolution
        if let firstFormat = photoOutput.availablePhotoCodecTypes.first {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: firstFormat])
            
            // Re-apply flash setting
            if isFlashOn && photoOutput.supportedFlashModes.contains(.on) {
                settings.flashMode = .on
            } else {
                settings.flashMode = .off
            }
        }
        
        // Enable high resolution photo capture if available
        settings.isHighResolutionPhotoEnabled = photoOutput.isHighResolutionCaptureEnabled
        
        print("Capturing photo with settings: \(settings)")
        print("High resolution enabled: \(settings.isHighResolutionPhotoEnabled)")
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func cancelTapped() {
        delegate?.didCancelCapture()
    }
    
    @objc private func flashTapped() {
        isFlashOn.toggle()
        updateFlashButtonAppearance()
        
        // Provide haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
    }
}

extension AlbumCoverCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("Photo capture completed")
        
        // Re-enable the shutter button
        DispatchQueue.main.async { [weak self] in
            self?.shutterButton.isEnabled = true
        }
        
        guard error == nil else {
            print("Error capturing photo: \(error!.localizedDescription)")
            return
        }
        
        guard let data = photo.fileDataRepresentation() else {
            print("Unable to get photo data representation")
            return
        }
        
        guard let image = UIImage(data: data) else {
            print("Unable to create UIImage from photo data")
            return
        }
        
        print("Photo captured successfully, size: \(image.size)")
        
        // Pass the raw image to the delegate for cropping in the next step
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.didCaptureRawImage(image, from: self)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        print("Photo capture initiated")
        if let error = error {
            print("Photo capture error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Photo Crop View Controller

class PhotoCropViewController: UIViewController {
    weak var delegate: PhotoCropDelegate?
    var originalImage: UIImage?
    
    private var imageView: UIImageView!
    private var cropOverlay: CropOverlayView!
    private var scrollView: UIScrollView!
    private var cropButton: UIButton!
    private var cancelButton: UIButton!
    private var resetButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("PhotoCropViewController viewDidLoad")
        setupNavigationBar()
        setupUI()
        setupButtons()
        setupConstraints()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("PhotoCropViewController viewDidAppear")
        setupImage()
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.isHidden = true
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        print("PhotoCropViewController setupUI called")
        
        // Scroll view for zoom and pan
        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 3.0
        scrollView.zoomScale = 1.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Image view
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        
        // Crop overlay
        cropOverlay = CropOverlayView()
        cropOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cropOverlay)
    }
    
    private func setupButtons() {
        // Cancel button
        cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        cancelButton.layer.cornerRadius = 8
        cancelButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        // Reset button
        resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        resetButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        resetButton.layer.cornerRadius = 8
        resetButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        
        // Crop button
        cropButton = UIButton(type: .system)
        cropButton.setTitle("Use Photo", for: .normal)
        cropButton.setTitleColor(.black, for: .normal)
        cropButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        cropButton.backgroundColor = .white
        cropButton.layer.cornerRadius = 25
        cropButton.addTarget(self, action: #selector(cropTapped), for: .touchUpInside)
        
        [cancelButton, resetButton, cropButton].forEach {
            $0?.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0!)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Crop overlay
            cropOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            cropOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cropOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cropOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Cancel button
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Reset button
            resetButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            resetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Crop button
            cropButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            cropButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cropButton.widthAnchor.constraint(equalToConstant: 120),
            cropButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupImage() {
        guard let image = originalImage else { 
            print("PhotoCropViewController: No original image available")
            return 
        }
        
        print("PhotoCropViewController: Setting up image with size: \(image.size)")
        imageView.image = image
        
        // Set initial size to fit the image properly without cropping
        let viewSize = view.bounds.size
        let imageSize = image.size
        
        print("PhotoCropViewController: View size: \(viewSize), Image size: \(imageSize)")
        
        // Calculate scale to fit the entire image in the view (aspect fit)
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)
        
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        print("PhotoCropViewController: Scale: \(scale), Scaled dimensions: \(scaledWidth) x \(scaledHeight)")
        
        // Center the image in the scroll view
        let x = (viewSize.width - scaledWidth) / 2
        let y = (viewSize.height - scaledHeight) / 2
        
        let imageFrame = CGRect(
            x: 0,  // Position at origin in scroll view
            y: 0,
            width: scaledWidth,
            height: scaledHeight
        )
        
        print("PhotoCropViewController: Setting image frame to: \(imageFrame)")
        
        imageView.frame = imageFrame
        
        // Set scroll view content size to match the image size
        scrollView.contentSize = CGSize(width: scaledWidth, height: scaledHeight)
        
        // Center the content in the scroll view if smaller than view
        let offsetX = max(0, (viewSize.width - scaledWidth) / 2)
        let offsetY = max(0, (viewSize.height - scaledHeight) / 2)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        
        scrollView.zoomScale = 1.0
        
        print("PhotoCropViewController: Content size: \(scrollView.contentSize)")
        print("PhotoCropViewController: Content inset: \(scrollView.contentInset)")
        
        // Force layout and redraw
        view.setNeedsLayout()
        view.layoutIfNeeded()
        cropOverlay.setNeedsDisplay()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if imageView.image != nil && imageView.frame == .zero {
            setupImage()
        }
        
        // Update crop overlay after layout
        DispatchQueue.main.async { [weak self] in
            self?.cropOverlay.setNeedsDisplay()
        }
    }
    
    @objc private func cancelTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func resetTapped() {
        print("PhotoCropViewController: Reset tapped")
        
        // Reset scroll view
        scrollView.setZoomScale(1.0, animated: true)
        scrollView.setContentOffset(CGPoint.zero, animated: true)
        
        // Reset crop overlay
        cropOverlay.resetCrop()
        
        // Optionally re-setup the image to ensure proper positioning
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.setupImage()
        }
    }
    
    @objc private func cropTapped() {
        guard let image = originalImage else { return }
        let croppedImage = cropImage(image)
        delegate?.didFinalizeCroppedImage(croppedImage)
    }
    
    private func cropImage(_ image: UIImage) -> UIImage {
        print("=== CROP IMAGE DEBUG ===")
        
        let cropRect = cropOverlay.getCropRect(for: imageView, in: scrollView)
        
        // Get the actual image size vs displayed size ratio
        let imageSize = image.size
        let displayedSize = imageView.frame.size
        
        print("Original image size: \(imageSize)")
        print("Displayed image size: \(displayedSize)")
        print("Crop rect in view coordinates: \(cropRect)")
        print("Image view frame: \(imageView.frame)")
        print("Scroll view content size: \(scrollView.contentSize)")
        print("Scroll view zoom scale: \(scrollView.zoomScale)")
        
        // Calculate the scale between original image and displayed image
        let scaleX = imageSize.width / displayedSize.width
        let scaleY = imageSize.height / displayedSize.height
        
        print("Scale X: \(scaleX), Scale Y: \(scaleY)")
        
        // Convert crop rect to actual image coordinates
        // Ensure we don't go outside image bounds
        let actualCropRect = CGRect(
            x: max(0, min(cropRect.origin.x * scaleX, imageSize.width - 1)),
            y: max(0, min(cropRect.origin.y * scaleY, imageSize.height - 1)),
            width: min(cropRect.size.width * scaleX, imageSize.width - cropRect.origin.x * scaleX),
            height: min(cropRect.size.height * scaleY, imageSize.height - cropRect.origin.y * scaleY)
        )
        
        print("Actual crop rect: \(actualCropRect)")
        print("========================")
        
        guard actualCropRect.width > 0 && actualCropRect.height > 0,
              let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: actualCropRect) else {
            print("Failed to crop image - using original")
            return image
        }
        
        let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        print("Cropped image size: \(croppedImage.size)")
        
        return croppedImage
    }
}

extension PhotoCropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Center the image view in the scroll view when zooming
        let boundsSize = scrollView.bounds.size
        var frameToCenter = imageView.frame
        
        // Horizontally
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }
        
        // Vertically
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }
        
        imageView.frame = frameToCenter
    }
}

// MARK: - Crop Overlay View

class CropOverlayView: UIView {
    private var cropRect = CGRect(x: 50, y: 200, width: 250, height: 250)
    private var isDragging = false
    private var isResizing = false
    private var dragOffset = CGPoint.zero
    private var resizeCorner: CornerType = .none
    
    private enum CornerType {
        case none, topLeft, topRight, bottomLeft, bottomRight, left, right, top, bottom
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // Draw semi-transparent overlay
        UIColor.black.withAlphaComponent(0.6).setFill()
        UIRectFill(rect)
        
        // Clear the crop area
        UIColor.clear.setFill()
        UIRectFill(cropRect)
        
        // Draw crop border
        let borderPath = UIBezierPath(rect: cropRect)
        borderPath.lineWidth = 2
        UIColor.white.setStroke()
        borderPath.stroke()
        
        // Draw corner handles
        drawCornerHandles()
        
        // Draw grid lines
        drawGridLines()
    }
    
    private func drawCornerHandles() {
        let handleSize: CGFloat = 20
        let handleColor = UIColor.white
        
        let corners = [
            CGPoint(x: cropRect.minX - handleSize/2, y: cropRect.minY - handleSize/2),
            CGPoint(x: cropRect.maxX - handleSize/2, y: cropRect.minY - handleSize/2),
            CGPoint(x: cropRect.minX - handleSize/2, y: cropRect.maxY - handleSize/2),
            CGPoint(x: cropRect.maxX - handleSize/2, y: cropRect.maxY - handleSize/2)
        ]
        
        for corner in corners {
            let handleRect = CGRect(x: corner.x, y: corner.y, width: handleSize, height: handleSize)
            let handlePath = UIBezierPath(rect: handleRect)
            handleColor.setFill()
            handlePath.fill()
        }
    }
    
    private func drawGridLines() {
        let gridPath = UIBezierPath()
        gridPath.lineWidth = 1
        
        // Vertical lines
        let verticalSpacing = cropRect.width / 3
        for i in 1...2 {
            let x = cropRect.minX + CGFloat(i) * verticalSpacing
            gridPath.move(to: CGPoint(x: x, y: cropRect.minY))
            gridPath.addLine(to: CGPoint(x: x, y: cropRect.maxY))
        }
        
        // Horizontal lines
        let horizontalSpacing = cropRect.height / 3
        for i in 1...2 {
            let y = cropRect.minY + CGFloat(i) * horizontalSpacing
            gridPath.move(to: CGPoint(x: cropRect.minX, y: y))
            gridPath.addLine(to: CGPoint(x: cropRect.maxX, y: y))
        }
        
        UIColor.white.withAlphaComponent(0.5).setStroke()
        gridPath.stroke()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .began:
            resizeCorner = getCornerType(at: location)
            if resizeCorner != .none {
                isResizing = true
            } else if cropRect.contains(location) {
                isDragging = true
                dragOffset = CGPoint(x: location.x - cropRect.midX, y: location.y - cropRect.midY)
            }
            
        case .changed:
            if isResizing {
                resizeCropRect(corner: resizeCorner, translation: translation)
            } else if isDragging {
                moveCropRect(to: CGPoint(x: location.x - dragOffset.x, y: location.y - dragOffset.y))
            }
            gesture.setTranslation(.zero, in: self)
            
        case .ended, .cancelled:
            isDragging = false
            isResizing = false
            resizeCorner = .none
            
        default:
            break
        }
    }
    
    private func getCornerType(at point: CGPoint) -> CornerType {
        let handleSize: CGFloat = 30
        
        // Check corners first
        if CGRect(x: cropRect.minX - handleSize/2, y: cropRect.minY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .topLeft
        }
        if CGRect(x: cropRect.maxX - handleSize/2, y: cropRect.minY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .topRight
        }
        if CGRect(x: cropRect.minX - handleSize/2, y: cropRect.maxY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .bottomLeft
        }
        if CGRect(x: cropRect.maxX - handleSize/2, y: cropRect.maxY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .bottomRight
        }
        
        // Check edges
        let edgeThickness: CGFloat = 20
        if abs(point.x - cropRect.minX) < edgeThickness && point.y >= cropRect.minY && point.y <= cropRect.maxY {
            return .left
        }
        if abs(point.x - cropRect.maxX) < edgeThickness && point.y >= cropRect.minY && point.y <= cropRect.maxY {
            return .right
        }
        if abs(point.y - cropRect.minY) < edgeThickness && point.x >= cropRect.minX && point.x <= cropRect.maxX {
            return .top
        }
        if abs(point.y - cropRect.maxY) < edgeThickness && point.x >= cropRect.minX && point.x <= cropRect.maxX {
            return .bottom
        }
        
        return .none
    }
    
    private func resizeCropRect(corner: CornerType, translation: CGPoint) {
        let minSize: CGFloat = 100
        var newRect = cropRect
        
        switch corner {
        case .topLeft:
            newRect.origin.x += translation.x
            newRect.origin.y += translation.y
            newRect.size.width -= translation.x
            newRect.size.height -= translation.y
            
        case .topRight:
            newRect.origin.y += translation.y
            newRect.size.width += translation.x
            newRect.size.height -= translation.y
            
        case .bottomLeft:
            newRect.origin.x += translation.x
            newRect.size.width -= translation.x
            newRect.size.height += translation.y
            
        case .bottomRight:
            newRect.size.width += translation.x
            newRect.size.height += translation.y
            
        case .left:
            newRect.origin.x += translation.x
            newRect.size.width -= translation.x
            
        case .right:
            newRect.size.width += translation.x
            
        case .top:
            newRect.origin.y += translation.y
            newRect.size.height -= translation.y
            
        case .bottom:
            newRect.size.height += translation.y
            
        case .none:
            return
        }
        
        // Ensure minimum size
        if newRect.width >= minSize && newRect.height >= minSize {
            // Keep within bounds
            newRect.origin.x = max(0, min(newRect.origin.x, bounds.width - newRect.width))
            newRect.origin.y = max(0, min(newRect.origin.y, bounds.height - newRect.height))
            
            cropRect = newRect
            setNeedsDisplay()
        }
    }
    
    private func moveCropRect(to center: CGPoint) {
        let halfWidth = cropRect.width / 2
        let halfHeight = cropRect.height / 2
        
        let newX = max(halfWidth, min(center.x, bounds.width - halfWidth))
        let newY = max(halfHeight, min(center.y, bounds.height - halfHeight))
        
        cropRect = CGRect(
            x: newX - halfWidth,
            y: newY - halfHeight,
            width: cropRect.width,
            height: cropRect.height
        )
        
        setNeedsDisplay()
    }
    
    func resetCrop() {
        let margin: CGFloat = 50
        let size = min(bounds.width - margin * 2, bounds.height - margin * 2)
        cropRect = CGRect(
            x: (bounds.width - size) / 2,
            y: (bounds.height - size) / 2,
            width: size,
            height: size
        )
        setNeedsDisplay()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Initialize crop rect if it's still at default
        if cropRect == CGRect(x: 50, y: 200, width: 250, height: 250) {
            resetCrop()
        }
    }
    
    func getCropRect(for imageView: UIImageView, in scrollView: UIScrollView) -> CGRect {
        print("CropOverlay: Getting crop rect")
        print("CropOverlay: Overlay crop rect: \(cropRect)")
        print("CropOverlay: Image view frame: \(imageView.frame)")
        print("CropOverlay: Scroll view content offset: \(scrollView.contentOffset)")
        print("CropOverlay: Scroll view zoom scale: \(scrollView.zoomScale)")
        
        // Get the current zoom scale and content offset
        let zoomScale = scrollView.zoomScale
        let contentOffset = scrollView.contentOffset
        let contentInset = scrollView.contentInset
        
        // Adjust for content inset
        let adjustedOffset = CGPoint(
            x: contentOffset.x + contentInset.left,
            y: contentOffset.y + contentInset.top
        )
        
        // Convert crop rect from overlay coordinates to scroll view content coordinates
        let cropRectInScrollView = CGRect(
            x: (cropRect.origin.x + adjustedOffset.x) / zoomScale,
            y: (cropRect.origin.y + adjustedOffset.y) / zoomScale,
            width: cropRect.width / zoomScale,
            height: cropRect.height / zoomScale
        )
        
        // Now convert to image view coordinates relative to the image's frame
        let imageViewFrame = imageView.frame
        let cropRectInImageView = CGRect(
            x: cropRectInScrollView.origin.x - imageViewFrame.origin.x / zoomScale,
            y: cropRectInScrollView.origin.y - imageViewFrame.origin.y / zoomScale,
            width: cropRectInScrollView.width,
            height: cropRectInScrollView.height
        )
        
        print("CropOverlay: Final crop rect in image coordinates: \(cropRectInImageView)")
        
        return cropRectInImageView
    }
}
