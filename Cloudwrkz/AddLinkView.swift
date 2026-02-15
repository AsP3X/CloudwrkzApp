//
//  AddLinkView.swift
//  Cloudwrkz
//
//  Add link sheet. Liquid glass, modern enterprise. Matches Links design language.
//

import SwiftUI

struct AddLinkView: View {
    @Environment(\.dismiss) private var dismiss
    var collections: [Collection]
    var currentCollectionId: String?
    var onSaved: () -> Void

    @State private var urlText = ""
    @State private var titleText = ""
    @State private var descriptionText = ""
    @State private var selectedCollectionId: String?
    @State private var isSaving = false
    @State private var isExtractingMetadata = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private let config = ServerConfig.load()

    enum Field {
        case url, title, description
    }

    private var background: some View {
        LinearGradient(
            colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(CloudwrkzColors.neutral500)
    }

    private var canSave: Bool {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.contains("."))
    }

    private var canFetchMetadata: Bool {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.contains(".")) && !isExtractingMetadata
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        sectionLabel("URL")
                        TextField("https://example.com", text: $urlText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .url)
                            .padding(14)
                            .glassField(cornerRadius: 12)

                        Button {
                            Task { await fetchMetadata() }
                        } label: {
                            HStack(spacing: 8) {
                                if isExtractingMetadata {
                                    ProgressView()
                                        .scaleEffect(0.9)
                                        .tint(CloudwrkzColors.neutral100)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 18))
                                }
                                Text(isExtractingMetadata ? "Extracting…" : "Fetch title & description")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(canFetchMetadata ? CloudwrkzColors.primary400 : CloudwrkzColors.neutral500)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .glassButtonSecondary(cornerRadius: 12)
                        }
                        .disabled(!canFetchMetadata)

                        sectionLabel("Title (optional)")
                        TextField("Title", text: $titleText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                            .focused($focusedField, equals: .title)
                            .padding(14)
                            .glassField(cornerRadius: 12)

                        sectionLabel("Description (optional)")
                        TextField("Description", text: $descriptionText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                            .focused($focusedField, equals: .description)
                            .padding(14)
                            .glassField(cornerRadius: 12)

                        if !collections.isEmpty {
                            sectionLabel("Add to collection")
                            VStack(spacing: 10) {
                                addLinkCollectionRow(name: "None", id: nil)
                                ForEach(collections) { collection in
                                    addLinkCollectionRow(name: collection.name, id: collection.id)
                                }
                            }
                            .padding(20)
                            .glassPanel(cornerRadius: 20, tint: CloudwrkzColors.primary500, tintOpacity: 0.04)
                        }

                        if let err = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(CloudwrkzColors.error500)
                                Text(err)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(CloudwrkzColors.neutral100)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CloudwrkzColors.error500.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CloudwrkzColors.neutral950.opacity(0.95), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(CloudwrkzColors.primary400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(canSave && !isSaving ? CloudwrkzColors.primary400 : CloudwrkzColors.neutral500)
                    .disabled(!canSave || isSaving)
                }
            }
            .tint(CloudwrkzColors.primary400)
            .onAppear {
                selectedCollectionId = currentCollectionId
                if urlText.isEmpty {
                    focusedField = .url
                }
            }
        }
    }

    private func addLinkCollectionRow(name: String, id: String?) -> some View {
        let isSelected = (selectedCollectionId == nil && id == nil) || (selectedCollectionId == id)
        return Button {
            selectedCollectionId = id
        } label: {
            HStack {
                Text(name)
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

    private func fetchMetadata() async {
        errorMessage = nil
        var url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty && !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        guard !url.isEmpty else { return }
        isExtractingMetadata = true
        let result = await LinkService.fetchMetadata(config: config, url: url)
        await MainActor.run {
            isExtractingMetadata = false
            switch result {
            case .success(let meta):
                if titleText.isEmpty, let t = meta.title, !t.isEmpty {
                    titleText = t
                }
                if descriptionText.isEmpty, let d = meta.description, !d.isEmpty {
                    descriptionText = d
                }
            case .failure(let err):
                errorMessage = message(for: err)
            }
        }
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        var url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty && !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        let collectionIds: [String]? = selectedCollectionId.map { [$0] }
        let result = await LinkService.createLink(
            config: config,
            url: url,
            title: titleText.isEmpty ? nil : titleText,
            description: descriptionText.isEmpty ? nil : descriptionText,
            collectionIds: collectionIds
        )
        await MainActor.run {
            isSaving = false
            switch result {
            case .success:
                onSaved()
                dismiss()
            case .failure(let err):
                errorMessage = message(for: err)
            }
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

#Preview {
    AddLinkView(
        collections: [],
        currentCollectionId: nil,
        onSaved: {}
    )
}
