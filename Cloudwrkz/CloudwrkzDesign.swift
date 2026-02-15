//
//  CloudwrkzDesign.swift
//  Cloudwrkz
//
//  Liquid glass only. Enterprise-ready. No solid fills on UI chrome.
//

import SwiftUI

// MARK: - Enterprise palette (Cloudwrkz + neutrals for glass-on-dark)

enum CloudwrkzColors {
    // Primary – used sparingly for brand and CTAs
    static let primary400 = Color(red: 96/255, green: 165/255, blue: 250/255)
    static let primary500 = Color(red: 59/255, green: 130/255, blue: 246/255)
    static let primary600 = Color(red: 37/255, green: 99/255, blue: 235/255)
    static let primary700 = Color(red: 29/255, green: 78/255, blue: 216/255)
    static let primary800 = Color(red: 30/255, green: 64/255, blue: 175/255)
    static let primary900 = Color(red: 30/255, green: 58/255, blue: 138/255)
    static let primary950 = Color(red: 23/255, green: 37/255, blue: 84/255)

    // Neutrals – text and surfaces
    static let neutral100 = Color(red: 245/255, green: 245/255, blue: 244/255)
    static let neutral200 = Color(red: 231/255, green: 229/255, blue: 228/255)
    static let neutral400 = Color(red: 168/255, green: 162/255, blue: 158/255)
    static let neutral500 = Color(red: 120/255, green: 113/255, blue: 108/255)
    static let neutral600 = Color(red: 87/255, green: 83/255, blue: 78/255)
    static let neutral700 = Color(red: 68/255, green: 64/255, blue: 60/255)
    static let neutral800 = Color(red: 41/255, green: 37/255, blue: 36/255)
    static let neutral900 = Color(red: 28/255, green: 25/255, blue: 23/255)
    static let neutral950 = Color(red: 12/255, green: 10/255, blue: 9/255)

    // Semantic (health status, alerts)
    static let error50 = Color(red: 254/255, green: 242/255, blue: 242/255)
    static let error500 = Color(red: 239/255, green: 68/255, blue: 68/255)
    static let error700 = Color(red: 185/255, green: 28/255, blue: 28/255)
    static let success500 = Color(red: 34/255, green: 197/255, blue: 94/255)
    static let success400 = Color(red: 74/255, green: 222/255, blue: 128/255)
    static let warning500 = Color(red: 234/255, green: 179/255, blue: 8/255)
    static let warning400 = Color(red: 250/255, green: 204/255, blue: 21/255)
}

// MARK: - Liquid glass only (no tint; glass + highlight edge)

extension View {
    /// Pure liquid glass panel. Translucent only; optional minimal tint.
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat = 24, tint: Color? = nil, tintOpacity: Double = 0.06) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(
                    .regular.tint((tint ?? CloudwrkzColors.primary500).opacity(tintOpacity)),
                    in: RoundedRectangle(cornerRadius: cornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                )
        } else {
            self
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        }
    }

    /// Primary CTA: glass with blue tint for clear visibility on dark background.
    @ViewBuilder
    func glassButtonPrimary(cornerRadius: CGFloat = 14) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(
                    .regular.tint(CloudwrkzColors.primary500.opacity(0.6)),
                    in: RoundedRectangle(cornerRadius: cornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(0.4), lineWidth: 1)
                )
        } else {
            self
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .background(
                    CloudwrkzColors.primary600.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: cornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(0.4), lineWidth: 1)
                )
        }
    }

    /// Secondary action: glass with visible border for contrast on dark background.
    @ViewBuilder
    func glassButtonSecondary(cornerRadius: CGFloat = 14) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.clear.tint(.white.opacity(0.12)), in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(CloudwrkzColors.primary400.opacity(0.7), lineWidth: 1.5)
                )
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(CloudwrkzColors.primary400.opacity(0.7), lineWidth: 1.5)
                )
        }
    }

    /// Input field: pure glass.
    @ViewBuilder
    func glassField(cornerRadius: CGFloat = 12) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.clear.tint(.white.opacity(0.06)), in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        }
    }
}
