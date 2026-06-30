//
//  GeminiManager.swift
//  Sonex
//
//  Created by Assistant on 4/14/26.
//

import Foundation

struct GeminiResponse: Codable {
    let candidates: [Candidate]
    
    struct Candidate: Codable {
        let content: Content
        
        struct Content: Codable {
            let parts: [Part]
            
            struct Part: Codable {
                let text: String
            }
        }
    }
}

struct GeminiSuggestion {
    let artist: String
    let album: String
    let confidence: String
}

@Observable
class GeminiManager {
    static let shared = GeminiManager()
    
    private let apiKey = APIConfiguration.geminiAPIKey
    private let model = APIConfiguration.geminiModel
    private var baseURL: String {
        return "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
    }
    
    // Rate limiting properties
    private var lastRequestTime: Date = .distantPast
    private let minimumRequestInterval: TimeInterval = 1.0 // 1 second between requests
    private var requestCount: Int = 0
    private let maxRequestsPerMinute: Int = 60
    private var requestTimes: [Date] = []
    
    private init() {
        APIConfiguration.validateConfiguration()
    }
    
    func suggestAlbumFromText(_ recognizedWords: [String]) async throws -> GeminiSuggestion? {
        guard APIConfiguration.isConfigured else {
            print("⚠️ Gemini API key not configured - skipping AI suggestion")
            return nil
        }
        
        // Check rate limits before making request
        try await enforceRateLimit()
        
        let wordsString = recognizedWords.joined(separator: ", ")
        
        let prompt = """
        I have scanned text from an album cover or vinyl record and extracted these words: \(wordsString)
        
        Based on these words, please suggest the most likely artist name and album title. You are a music expert assistant that helps identify albums and artists from text found on album covers. You should only suggest real albums and artists that exist. First identify the artist, and then infer the album from their discography by comparing words in the input list to album titles.
        
        Please respond in this exact JSON format:
        {
            "artist": "Artist Name",
            "album": "Album Title", 
            "confidence": "high/medium/low"
        }
        
        If you cannot determine an artist and album with reasonable confidence, respond with:
        {
            "artist": "",
            "album": "",
            "confidence": "low"
        }
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 200,
                "topP": 0.8,
                "topK": 10
            ]
        ]
        
        guard let url = URL(string: baseURL) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw GeminiError.invalidRequest
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.networkError
        }
        
        // Handle rate limiting with exponential backoff
        if httpResponse.statusCode == 429 {
            print("🚫 Rate limit hit, attempting retry with backoff...")
            try await handleRateLimit()
            
            // Retry the request once
            let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw GeminiError.networkError
            }
            
            guard retryHttpResponse.statusCode == 200 else {
                print("🚫 Retry failed with status: \(retryHttpResponse.statusCode)")
                if let responseBody = String(data: retryData, encoding: .utf8) {
                    print("Response body: \(responseBody)")
                }
                throw GeminiError.apiError(retryHttpResponse.statusCode)
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: retryData)
            guard let content = geminiResponse.candidates.first?.content.parts.first?.text else {
                throw GeminiError.noResponse
            }
            return try parseAISuggestion(from: content)
        }
        
        guard httpResponse.statusCode == 200 else {
            print("🚫 API error with status: \(httpResponse.statusCode)")
            
            // For debugging, print response body
            if let responseBody = String(data: data, encoding: .utf8) {
                print("Response body: \(responseBody)")
            }
            
            throw GeminiError.apiError(httpResponse.statusCode)
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let content = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.noResponse
        }
        
        // Parse the JSON response
        return try parseAISuggestion(from: content)
    }
    
    private func parseAISuggestion(from jsonString: String) throws -> GeminiSuggestion? {
        // Clean up the response - sometimes Gemini includes markdown formatting
        let cleanedString = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedString.data(using: .utf8) else {
            throw GeminiError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: String]
        
        guard let artist = json?["artist"],
              let album = json?["album"],
              let confidence = json?["confidence"] else {
            throw GeminiError.invalidResponse
        }
        
        // Return nil if AI couldn't determine with confidence
        if artist.isEmpty || album.isEmpty || confidence == "low" {
            return nil
        }
        
        return GeminiSuggestion(artist: artist, album: album, confidence: confidence)
    }
    
    // MARK: - Rate Limiting
    
    private func enforceRateLimit() async throws {
        let now = Date()
        
        // Clean up old request times (remove requests older than 1 minute)
        requestTimes.removeAll { now.timeIntervalSince($0) > 60 }
        
        // Check if we've exceeded requests per minute
        if requestTimes.count >= maxRequestsPerMinute {
            let oldestRequest = requestTimes.min() ?? now
            let waitTime = 60.0 - now.timeIntervalSince(oldestRequest)
            
            if waitTime > 0 {
                print("⏱️ Rate limit: waiting \(waitTime) seconds...")
                try await Task.sleep(for: .seconds(waitTime))
            }
        }
        
        // Check minimum interval between requests
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < minimumRequestInterval {
            let waitTime = minimumRequestInterval - timeSinceLastRequest
            print("⏱️ Request throttling: waiting \(waitTime) seconds...")
            try await Task.sleep(for: .seconds(waitTime))
        }
        
        // Record this request
        lastRequestTime = Date()
        requestTimes.append(Date())
    }
    
    private func handleRateLimit() async throws {
        // Exponential backoff - wait longer on rate limit
        let backoffTime: TimeInterval = 5.0 + Double.random(in: 0...2.0) // 5-7 seconds
        print("⏱️ Rate limit backoff: waiting \(backoffTime) seconds...")
        try await Task.sleep(for: .seconds(backoffTime))
    }
}

enum GeminiError: Error, LocalizedError {
    case invalidURL
    case invalidRequest
    case networkError
    case apiError(Int)
    case noResponse
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidRequest:
            return "Invalid request format"
        case .networkError:
            return "Network connection error"
        case .apiError(let statusCode):
            return "API error with status code: \(statusCode)"
        case .noResponse:
            return "No response from AI service"
        case .invalidResponse:
            return "Invalid response format from AI service"
        }
    }
}
