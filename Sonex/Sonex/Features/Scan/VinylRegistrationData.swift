//
//  VinylRegistrationData.swift
//  Sonex
//
//  Created by Assistant on 4/8/26.
//

import Foundation
import SonexShared

@Observable
class VinylRegistrationData {
    // NFC Data
    var nfcTagHash: String?
    
    // Album Info
    var title: String = ""
    var artist: String = ""
    var label: String = ""
    var year: Int?
    var pressing: String = ""
    var format: String = ""
    var discogsId: String?
    var coverArtUrl: String?
    
    // Grading
    var mediaGrade: VinylGrade?
    var sleeveGrade: VinylGrade?
    var gradeNotes: String = ""
    
    // Pricing
    var forSale: Bool = false
    var askingPrice: Double?
    var lastSoldPrice: Double?
    var medianPrice: Double?
    var highPrice: Double?
    var lowPrice: Double?
    
    // Current step in registration flow
    var currentStep: RegistrationStep = .nfcScan
    
    init() {
        // Explicit initializer to resolve ambiguity
    }
    
    enum RegistrationStep: CaseIterable {
        case nfcScan
        case albumInfo
        case grading
        case pricing
        case confirmation
    }
    
    func reset() {
        nfcTagHash = nil
        title = ""
        artist = ""
        label = ""
        year = nil
        pressing = ""
        format = ""
        discogsId = nil
        coverArtUrl = nil
        mediaGrade = nil
        sleeveGrade = nil
        gradeNotes = ""
        forSale = false
        askingPrice = nil
        lastSoldPrice = nil
        medianPrice = nil
        highPrice = nil
        lowPrice = nil
        currentStep = .nfcScan
    }
    
    var isValid: Bool {
        return !title.isEmpty && !artist.isEmpty && nfcTagHash != nil
    }
    
    func nextStep() {
        guard let currentIndex = RegistrationStep.allCases.firstIndex(of: currentStep),
              currentIndex < RegistrationStep.allCases.count - 1 else { return }
        currentStep = RegistrationStep.allCases[currentIndex + 1]
    }
    
    func previousStep() {
        guard let currentIndex = RegistrationStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        currentStep = RegistrationStep.allCases[currentIndex - 1]
    }
}
