//
//  Colors.swift
//  Sonex Design System
//
//  Created by Ricardo Payares on 4/29/26.
//
//  Color palette and semantic color definitions for the Sonex app
//

import SwiftUI

// MARK: - Color Palette
extension Color {
    // MARK: - Primary Colors
    /// Main brand color - Amber/Gold
    static let sonexAmber = Color(red: 0.98, green: 0.73, blue: 0.12)
    /// Darker variant of amber for pressed states
    static let sonexAmberDark = Color(red: 0.85, green: 0.62, blue: 0.10)
    /// Lighter variant of amber for highlights
    static let sonexAmberLight = Color(red: 1.0, green: 0.85, blue: 0.35)
    
    // MARK: - Background Colors
    /// Primary background - Dark charcoal
    static let sonexCharcoal = Color(red: 0.08, green: 0.08, blue: 0.10)
    /// Secondary background - Slightly lighter charcoal
    static let sonexSurface = Color(red: 0.12, green: 0.12, blue: 0.14)
    /// Elevated surface - Even lighter for cards and overlays
    static let sonexSurfaceElevated = Color(red: 0.16, green: 0.16, blue: 0.18)
    
    // MARK: - Text Colors
    /// Primary text color - High contrast white
    static let sonexTextPrimary = Color(red: 0.98, green: 0.98, blue: 1.0)
    /// Secondary text color - Medium contrast
    static let sonexTextSecondary = Color(red: 0.78, green: 0.78, blue: 0.82)
    /// Tertiary text color - Low contrast for hints
    static let sonexTextTertiary = Color(red: 0.58, green: 0.58, blue: 0.62)
    /// Text color on amber backgrounds
    static let sonexTextOnAmber = Color(red: 0.05, green: 0.05, blue: 0.07)
    
    // MARK: - Semantic Colors
    /// Success/positive actions
    static let sonexSuccess = Color(red: 0.20, green: 0.78, blue: 0.35)
    /// Error/destructive actions
    static let sonexError = Color(red: 0.96, green: 0.26, blue: 0.21)
    /// Warning/caution
    static let sonexWarning = Color(red: 1.0, green: 0.58, blue: 0.0)
    /// Information/neutral
    static let sonexInfo = Color(red: 0.20, green: 0.68, blue: 0.99)
    
    // MARK: - Glass Effect Colors
    /// Tint for glass backgrounds
    static let sonexGlassTint = Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.6)
    /// Border color for glass elements
    static let sonexGlassBorder = Color.white.opacity(0.1)
    
    // MARK: - UI Element Colors
    /// Separator lines
    static let sonexSeparator = Color(red: 0.24, green: 0.24, blue: 0.26)
    /// Input field backgrounds
    static let sonexInputBackground = Color(red: 0.18, green: 0.18, blue: 0.20)
    /// Selection/highlight
    static let sonexSelection = sonexAmber.opacity(0.2)
}

// MARK: - Color Provider Protocol
protocol ColorProviding {
    var primary: Color { get }
    var background: Color { get }
    var surface: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var success: Color { get }
    var error: Color { get }
    var warning: Color { get }
}

// MARK: - Dark Theme Implementation
struct SonexDarkTheme: ColorProviding {
    let primary: Color = .sonexAmber
    let background: Color = .sonexCharcoal
    let surface: Color = .sonexSurface
    let textPrimary: Color = .sonexTextPrimary
    let textSecondary: Color = .sonexTextSecondary
    let success: Color = .sonexSuccess
    let error: Color = .sonexError
    let warning: Color = .sonexWarning
}

// MARK: - Dynamic Color Helpers
extension Color {
    /// Creates a color that adapts to light/dark modes
    static func sonexDynamic(light: Color, dark: Color) -> Color {
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            case .light:
                return UIColor(light)
            default:
                return UIColor(dark)
            }
        })
    }
}

// MARK: - Gradient Definitions
extension LinearGradient {
    /// Primary amber gradient
    static let sonexAmberGradient = LinearGradient(
        colors: [.sonexAmber, .sonexAmberDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Background gradient for overlays
    static let sonexBackgroundGradient = LinearGradient(
        colors: [.sonexCharcoal, .sonexSurface],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Glass effect gradient
    static let sonexGlassGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.2),
            Color.white.opacity(0.1),
            Color.clear
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Color Extensions for SwiftUI
extension ShapeStyle where Self == Color {
    /// Convenient access to Sonex amber color
    static var sonexAmber: Color { Color.sonexAmber }
    /// Convenient access to Sonex primary text color
    static var sonexTextPrimary: Color { Color.sonexTextPrimary }
    /// Convenient access to Sonex surface color
    static var sonexSurface: Color { Color.sonexSurface }
}