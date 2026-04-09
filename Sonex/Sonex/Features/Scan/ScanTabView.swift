//
//  ScanTabView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

//
//  ScanTabView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

import SwiftUI
import SonexShared

struct ScanTabView: View {
    @State private var registrationData = VinylRegistrationData()
    @State private var nfcManager = NFCManager()
    @State private var dbManager = SonexDBManager.shared
    @State private var showingRegistrationFlow = false
    @State private var isCheckingTag = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.sonexCharcoal.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                headerSection
                
                Spacer()
                
                nfcScanningSection
                
                Spacer()
            }
            .padding()
        }
        .onChange(of: nfcManager.scannedTagHash) { tagHash in
            if let tagHash = tagHash {
                handleScannedTag(tagHash)
            }
        }
        .onAppear {
            
            // Print debug info to console
            print(nfcManager.getAvailabilityInfo())
            
            // Additional debugging
            print("📱 Device Debug:")
            print("  Model: \(UIDevice.current.model)")
            print("  System: \(UIDevice.current.systemVersion)")
            print("  Is Simulator: \(nfcManager.isSimulator)")
        }
        .sheet(isPresented: $showingRegistrationFlow) {
            registrationFlowSheet
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Ready to Scan")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text("Scan the Spin Tag you wish to set up for your media. Then walk through a quick setup to get you graded and listed!")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    @ViewBuilder
    private var nfcScanningSection: some View {
        VStack(spacing: 32) {
            nfcAnimationView
            scanButton
            statusMessagesView
        }
    }
    
    @ViewBuilder
    private var nfcAnimationView: some View {
        ZStack {
            // Outer rings - animated
            ForEach(0..<3, id: \.self) { index in
                animatedRing(for: index)
            }
            
            nfcCenterCircle
        }
    }
    
    @ViewBuilder
    private func animatedRing(for index: Int) -> some View {
        let ringSize = 200 + CGFloat(index * 40)
        let animationDelay = Double(index) * 0.3
        let baseAnimation = Animation.easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
            .delay(animationDelay)
        
        Circle()
            .strokeBorder(Color.sonexAmber.opacity(0.3), lineWidth: 2)
            .frame(width: ringSize, height: ringSize)
            .scaleEffect(nfcManager.isScanning ? 1.2 : 1.0)
            .opacity(nfcManager.isScanning ? 0.2 : 0.6)
            .animation(baseAnimation, value: nfcManager.isScanning)
    }
    
    @ViewBuilder
    private var nfcCenterCircle: some View {
        ZStack {
            Circle()
                .fill(Color.sonexAmber.opacity(0.1))
                .frame(width: 160, height: 160)
            
            Circle()
                .strokeBorder(Color.sonexAmber, lineWidth: 3)
                .frame(width: 160, height: 160)
            
            VStack(spacing: 8) {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.sonexAmber)
                
                nfcStatusText
            }
        }
    }
    
    @ViewBuilder
    private var nfcStatusText: some View {
        if isCheckingTag {
            Text("Checking Tag...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        } else if nfcManager.isScanning {
            Text("Scanning...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
    
    @ViewBuilder
    private var scanButton: some View {
        Button(action: {
            if nfcManager.isScanning {
                nfcManager.stopScanning()
            } else {
                nfcManager.startScanning()
            }
        }) {
            scanButtonContent
        }
        .disabled(isCheckingTag || !nfcManager.isAvailable)
        .padding(.horizontal, 32)
    }
    
    @ViewBuilder
    private var scanButtonContent: some View {
        HStack(spacing: 12) {
            Image(systemName: nfcManager.isScanning ? "stop.fill" : "nfc")
                .font(.title3)
            
            Text(nfcManager.isScanning ? "Cancel Scan" : "Start Scanning")
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .foregroundStyle(nfcManager.isScanning ? .white : Color.sonexCharcoal)
        .background(nfcManager.isScanning ? Color.red : Color.sonexAmber)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var statusMessagesView: some View {
        VStack(spacing: 8) {
            if let error = errorMessage ?? nfcManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            if !nfcManager.isAvailable {
                VStack(spacing: 4) {
                    if nfcManager.isSimulator {
                        Text("NFC testing requires a physical device")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("NFC is not available on this device")
                            .font(.caption)
                            .foregroundStyle(.red)
                        
                        Text("Check NFC settings and app permissions")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
                .multilineTextAlignment(.center)
            } else if nfcManager.isAvailable && !nfcManager.isScanning {
                Text("Ready to scan NFC tags")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 32)
    }
    
    @ViewBuilder
    private var registrationFlowSheet: some View {
        VinylRegistrationFlowView(
            registrationData: registrationData,
            onComplete: { vinyl in
                showingRegistrationFlow = false
                registrationData.reset()
            },
            onCancel: {
                showingRegistrationFlow = false
                registrationData.reset()
            }
        )
    }
    
    private func handleScannedTag(_ tagHash: String) {
        isCheckingTag = true
        errorMessage = nil
        
        Task {
            do {
                // Check if tag is already registered
                let existingVinyl = try await dbManager.checkNFCTagRegistration(tagHash: tagHash)
                
                await MainActor.run {
                    if existingVinyl != nil {
                        errorMessage = "This tag is already registered to a vinyl record."
                    } else {
                        // Start registration flow
                        registrationData.nfcTagHash = tagHash
                        showingRegistrationFlow = true
                    }
                    isCheckingTag = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to check tag registration: \(error.localizedDescription)"
                    isCheckingTag = false
                }
            }
        }
    }
}

struct VinylRegistrationFlowView: View {
    @Bindable var registrationData: VinylRegistrationData
    let onComplete: (VinylEntry) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                switch registrationData.currentStep {
                case .nfcScan:
                    // This shouldn't show since we start with a scanned tag
                    EmptyView()
                case .albumInfo:
                    AlbumInfoView(registrationData: registrationData)
                case .grading:
                    GradingView(registrationData: registrationData)
                case .pricing:
                    PricingView(registrationData: registrationData, onComplete: onComplete)
                case .confirmation:
                    ConfirmationView(registrationData: registrationData, onComplete: onComplete)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text(registrationData.currentStep.title)
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Start with album info since we already have the NFC tag
            registrationData.currentStep = .albumInfo
        }
    }
}

extension VinylRegistrationData.RegistrationStep {
    var title: String {
        switch self {
        case .nfcScan: return "Link Tag"
        case .albumInfo: return "Album Info"
        case .grading: return "Grading"
        case .pricing: return "Est. Value"
        case .confirmation: return "Confirmation"
        }
    }
}
