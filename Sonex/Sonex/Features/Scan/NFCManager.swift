import CoreNFC
import Foundation
import UIKit

// MARK: - Supporting Types

enum NFCError: Error, LocalizedError {
    case unavailable
    case invalidData
    case scanCancelled
    case sessionTimeout
    
    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "NFC is not available on this device"
        case .invalidData:
            return "Invalid NFC tag data"
        case .scanCancelled:
            return "NFC scan was cancelled"
        case .sessionTimeout:
            return "NFC scan timed out"
        }
    }
}

// MARK: - NFCManager

@Observable
class NFCManager: NSObject {
    // Public properties
    private(set) var isScanning = false
    private(set) var scannedTagHash: String?
    private(set) var lastError: String?
    
    // Private properties
    private var session: NFCReaderSession?
    
    // Computed property to check availability dynamically
    var isAvailable: Bool {
        return NFCNDEFReaderSession.readingAvailable
    }
    
    // Debug method to get detailed availability information
    func getAvailabilityInfo() -> String {
        var info = "NFC Availability Debug Info:\n"
        info += "• NFCNDEFReaderSession.readingAvailable: \(NFCNDEFReaderSession.readingAvailable)\n"
        
        #if targetEnvironment(simulator)
        info += "• Running in Simulator: true (NFC not supported)\n"
        #else
        info += "• Running in Simulator: false\n"
        #endif
        
        // Check device capabilities
        info += "• Device Model: \(UIDevice.current.model)\n"
        info += "• System Version: \(UIDevice.current.systemVersion)\n"
        
        // Check if running on physical device with NFC capability
        if !NFCNDEFReaderSession.readingAvailable {
            info += "\n⚠️ Possible Issues:\n"
            #if targetEnvironment(simulator)
            info += "  - Simulator doesn't support NFC\n"
            #endif
            info += "  - Device may not support NFC (iPhone 7+ required)\n"
            info += "  - Missing NFC entitlements in project\n"
            info += "  - Missing NFCReaderUsageDescription in Info.plist\n"
            info += "  - App not signed with proper provisioning profile\n"
        }
        
        return info
    }
    
    // Method to check if this is a simulator
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    override init() {
        super.init()
    }
    
    
    func startScanning() {
        guard NFCNDEFReaderSession.readingAvailable else {
            lastError = NFCError.unavailable.localizedDescription
            return
        }
        
        guard !isScanning else { return }
        
        lastError = nil
        scannedTagHash = nil
        isScanning = true
        
        session = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: false
        )
        
        session?.alertMessage = "Hold your iPhone near an NFC tag to scan it."
        session?.begin()
    }
    
    func stopScanning() {
        session?.invalidate()
        isScanning = false
    }
    
    private func generateTagHash(from message: NFCNDEFMessage) -> String {
        // Create a hash from the tag's data for identification
        var hashString = ""
        
        for record in message.records {
            hashString += record.type.description
            hashString += record.payload.description
        }
        
        // If no meaningful data, use a timestamp-based fallback
        if hashString.isEmpty {
            hashString = "\(Date().timeIntervalSince1970)"
        }
        
        return String(hashString.hashValue)
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
            
            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    self.lastError = NFCError.scanCancelled.localizedDescription
                case .readerSessionInvalidationErrorSessionTimeout:
                    self.lastError = NFCError.sessionTimeout.localizedDescription
                default:
                    self.lastError = error.localizedDescription
                }
            } else {
                self.lastError = error.localizedDescription
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let message = messages.first else {
            DispatchQueue.main.async {
                self.lastError = NFCError.invalidData.localizedDescription
                self.isScanning = false
            }
            return
        }
        
        let tagHash = generateTagHash(from: message)
        
        DispatchQueue.main.async {
            self.scannedTagHash = tagHash
            self.isScanning = false
            self.lastError = nil
        }
        
        session.alertMessage = "Tag detected successfully!"
    }
}

