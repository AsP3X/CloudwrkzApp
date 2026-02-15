//
//  DashboardHomeView.swift
//  Cloudwrkz
//
//  Default dashboard detail: welcome and quick access to sections.
//

import SwiftUI

struct DashboardHomeView: View {
    var onSelectSection: ((DashboardSection) -> Void)?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    welcomeSection
                    quickAccessSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .toolbarBackground(CloudwrkzColors.neutral950.opacity(0.95), for: .navigationBar)
    }

    private var welcomeSection: some View {
        Text("Welcome back. Choose a section from the menu or use the shortcuts below.")
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(CloudwrkzColors.neutral400)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK ACCESS")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(CloudwrkzColors.neutral500)

            VStack(spacing: 10) {
                ForEach(DashboardSection.allCases.filter { $0 != .home }) { section in
                    Button {
                        onSelectSection?(section)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: section.iconName)
                                .font(.system(size: 20))
                                .foregroundStyle(CloudwrkzColors.primary400)
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(CloudwrkzColors.neutral100)
                                Text(section.subtitle)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(CloudwrkzColors.neutral500)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CloudwrkzColors.neutral500)
                        }
                        .padding(16)
                        .background(quickAccessRowGlass)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quickAccessRowGlass: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.white.opacity(0.04)), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            }
        }
    }
}

#Preview {
    NavigationStack {
        DashboardHomeView()
    }
}
