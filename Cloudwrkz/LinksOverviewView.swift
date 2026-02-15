//
//  LinksOverviewView.swift
//  Cloudwrkz
//
//  Enterprise links list with filter sheet. Liquid glass, modern enterprise. Matches cloudwrkz links design.
//

import SwiftUI

struct LinksOverviewView: View {
    @State private var links: [Link] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var filters = LinkFilters()
    @State private var showFilters = false

    private let config = ServerConfig.load()

    var body: some View {
        ZStack {
            background
            if isLoading && links.isEmpty {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if links.isEmpty {
                emptyView
            } else {
                linkList
            }
        }
        .navigationTitle("Links")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CloudwrkzColors.neutral950.opacity(0.95), for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(CloudwrkzColors.primary400)
                }
            }
        }
        .tint(CloudwrkzColors.primary400)
        .sheet(isPresented: $showFilters) {
            LinkFiltersView(filters: $filters)
                .onDisappear { Task { await loadLinks() } }
        }
        .onAppear { Task { await loadLinks() } }
    }

    private var background: some View {
        LinearGradient(
            colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(CloudwrkzColors.primary400)
            Text("Loading links…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CloudwrkzColors.neutral400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(CloudwrkzColors.warning500)
            Text("Couldn't load links")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral100)
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CloudwrkzColors.neutral400)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") { Task { await loadLinks() } }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.primary400)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link")
                .font(.system(size: 48))
                .foregroundStyle(CloudwrkzColors.neutral500)
            Text("No links")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral100)
            Text("Add and organize bookmarks in the web app.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CloudwrkzColors.neutral500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var linkList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(links) { link in
                    LinkRowView(link: link)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .refreshable {
            await loadLinks()
        }
    }

    private func loadLinks() async {
        errorMessage = nil
        isLoading = true
        let result = await LinkService.fetchLinks(config: config, filters: filters, page: 1, limit: 100)
        await MainActor.run {
            switch result {
            case .success(let response):
                links = response.links
                errorMessage = nil
            case .failure(let err):
                links = []
                errorMessage = message(for: err)
            }
            isLoading = false
        }
    }

    private func message(for error: LinkServiceError) -> String {
        switch error {
        case .noServerURL: return "No server configured."
        case .noToken: return "Please sign in again."
        case .unauthorized: return "Session expired. Sign in again."
        case .serverError(let m): return m
        case .networkError: return "Could not reach server."
        }
    }
}

// MARK: - Link row (liquid glass card, type badge, open in Safari)

private struct LinkRowView: View {
    let link: Link

    var body: some View {
        Button {
            openURL(link.url)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    linkIcon
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            typePill(link.linkType)
                            if link.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(CloudwrkzColors.warning400)
                            }
                        }
                        Text(link.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CloudwrkzColors.neutral500)
                }

                if let desc = link.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(CloudwrkzColors.neutral400)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Text(domainLabel(link.url))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CloudwrkzColors.primary400)
                        .lineLimit(1)
                    if !link.collections.isEmpty {
                        let names = link.collections.prefix(2).map { $0.collection.name }
                        Text(names.joined(separator: ", "))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(CloudwrkzColors.neutral500)
                            .lineLimit(1)
                    }
                    Text(formatted(link.createdAt))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(CloudwrkzColors.neutral500)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(linkRowGlass)
        }
        .buttonStyle(.plain)
    }

    private var linkIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(CloudwrkzColors.primary500.opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: linkTypeIcon(link.linkType))
                .font(.system(size: 18))
                .foregroundStyle(CloudwrkzColors.primary400)
        }
    }

    private var linkRowGlass: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.white.opacity(0.08)), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }

    private func typePill(_ type: String) -> some View {
        Text(type.replacingOccurrences(of: "_", with: " "))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(CloudwrkzColors.neutral200)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(CloudwrkzColors.neutral700.opacity(0.8), in: Capsule())
    }

    private func linkTypeIcon(_ type: String) -> String {
        switch type.uppercased() {
        case "VIDEO": return "play.rectangle.fill"
        case "FILE": return "doc.fill"
        case "DOCUMENT": return "doc.text.fill"
        case "IMAGE": return "photo.fill"
        default: return "link"
        }
    }

    private func domainLabel(_ urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else { return urlString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Link filters sheet

struct LinkFiltersView: View {
    @Binding var filters: LinkFilters
    @Environment(\.dismiss) private var dismiss

    private var background: some View {
        LinearGradient(
            colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(CloudwrkzColors.neutral500)
    }

    private func filterRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CloudwrkzColors.neutral100)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(CloudwrkzColors.primary400)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(CloudwrkzColors.primary400)
                                Text("Filter links")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(CloudwrkzColors.neutral100)
                            }
                            Text("Sort and filter your saved links.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(CloudwrkzColors.neutral400)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Show")
                            VStack(spacing: 10) {
                                ForEach(LinkFilters.LinkFavoriteFilter.allCases) { option in
                                    filterRow(
                                        title: option.displayName,
                                        isSelected: filters.isFavorite == option
                                    ) {
                                        filters.isFavorite = option
                                    }
                                }
                            }
                            .padding(20)
                            .glassPanel(cornerRadius: 20, tint: CloudwrkzColors.primary500, tintOpacity: 0.04)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Sort by")
                            VStack(spacing: 10) {
                                ForEach(LinkFilters.LinkSortOption.allCases) { option in
                                    filterRow(
                                        title: option.displayName,
                                        isSelected: filters.sort == option
                                    ) {
                                        filters.sort = option
                                    }
                                }
                            }
                            .padding(20)
                            .glassPanel(cornerRadius: 20, tint: CloudwrkzColors.primary500, tintOpacity: 0.04)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.primary400)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LinksOverviewView()
    }
}
