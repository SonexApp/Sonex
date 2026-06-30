//
//  APIConfiguration.swift
//  Sonex
//
//  Created by Assistant on 4/14/26.
//

import Foundation

struct APIConfiguration {
    // MARK: - Google Gemini Configuration
    
    /// Replace this with your actual Google Gemini API key
    /// Get your API key from: https://makersuite.google.com/app/apikey
    static let geminiAPIKey = "AIzaSyDdCMJ6XGfZ3wGhDwhUWnyvh24sX3M6WHY"
    
    /// Gemini model to use for album suggestions
    static let geminiModel = "gemini-2.5-flash-lite"
    
    // MARK: - Configuration Validation
    
    static var isConfigured: Bool {
        return !geminiAPIKey.isEmpty
    }
    
    static func validateConfiguration() {
        guard isConfigured else {
            print("⚠️ Warning: Gemini API key not configured. Please update APIConfiguration.swift with your API key.")
            return
        }
        print("✅ API Configuration validated successfully")
    }
}
