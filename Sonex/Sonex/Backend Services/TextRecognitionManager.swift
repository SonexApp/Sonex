//
//  TextRecognitionManager.swift
//  Sonex
//
//  Created by Assistant on 4/14/26.
//

import UIKit
import VisionKit
import Vision

@Observable
class TextRecognitionManager: NSObject {
    static let shared = TextRecognitionManager()
    
    var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }
    
    private override init() {
        super.init()
    }
    
    func recognizeText(from image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw TextRecognitionError.invalidImage
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en"]
        
        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    
                    let observations = request.results ?? []
                    var recognizedText: [String] = []
                    
                    for observation in observations {
                        guard let topCandidate = observation.topCandidates(1).first else { continue }
                        let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Filter out very short text and common noise
                        if text.count > 1 && !text.allSatisfy({ $0.isPunctuation }) {
                            recognizedText.append(text)
                        }
                    }
                    
                    DispatchQueue.main.async {
                        continuation.resume(returning: recognizedText)
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: TextRecognitionError.recognitionFailed(error))
                    }
                }
            }
        }
    }
}

enum TextRecognitionError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed(Error)
    case notSupported
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .recognitionFailed(let error):
            return "Text recognition failed: \(error.localizedDescription)"
        case .notSupported:
            return "Text recognition not supported on this device"
        }
    }
}
