//
//  CameraPermissionManager.swift
//  Sonex
//
//  Created by Assistant on 4/14/26.
//

import AVFoundation
import UIKit

@Observable
class CameraPermissionManager {
    static let shared = CameraPermissionManager()
    
    var permissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    
    private init() {
        permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    func requestCameraPermission() async -> Bool {
        switch permissionStatus {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                self.permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
            return granted
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    var isAuthorized: Bool {
        return permissionStatus == .authorized
    }
    
    var canRequestPermission: Bool {
        return permissionStatus == .notDetermined
    }
    
    func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            Task { @MainActor in
                if UIApplication.shared.canOpenURL(settingsURL) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        }
    }
}