//
//  BackgroundNFCManager.swift
//  Sonex
//
//  Created by Assistant on 4/14/26.
//

import Foundation
import CoreNFC
import UIKit
import Combine

/// Manages background NFC reading for registered tags
class BackgroundNFCManager: NSObject, ObservableObject {
    static let shared = BackgroundNFCManager()
    
    @Published var isBackgroundReadingEnabled = false
    @Published var lastBackgroundTagHash: String?
    
    private var dbManager = SonexDBManager.shared
    
    private override init() {
        super.init()
        setupBackgroundNFCReading()
    }
    
    private func setupBackgroundNFCReading() {
        // Background NFC reading is automatically enabled on devices that support it
        // when the app has the proper entitlements and Info.plist configuration
        isBackgroundReadingEnabled = NFCNDEFReaderSession.readingAvailable
        
        print("📱 Background NFC reading available: \(isBackgroundReadingEnabled)")
    }
    
    /// Called when the app launches from an NFC tag
    func handleBackgroundNFCLaunch(with url: URL) {
        print("🏷️ App launched from NFC tag with URL: \(url)")
        
        // Extract tag hash from URL if it's a Sonex URL
        if url.scheme == "sonex",
           url.host == "album",
           url.pathComponents.count == 2 {
            let tagHash = url.pathComponents[1]
            lastBackgroundTagHash = tagHash
            
            // Send notification that we received a background NFC tag
            NotificationCenter.default.post(
                name: .backgroundNFCDetected,
                object: nil,
                userInfo: ["tagHash": tagHash, "url": url]
            )
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let backgroundNFCDetected = Notification.Name("backgroundNFCDetected")
}
