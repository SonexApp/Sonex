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
    private var isWritingMode = false
    private var pendingWriteTagHash: String?
    private var pendingURLToWrite: String?
    private var writeCompletion: ((Result<Void, Error>) -> Void)?
    
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
        
        // Get specific device info
        let deviceName = UIDevice.current.name
        info += "• Device Name: \(deviceName)\n"
        
        // Check iOS version compatibility
        if #available(iOS 11.0, *) {
            info += "• iOS 11+ Support: ✅\n"
        } else {
            info += "• iOS 11+ Support: ❌ (iOS 11+ required for NFC)\n"
        }
        
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
            info += "  - NFC may be disabled in device settings\n"
        } else {
            info += "\n✅ NFC appears to be available\n"
            info += "\n🔧 Troubleshooting Tips:\n"
            info += "  - Hold iPhone close to tag (within 1-2 inches)\n"
            info += "  - Make sure NFC tag is NDEF compatible\n"
            info += "  - Try different NFC tags if available\n"
            info += "  - Ensure tag is not damaged or corrupted\n"
            info += "  - Check if tag is locked or read-only\n"
            info += "  - Verify tag has sufficient power/antenna\n"
            info += "  - Try repositioning the tag during scan\n"
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
        performInitialDiagnostics()
    }
    
    private func performInitialDiagnostics() {
        print("🔍 NFCManager: Performing initial diagnostics...")
        print(getAvailabilityInfo())
        
        // Additional runtime checks
        if NFCNDEFReaderSession.readingAvailable {
            print("✅ NFC is available - ready for scanning")
        } else {
            print("❌ NFC is not available")
        }
    }
    
    // Method to test NFC session creation without actually starting
    func testNFCSessionCreation() -> Bool {
        guard NFCNDEFReaderSession.readingAvailable else {
            print("❌ Cannot create NFC session - NFC not available")
            return false
        }
        
        do {
            let testSession = NFCNDEFReaderSession(
                delegate: self,
                queue: DispatchQueue.global(qos: .userInitiated),
                invalidateAfterFirstRead: true
            )
            testSession.alertMessage = "Test session"
            print("✅ NFC session creation test successful")
            return true
        } catch {
            print("❌ NFC session creation failed: \(error)")
            return false
        }
    }
    
    
    func startScanning() {
        print("🔍 NFCManager: Starting scan...")
        
        guard NFCNDEFReaderSession.readingAvailable else {
            print("❌ NFC not available")
            lastError = NFCError.unavailable.localizedDescription
            return
        }
        
        guard !isScanning else { 
            print("⚠️ Already scanning, ignoring request")
            return 
        }
        
        print("✅ NFC available, initializing session...")
        
        lastError = nil
        scannedTagHash = nil
        isScanning = true
        
        // Create session with proper configuration
        session = NFCNDEFReaderSession(
            delegate: self,
            queue: DispatchQueue.global(qos: .userInitiated), // Use background queue
            invalidateAfterFirstRead: false  // Set to false to handle blank tags properly
        )
        
        session?.alertMessage = "Hold your iPhone near an NFC tag to scan it."
        
        print("📱 Starting NFC session...")
        session?.begin()
        
        // Add timeout monitoring
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if self.isScanning {
                print("⏰ NFC scan timeout after 30 seconds")
                self.stopScanning()
                self.lastError = NFCError.sessionTimeout.localizedDescription
            }
        }
    }
    
    func stopScanning() {
        print("🛑 NFCManager: Stopping scan...")
        session?.invalidate()
        isScanning = false
        isWritingMode = false
        pendingWriteTagHash = nil
        pendingURLToWrite = nil
        writeCompletion = nil
        print("✅ NFCManager: Scan stopped")
    }
    
    /// Writes a Sonex URL to an NFC tag
    func writeURL(_ url: String, to tagHash: String) async throws {
        guard isAvailable else {
            throw NFCError.unavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            print("📝 NFCManager: Starting URL write for tag \(tagHash)")
            
            // Store the write parameters
            pendingURLToWrite = url
            pendingWriteTagHash = tagHash
            writeCompletion = { result in
                continuation.resume(with: result)
            }
            
            // Start the writing session
            startWritingSession()
        }
    }
    
    private func startWritingSession() {
        print("📝 Starting NFC writing session...")
        
        lastError = nil
        scannedTagHash = nil
        isScanning = true
        isWritingMode = true
        
        // Create session for writing
        session = NFCNDEFReaderSession(
            delegate: self,
            queue: DispatchQueue.global(qos: .userInitiated),
            invalidateAfterFirstRead: false
        )
        
        session?.alertMessage = "Hold your iPhone near the NFC tag to write the Sonex URL."
        session?.begin()
        
        print("📱 NFC writing session started...")
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
    
    private func generateFallbackTagHash() -> String {
        // Generate a hash for tags without NDEF data
        let timestamp = Date().timeIntervalSince1970
        let randomComponent = Int.random(in: 1000...9999)
        return "sonex_spinTag_\(Int(timestamp))_\(randomComponent)"
    }
    
    // MARK: - Writing Functions
    
    /// Writes a Sonex tag with the provided hash and write-locks it
    func writeSonexTag(tagHash: String) {
        print("🔄 NFCManager: Starting Sonex tag write with hash: \(tagHash)")
        
        guard NFCNDEFReaderSession.readingAvailable else {
            print("❌ NFC not available for writing")
            lastError = NFCError.unavailable.localizedDescription
            return
        }
        
        guard !isScanning else {
            print("⚠️ Already scanning, ignoring write request")
            return
        }
        
        print("✅ NFC available, initializing write session...")
        
        lastError = nil
        isScanning = true
        
        // Create session for writing
        session = NFCNDEFReaderSession(
            delegate: self,
            queue: DispatchQueue.global(qos: .userInitiated),
            invalidateAfterFirstRead: false
        )
        
        session?.alertMessage = "Hold your iPhone near an NFC tag to write Sonex data."
        
        // Store the tag hash for writing
        self.pendingWriteTagHash = tagHash
        self.isWritingMode = true
        
        print("📱 Starting NFC write session...")
        session?.begin()
        
        // Add timeout monitoring
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if self.isScanning {
                print("⏰ NFC write timeout after 30 seconds")
                self.stopScanning()
                self.lastError = NFCError.sessionTimeout.localizedDescription
            }
        }
    }
    
    private func createSonexNDEFMessage(tagHash: String) -> NFCNDEFMessage {
        // Create a text record with the Sonex tag hash
        let sonexPayload = "sonex://tag/\(tagHash)".data(using: .utf8) ?? Data()
        
        // Create NDEF record with Sonex URI scheme
        let uriRecord = NFCNDEFPayload(
            format: .absoluteURI,
            type: "U".data(using: .utf8) ?? Data(),
            identifier: Data(),
            payload: sonexPayload
        )
        
        // Create additional text record for identification
        let textPayload = "\u{02}enSonex Spin Tag: \(tagHash)".data(using: .utf8) ?? Data()
        let textRecord = NFCNDEFPayload(
            format: .nfcWellKnown,
            type: "T".data(using: .utf8) ?? Data(),
            identifier: Data(),
            payload: textPayload
        )
        
        return NFCNDEFMessage(records: [uriRecord, textRecord])
    }
    
    private func writeNDEFAndLockTag(_ tag: NFCNDEFTag, message: NFCNDEFMessage, session: NFCNDEFReaderSession) {
        print("📝 Writing NDEF message to tag...")
        
        tag.writeNDEF(message) { error in
            if let error = error {
                print("❌ Failed to write NDEF message: \(error)")
                DispatchQueue.main.async {
                    self.lastError = "Failed to write tag: \(error.localizedDescription)"
                    self.isScanning = false
                    self.isWritingMode = false
                }
                session.invalidate(errorMessage: "Write failed")
                return
            }
            
            print("✅ NDEF message written successfully")
            session.alertMessage = "Data written, now locking tag..."
            
            // Now write-lock the tag
            self.lockTag(tag, session: session)
        }
    }
    
    private func lockTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        print("🔒 Write-locking the tag...")
        
        tag.writeLock { error in
            if let error = error {
                print("❌ Failed to lock tag: \(error)")
                DispatchQueue.main.async {
                    self.lastError = "Failed to lock tag: \(error.localizedDescription)"
                    self.isScanning = false
                    self.isWritingMode = false
                }
                session.invalidate(errorMessage: "Lock failed")
                return
            }
            
            print("🔒✅ Tag write-locked successfully")
            
            DispatchQueue.main.async {
                self.scannedTagHash = self.pendingWriteTagHash
                self.isScanning = false
                self.isWritingMode = false
                self.pendingWriteTagHash = nil
                self.lastError = nil
            }
            
            session.alertMessage = "Sonex tag created and locked successfully!"
            session.invalidate()
        }
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("📡 NFC Session invalidated with error: \(error)")
        
        DispatchQueue.main.async {
            self.isScanning = false
            
            if let nfcError = error as? NFCReaderError {
                print("🔍 NFC Error Code: \(nfcError.code.rawValue)")
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    print("👤 User cancelled scan")
                    self.lastError = NFCError.scanCancelled.localizedDescription
                case .readerSessionInvalidationErrorSessionTimeout:
                    print("⏰ Session timed out")
                    self.lastError = NFCError.sessionTimeout.localizedDescription
                case .readerSessionInvalidationErrorSystemIsBusy:
                    print("⚠️ System is busy")
                    self.lastError = "NFC system is busy, please try again"
                case .readerSessionInvalidationErrorFirstNDEFTagRead:
                    print("✅ First NDEF tag read (success)")
                    // This is actually success, don't treat as error
                    return
                default:
                    print("❌ Other NFC error: \(nfcError.localizedDescription)")
                    self.lastError = error.localizedDescription
                }
            } else {
                print("❌ Non-NFC error: \(error.localizedDescription)")
                self.lastError = error.localizedDescription
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        print("🎯 NFC Tag detected! Messages count: \(messages.count)")
        
        guard let message = messages.first else {
            print("❌ No valid message found in detected tags")
            DispatchQueue.main.async {
                self.lastError = NFCError.invalidData.localizedDescription
                self.isScanning = false
            }
            session.invalidate(errorMessage: "Invalid tag data")
            return
        }
        
        print("📄 Processing message with \(message.records.count) records")
        
        // Log each record for debugging
        for (index, record) in message.records.enumerated() {
            print("  Record \(index):")
            print("    Type: \(record.type)")
            print("    Type Name Format: \(record.typeNameFormat.rawValue)")
            print("    Identifier: \(record.identifier)")
            print("    Payload length: \(record.payload.count) bytes")
        }
        
        let tagHash = generateTagHash(from: message)
        print("🔑 Generated tag hash: \(tagHash)")
        
        DispatchQueue.main.async {
            self.scannedTagHash = tagHash
            self.isScanning = false
            self.lastError = nil
            print("✅ Tag detection completed successfully")
        }
        
        session.alertMessage = "Tag detected successfully!"
        // Note: For didDetectNDEFs, session auto-invalidates if invalidateAfterFirstRead is true
    }
    
    // Additional delegate method for detecting tags without NDEF data
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        print("🏷️ NFC Tags detected: \(tags.count)")
        
        guard let tag = tags.first else { 
            session.invalidate(errorMessage: "No valid tag found")
            return 
        }
        
        // Connect to tag and try to read
        session.connect(to: tag) { (error) in
            if let error = error {
                print("❌ Failed to connect to tag: \(error)")
                session.alertMessage = "Failed to connect to tag"
                session.invalidate(errorMessage: "Connection failed")
                return
            }
            
            print("🔗 Connected to NFC tag")
            
            // Check if we're in writing mode
            if self.isWritingMode {
                self.handleWriteMode(tag: tag, session: session)
                return
            }
            
            // Query NDEF status for reading
            tag.queryNDEFStatus { (ndefStatus, capacity, error) in
                if let error = error {
                    print("❌ NDEF query error: \(error)")
                    session.alertMessage = "Failed to read tag"
                    session.invalidate(errorMessage: "Tag read failed")
                    return
                }
                
                print("📊 NDEF Status: \(ndefStatus.rawValue), Capacity: \(capacity)")
                
                switch ndefStatus {
                case .notSupported:
                    print("⚠️ Tag does not support NDEF")
                    session.alertMessage = "Tag type not supported"
                    session.invalidate(errorMessage: "Unsupported tag type")
                case .readOnly, .readWrite:
                    // Try to read NDEF message
                    tag.readNDEF { (message, error) in
                        if let error = error {
                            print("❌ NDEF read error: \(error)")
                            // Generate hash from tag availability even if no NDEF data
                            let tagHash = self.generateFallbackTagHash()
                            DispatchQueue.main.async {
                                self.scannedTagHash = tagHash
                                self.isScanning = false
                                self.lastError = nil
                            }
                            session.alertMessage = "Blank tag detected"
                            session.invalidate() // FIXED: Properly dismiss session
                            return
                        }
                        
                        if let message = message {
                            print("📖 Successfully read NDEF message")
                            let tagHash = self.generateTagHash(from: message)
                            DispatchQueue.main.async {
                                self.scannedTagHash = tagHash
                                self.isScanning = false
                                self.lastError = nil
                            }
                            session.alertMessage = "Tag read successfully!"
                            session.invalidate() // FIXED: Properly dismiss session
                        } else {
                            print("📝 Empty NDEF message")
                            let tagHash = self.generateFallbackTagHash()
                            DispatchQueue.main.async {
                                self.scannedTagHash = tagHash
                                self.isScanning = false
                                self.lastError = nil
                            }
                            session.alertMessage = "Empty tag detected"
                            session.invalidate() // FIXED: Properly dismiss session
                        }
                    }
                default:
                    print("⚠️ Unknown NDEF status: \(ndefStatus)")
                    session.invalidate(errorMessage: "Unknown tag status")
                }
            }
        }
    }
    
    private func handleWriteMode(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        guard let urlToWrite = pendingURLToWrite else {
            print("❌ No pending URL to write")
            session.invalidate(errorMessage: "Write configuration error")
            DispatchQueue.main.async {
                self.writeCompletion?(.failure(NFCError.invalidData))
                self.isWritingMode = false
                self.isScanning = false
            }
            return
        }
        
        // Query NDEF status before writing
        tag.queryNDEFStatus { (ndefStatus, capacity, error) in
            if let error = error {
                print("❌ NDEF query error during write: \(error)")
                DispatchQueue.main.async {
                    self.lastError = "Failed to query tag: \(error.localizedDescription)"
                    self.isScanning = false
                    self.isWritingMode = false
                }
                session.invalidate(errorMessage: "Tag query failed")
                return
            }
            
            print("📊 Write Mode - NDEF Status: \(ndefStatus.rawValue), Capacity: \(capacity)")
            
            switch ndefStatus {
            case .notSupported:
                print("❌ Tag does not support NDEF writing")
                DispatchQueue.main.async {
                    self.lastError = "Tag does not support NDEF"
                    self.writeCompletion?(.failure(NFCError.unavailable))
                    self.isScanning = false
                    self.isWritingMode = false
                }
                session.invalidate(errorMessage: "Tag type not supported for writing")
                
            case .readOnly:
                print("❌ Tag is read-only, cannot write")
                DispatchQueue.main.async {
                    self.lastError = "Tag is read-only"
                    self.writeCompletion?(.failure(NFCError.unavailable))
                    self.isScanning = false
                    self.isWritingMode = false
                }
                session.invalidate(errorMessage: "Tag is read-only")
                
            case .readWrite:
                print("✅ Tag is writable, proceeding with URL write")
                self.writeURLToTag(tag, url: urlToWrite, session: session)
                
            @unknown default:
                print("⚠️ Unknown NDEF status during write: \(ndefStatus)")
                DispatchQueue.main.async {
                    self.lastError = "Unknown tag status"
                    self.writeCompletion?(.failure(NFCError.unavailable))
                    self.isScanning = false
                    self.isWritingMode = false
                }
                session.invalidate(errorMessage: "Unknown tag status")
            }
        }
    }
    
    private func writeURLToTag(_ tag: NFCNDEFTag, url: String, session: NFCNDEFReaderSession) {
        // Create URL record
        guard let urlRecord = NFCNDEFPayload.wellKnownTypeURIPayload(string: url) else {
            print("❌ Failed to create URL record")
            DispatchQueue.main.async {
                self.lastError = "Failed to create URL record"
                self.writeCompletion?(.failure(NFCError.invalidData))
                self.isScanning = false
                self.isWritingMode = false
            }
            session.invalidate(errorMessage: "URL creation failed")
            return
        }
        
        // Create NDEF message with the URL record
        let message = NFCNDEFMessage(records: [urlRecord])
        
        // Write the message to the tag
        tag.writeNDEF(message) { error in
            if let error = error {
                print("❌ Failed to write URL to tag: \(error)")
                DispatchQueue.main.async {
                    self.lastError = "Write failed: \(error.localizedDescription)"
                    self.writeCompletion?(.failure(error))
                    self.isScanning = false
                    self.isWritingMode = false
                }
                session.invalidate(errorMessage: "Write failed")
                return
            }
            
            print("✅ Successfully wrote URL to NFC tag")
            DispatchQueue.main.async {
                self.writeCompletion?(.success(()))
                self.isScanning = false
                self.isWritingMode = false
                self.pendingURLToWrite = nil
                self.pendingWriteTagHash = nil
                self.writeCompletion = nil
            }
            
            session.alertMessage = "URL written successfully!"
            session.invalidate()
        }
    }
}

