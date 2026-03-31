//
//  NFCManager.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

import Foundation
import Observation

@Observable
final class NFCManager {

    var detectedTagHash: String? = nil
    var isScanning: Bool = false

    // Week 2: arm a real NFCNDEFReaderSession here
    func startSession() async {
        isScanning = true
    }

    func stopSession() {
        isScanning = false
    }

    // Called by RootView when a deep link URL carries a tag hash
    // instead of a physical NFC tap
    func resolveTagHash(_ hash: String) {
        detectedTagHash = hash
    }
}
