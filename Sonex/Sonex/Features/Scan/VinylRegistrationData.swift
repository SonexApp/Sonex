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
    
    // Owned vs Wishlist
    var isWishlist: Bool = false
    
    // Album Info
    var title: String = ""
    var artist: String = ""
    var label: String = ""
    var year: Int?
    var pressing: String = ""
    var format: String = ""
    var discogsId: String?
    var coverArtUrl: String?
    
    // Additional fields for enhanced entry
    var catalogNumber: String = ""
    var matrixCode: String = ""
    var barcode: String = ""
    var releaseEdition: ReleaseEdition = .standard
    var editionNotes: String = ""
    var mediaType: MediaType = .vinyl
    
    // MusicBrainz data
    var musicBrainzId: String?
    var isLimitedEdition: Bool = false
    
    // Grading
    var mediaGrade: VinylGrade?
    var sleeveGrade: VinylGrade?
    var gradeNotes: String = ""
    
    // Pricing
    var forSale: Bool = false
    var askingPrice: Double?
    var vinylSize: String?
    
    // Current step in registration flow
    var currentStep: RegistrationStep = .nfcScan
    
    // Store the registered vinyl entry
    var registeredVinyl: VinylEntry?
    
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
    
    enum MediaType: String, CaseIterable {
        case vinyl = "Vinyl"
        case cd = "CD"
        
        var displayName: String { rawValue }
    }
    
    enum ReleaseEdition: String, CaseIterable {
        case standard = "standard"
        case limitedEdition = "limited"
        case reissue = "reissue"
        
        var displayName: String { rawValue }
    }
    
    enum VinylSize : String, CaseIterable {
        case sevenInch = "7\" Single"
        case tenInch = "10\" EP"
        case twelveInch = "12\" Album"
        
        var displayName: String { rawValue }
    }
    func reset() {
        nfcTagHash = nil
        isWishlist = false
        title = ""
        artist = ""
        label = ""
        year = nil
        pressing = ""
        format = ""
        discogsId = nil
        coverArtUrl = nil
        catalogNumber = ""
        matrixCode = ""
        barcode = ""
        releaseEdition = .standard
        editionNotes = ""
        mediaType = .vinyl
        musicBrainzId = nil
        isLimitedEdition = false
        mediaGrade = nil
        sleeveGrade = nil
        gradeNotes = ""
        forSale = false
        askingPrice = nil
        currentStep = .nfcScan
        registeredVinyl = nil
    }
    
    var isValid: Bool {
        return !title.isEmpty && !artist.isEmpty && nfcTagHash != nil
    }
    
    func nextStep() {
        print("📄 nextStep() called - current step: \(currentStep)")
        guard let currentIndex = RegistrationStep.allCases.firstIndex(of: currentStep),
              currentIndex < RegistrationStep.allCases.count - 1 else { 
            print("📄 nextStep() - at last step or invalid index")
            return 
        }
        
        var nextStepIndex = currentIndex + 1
        let nextStep = RegistrationStep.allCases[nextStepIndex]
        
        // Skip grading step if this is a wishlist item
        if nextStep == .grading && isWishlist {
            print("📄 nextStep() - skipping grading step for wishlist item")
            // Clear any existing grading data for wishlist items
            mediaGrade = nil
            sleeveGrade = nil
            gradeNotes = ""
            
            // Move to the step after grading if possible
            nextStepIndex = min(nextStepIndex + 1, RegistrationStep.allCases.count - 1)
        }
        
        let finalNextStep = RegistrationStep.allCases[nextStepIndex]
        print("📄 nextStep() - moving from \(currentStep) to \(finalNextStep)")
        currentStep = finalNextStep
        print("📄 nextStep() - current step is now: \(currentStep)")
    }
    
    func previousStep() {
        print("📄 previousStep() called - current step: \(currentStep)")
        guard let currentIndex = RegistrationStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { 
            print("📄 previousStep() - at first step or invalid index")
            return 
        }
        
        var previousStepIndex = currentIndex - 1
        let previousStep = RegistrationStep.allCases[previousStepIndex]
        
        // Skip grading step in reverse if this is a wishlist item
        if previousStep == .grading && isWishlist {
            print("📄 previousStep() - skipping grading step for wishlist item")
            // Move to the step before grading if possible
            previousStepIndex = max(previousStepIndex - 1, 0)
        }
        
        let finalPreviousStep = RegistrationStep.allCases[previousStepIndex]
        print("📄 previousStep() - moving from \(currentStep) to \(finalPreviousStep)")
        currentStep = finalPreviousStep
        print("📄 previousStep() - current step is now: \(currentStep)")
    }
}
