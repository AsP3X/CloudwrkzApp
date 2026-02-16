//
//  LinksOverviewView.swift
//  Cloudwrkz
//
//  Enterprise links list with filter sheet. Liquid glass, modern enterprise. Matches cloudwrkz links design.
//

import SwiftUI

struct LinksOverviewView: View {
    @State private var links: [Link] = []
    @State private var collections: [Collection] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    /// Shown as banner when pull-to-refresh fails but we keep the current list.
    @State private var refreshErrorMessage: String?
    @State private var filters = LinkFilters()
    @State private var showFilters = false
    @State private var showAddLink = false
    /// When true, tapping rows toggles selection instead of navigating. Driven by bulk "Select" action.
    @State private var selectionMode = false
    /// Link ids currently selected for bulk actions.
    @State private var selectedLinkIds: Set<String> = []
    /// Link pending deletion confirmation from the context menu.
    @State private var pendingDeleteLink: Link?

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
                    .safeAreaInset(edge: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            if let refreshErr = refreshErrorMessage {
                                refreshErrorBanner(message: refreshErr)
                            }
                            if !collections.isEmpty || filters.collectionId != nil {
                                collectionPicker
                            }
                        }
                    }
            }
        }
        .navigationTitle("Links")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .overlay(alignment: .bottomTrailing) {
            if !isLoading || !links.isEmpty {
                addLinkButton
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if selectionMode {
                    Button("Done") {
                        selectionMode = false
                        selectedLinkIds.removeAll()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.primary400)
                }
            }
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
            LinkFiltersView(filters: $filters, collections: collections)
                .onDisappear { Task { await loadLinks() } }
        }
        .sheet(isPresented: $showAddLink) {
            AddLinkView(
                collections: collections,
                currentCollectionId: filters.collectionId,
                onSaved: {
                    Task {
                        await loadCollections()
                        await loadLinks()
                    }
                }
            )
        }
        .onChange(of: showFilters) { _, isOpen in
            if isOpen { Task { await loadCollections() } }
        }
        .onAppear {
            Task { await loadCollections() }
            Task { await loadLinks() }
        }
        .overlay {
            if let link = pendingDeleteLink {
                deleteConfirmationDialog(for: link)
            }
        }
    }

    /// Floating add-link button, bottom right. Liquid glass style.
    private var addLinkButton: some View {
        Button {
            showAddLink = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral950)
                .frame(width: 56, height: 56)
                .background(CloudwrkzColors.primary400, in: Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }

    /// Horizontal scroll of "All" + collection chips. Liquid glass style.
    private var collectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                collectionChip(name: "All", id: nil)
                ForEach(collections) { collection in
                    collectionChip(name: collection.name, id: collection.id)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(CloudwrkzColors.neutral950.opacity(0.6))
    }

    private func collectionChip(name: String, id: String?) -> some View {
        let isSelected = (filters.collectionId == nil && id == nil) || (filters.collectionId == id)
        return Button {
            filters.collectionId = id
            Task { await loadLinks() }
        } label: {
            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? CloudwrkzColors.neutral950 : CloudwrkzColors.neutral100)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? CloudwrkzColors.primary400
                        : Color.clear,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(isSelected ? 0 : 0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
            CloudwrkzSpinner(tint: CloudwrkzColors.primary400)
                .scaleEffect(1.2)
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
            Text(filters.collectionId != nil
                 ? "No links in this collection."
                 : "Add and organize bookmarks in the web app.")
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
                    let isSelected = selectedLinkIds.contains(link.id)
                    LinkRowView(
                        link: link,
                        serverBaseURL: config.baseURL,
                        isSelected: isSelected,
                        selectionMode: selectionMode
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectionMode {
                            toggleSelection(for: link)
                        }
                    }
                    .contextMenu {
                        Button {
                            toggleSelection(for: link)
                        } label: {
                            Text(isSelected ? "Deselect" : "Select")
                        }
                        Button {
                            // Hook for future edit flow (e.g. navigate to edit screen)
                        } label: {
                            Text("Edit")
                        }
                        Button {
                            // Hook for future archive API integration.
                        } label: {
                            Text("Archive")
                        }
                        Button(role: .destructive) {
                            pendingDeleteLink = link
                        } label: {
                            Text("Delete")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .refreshable {
            refreshErrorMessage = nil
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await loadCollections() }
                group.addTask { await loadLinks(isRefresh: true) }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func refreshErrorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(CloudwrkzColors.warning500)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CloudwrkzColors.neutral100)
            Spacer()
            Button("Dismiss") {
                refreshErrorMessage = nil
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(CloudwrkzColors.primary400)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CloudwrkzColors.neutral800.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.white.opacity(0.15)),
            alignment: .bottom
        )
    }

    private func loadCollections() async {
        let result = await CollectionService.fetchCollections(config: config, archived: false)
        await MainActor.run {
            if case .success(let list) = result {
                collections = list
            }
        }
    }

    /// When `isRefresh` is true and we already have links, failure shows a banner instead of clearing the list.
    private func loadLinks(isRefresh: Bool = false) async {
        let hadLinks = !links.isEmpty
        if !isRefresh {
            errorMessage = nil
            isLoading = true
        }
        let result = await LinkService.fetchLinks(config: config, filters: filters, page: 1, limit: 100)
        await MainActor.run {
            switch result {
            case .success(let response):
                links = response.links
                errorMessage = nil
                refreshErrorMessage = nil
            case .failure(let err):
                let errText = message(for: err)
                if isRefresh && hadLinks {
                    refreshErrorMessage = errText
                    // Keep existing links
                } else {
                    links = []
                    errorMessage = errText
                }
            }
            isLoading = false
        }
    }

    // MARK: - Link actions for long-press menu / bulk selection

    /// Toggle selection for bulk actions. First selection enables selection mode; clearing all exits it.
    private func toggleSelection(for link: Link) {
        if selectedLinkIds.contains(link.id) {
            selectedLinkIds.remove(link.id)
            if selectedLinkIds.isEmpty {
                selectionMode = false
            }
        } else {
            selectedLinkIds.insert(link.id)
            if !selectionMode {
                selectionMode = true
            }
        }
    }

    /// Centered liquid-glass confirmation dialog for deleting a link.
    @ViewBuilder
    private func deleteConfirmationDialog(for link: Link) -> some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "trash")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(CloudwrkzColors.error500)
                        Text("Delete link?")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                    }
                    Text("“\(link.title)” will be removed from this list. This action can’t be undone.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(CloudwrkzColors.neutral400)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Button {
                        pendingDeleteLink = nil
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(
                        Group {
                            if #available(iOS 26.0, *) {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.clear)
                                    .glassEffect(.regular.tint(.white.opacity(0.04)), in: RoundedRectangle(cornerRadius: 14))
                            } else {
                                Color.clear
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    )

                    Button {
                        // TODO: Wire to real delete endpoint, then refresh list.
                        pendingDeleteLink = nil
                    } label: {
                        Text("Delete")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(CloudwrkzColors.neutral950)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(CloudwrkzColors.error500)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(
                Group {
                    if #available(iOS 26.0, *) {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(.clear)
                            .glassEffect(.regular.tint(.white.opacity(0.08)), in: RoundedRectangle(cornerRadius: 22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(.white.opacity(0.16), lineWidth: 1)
                            )
                    } else {
                        Color.clear
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(.white.opacity(0.16), lineWidth: 1)
                            )
                    }
                }
            )
            .padding(.horizontal, 24)
        }
    }

    // (Context menu actions are currently simple hooks – real edit/archive/delete can be wired here later.)

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

// MARK: - Link row (liquid glass card, type badge; tap opens link detail)

private struct LinkRowView: View {
    let link: Link
    /// Server base URL (e.g. https://cloudwrkz.com). Used to resolve relative favicon paths from the API.
    var serverBaseURL: URL?
    /// When true, shows a subtle selected state for bulk actions.
    var isSelected: Bool = false
    /// When true, the list is in selection mode (driven from parent). Used only for visuals here.
    var selectionMode: Bool = false

    var body: some View {
        NavigationLink(value: link) {
            ZStack {
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
                            .foregroundStyle(CloudwrkzColors.primary400)
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
                        let linkCollections = link.collections ?? []
                        if !linkCollections.isEmpty {
                            let names = linkCollections.prefix(2).map { $0.collection.name }
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
        }
        .buttonStyle(.plain)
    }

    private var linkIcon: some View {
        let faviconURL = resolvedFaviconURL
        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(CloudwrkzColors.primary500.opacity(0.15))
                .frame(width: 40, height: 40)
            if let url = faviconURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    case .failure, .empty:
                        typeIconFallback
                    @unknown default:
                        typeIconFallback
                    }
                }
                .id(url.absoluteString)
            } else {
                typeIconFallback
            }
        }
        .frame(width: 40, height: 40)
    }

    /// Favicon URL to display: server-provided if present; otherwise we fall back to the type icon.
    /// This matches the Cloudwrkz server behavior so that when a favicon has been cached on the server,
    /// the iOS app uses that exact icon. When the server has no favicon, we intentionally avoid third‑party
    /// favicon services and show only the type-based icon.
    private var resolvedFaviconURL: URL? {
        return serverProvidedFaviconURL
    }

    /// Server-stored favicon: relative paths resolved against serverBaseURL; protocol-relative and absolute supported.
    private var serverProvidedFaviconURL: URL? {
        let fav = (link.favicon ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fav.isEmpty else { return nil }
        if fav.hasPrefix("//") {
            return URL(string: "https:" + fav)
        }
        if fav.hasPrefix("/") {
            guard let base = serverBaseURL else { return nil }
            return URL(string: fav, relativeTo: base)?.absoluteURL
        }
        return URL(string: fav)
    }

    private var typeIconFallback: some View {
        Image(systemName: linkTypeIcon(link.linkType))
            .font(.system(size: 18))
            .foregroundStyle(CloudwrkzColors.primary400)
    }

    private var linkRowGlass: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.white.opacity(0.08)), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? CloudwrkzColors.primary400 : .white.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? CloudwrkzColors.primary400 : .white.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
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
    var collections: [Collection] = []
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

                        if !collections.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader("Collection")
                                VStack(spacing: 10) {
                                    filterRow(
                                        title: "All links",
                                        isSelected: filters.collectionId == nil
                                    ) {
                                        filters.collectionId = nil
                                    }
                                    ForEach(collections) { collection in
                                        filterRow(
                                            title: collection.name,
                                            isSelected: filters.collectionId == collection.id
                                        ) {
                                            filters.collectionId = collection.id
                                        }
                                    }
                                }
                                .padding(20)
                                .glassPanel(cornerRadius: 20, tint: CloudwrkzColors.primary500, tintOpacity: 0.04)
                            }
                        }

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
