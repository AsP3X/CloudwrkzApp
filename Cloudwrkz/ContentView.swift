//
//  ContentView.swift
//  Cloudwrkz
//
//  Liquid glass only. Enterprise main content.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            ZStack {
                LinearGradient(
                    colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                List {
                    ForEach(items) { item in
                        NavigationLink {
                            detailContent(for: item)
                        } label: {
                            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(CloudwrkzColors.neutral100)
                        }
                        .listRowBackground(listRowGlass)
                        .listRowSeparatorTint(.white.opacity(0.12))
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .fontWeight(.medium)
                        .foregroundStyle(CloudwrkzColors.primary400)
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                    .foregroundStyle(CloudwrkzColors.primary400)
                }
            }
            .tint(CloudwrkzColors.primary400)
            .toolbarBackground(CloudwrkzColors.neutral950.opacity(0.95), for: .navigationBar)
        } detail: {
            ZStack {
                LinearGradient(
                    colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .toolbarBackground(CloudwrkzColors.neutral950.opacity(0.95), for: .navigationBar)
            .overlay {
                Text("Select an item")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }
        }
    }

    @ViewBuilder
    private func detailContent(for item: Item) -> some View {
        ZStack {
            LinearGradient(
                colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(CloudwrkzColors.neutral100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(28)
                .glassPanel(cornerRadius: 20)
                .padding(20)
        }
    }

    private var listRowGlass: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.white.opacity(0.04)), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
