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

// MARK: - Pure SwiftUI spinner (avoids UIKit CircularUIKitProgressView / PlatformViewRepresentableAdaptor)

/// Circular loading indicator implemented in pure SwiftUI. Use instead of `ProgressView()` to avoid
/// "Unable to render flattened version of PlatformViewRepresentableAdaptor<CircularUIKitProgressView>" in Previews and elsewhere.
struct CloudwrkzSpinner: View {
    var tint: Color = CloudwrkzColors.primary400
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1)
            .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .frame(width: 20, height: 20)
            .onAppear { withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { isAnimating = true } }
    }
}

// MARK: - Favicon image (bypasses AsyncImage cache, always fetches fresh)

/// Loads a remote image with explicit `reloadIgnoringLocalCacheData` policy so favicons
/// are always fresh after edits. SwiftUI's built-in `AsyncImage` uses an opaque URL cache
/// that can return stale (or previously-404) responses even when the server file has changed.
///
/// Includes the stored Bearer token in requests so that favicons load correctly even when
/// the server sits behind a reverse proxy that requires authentication.
struct FaviconImageView: View {
    let url: URL
    var size: CGFloat = 40
    var cornerRadius: CGFloat = 10
    var fallbackIcon: String = "link"
    var fallbackColor: Color = CloudwrkzColors.primary400

    @State private var uiImage: UIImage?
    @State private var failed = false
    @State private var loadTask: Task<Void, Never>?
    @State private var debugInfo: String = ""
    @State private var showDebug = false

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    var body: some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else if failed {
                fallbackView
            } else {
                CloudwrkzSpinner(tint: fallbackColor)
                    .scaleEffect(size > 30 ? 0.8 : 0.6)
            }
        }
        .frame(width: size, height: size)
        .onTapGesture(count: 2) { showDebug.toggle() }
        .popover(isPresented: $showDebug) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Favicon Debug").font(.headline)
                Text("URL: \(url.absoluteString)")
                    .font(.system(size: 11, design: .monospaced))
                Text(debugInfo)
                    .font(.system(size: 11, design: .monospaced))
                Button("Retry") { startLoad() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding()
            .frame(minWidth: 300)
        }
        .onAppear { startLoad() }
        .onChange(of: url) { _, _ in startLoad() }
        .onDisappear { loadTask?.cancel() }
    }

    private var fallbackView: some View {
        Image(systemName: fallbackIcon)
            .font(.system(size: size * 0.45))
            .foregroundStyle(fallbackColor)
    }

    private func startLoad() {
        loadTask?.cancel()
        uiImage = nil
        failed = false
        debugInfo = "[favicon] loading \(url.absoluteString)"
        print("[FaviconImageView] startLoad url=\(url.absoluteString)")
        loadTask = Task {
            do {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
                let hasToken: Bool
                if let token = AuthTokenStorage.getToken(), !token.isEmpty {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    hasToken = true
                } else {
                    hasToken = false
                }
                print("[FaviconImageView] fetching hasToken=\(hasToken) url=\(url.absoluteString)")
                let (data, response) = try await Self.session.data(for: request)
                guard !Task.isCancelled else {
                    print("[FaviconImageView] CANCELLED url=\(url.absoluteString)")
                    return
                }
                if let http = response as? HTTPURLResponse {
                    let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? "nil"
                    let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "(binary \(data.count) bytes)"
                    print("[FaviconImageView] status=\(http.statusCode) contentType=\(contentType) bytes=\(data.count) finalURL=\(http.url?.absoluteString ?? "nil") snippet=\(snippet)")
                    debugInfo = "[favicon] \(http.statusCode) \(contentType) \(data.count)B url=\(http.url?.absoluteString ?? "?")"
                    guard (200...299).contains(http.statusCode) else {
                        failed = true
                        return
                    }
                } else {
                    print("[FaviconImageView] non-HTTP response url=\(url.absoluteString)")
                    debugInfo = "[favicon] non-HTTP response"
                    failed = true
                    return
                }
                if let image = UIImage(data: data) {
                    print("[FaviconImageView] SUCCESS \(Int(image.size.width))x\(Int(image.size.height)) url=\(url.absoluteString)")
                    debugInfo = "[favicon] OK \(data.count)B"
                    uiImage = image
                } else {
                    print("[FaviconImageView] UIImage DECODE FAILED bytes=\(data.count) url=\(url.absoluteString)")
                    debugInfo = "[favicon] decode fail \(data.count)B"
                    failed = true
                }
            } catch {
                print("[FaviconImageView] ERROR \(error.localizedDescription) url=\(url.absoluteString)")
                debugInfo = "[favicon] error: \(error.localizedDescription)"
                if !Task.isCancelled {
                    failed = true
                }
            }
        }
    }
}

// MARK: - Color hex (for collection chips etc.)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
            self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
        default:
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
        }
    }
}
