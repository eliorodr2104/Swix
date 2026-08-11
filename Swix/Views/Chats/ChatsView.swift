//
//  ChatsView.swift
//  Swix
//
//  Created by Eliomar on 08/08/2026.
//

import SwiftUI

struct ChatsView: View {
    
    @Environment(\.chatListViewModel)
    private var chatListViewModel
    
    @State
    private var selectionMode: Bool = false

    /// The pinned chats and the normal ones laid out as one sequence, titles included. Keeping both
    /// groups in a single array is what lets a row that gets pinned travel between them instead of
    /// vanishing from one `ForEach` and reappearing in another. The "Chats" title only exists while
    /// something is pinned, because with nothing above it there is nothing to tell apart.
    private var items: [ChatListItem] {

        let pinned = chatListViewModel?.pinned ?? []
        let chats  = chatListViewModel?.chats  ?? []

        var items: [ChatListItem] = []

        if !pinned.isEmpty {

            items.append(.header("Pinned"))
            items.append(contentsOf: pinned.map(ChatListItem.room))

            if !chats.isEmpty {
                
                items.append(.header("Chats"))
            }
        }
        
        items.append(contentsOf: chats.map(ChatListItem.room))

        return items
    }

    var body: some View {

        let items = self.items
        let firstItemID = items.first?.id

        NavigationStack {
            ScrollView {

                LazyVStack(alignment: .leading) {

                    ForEach(items) { item in

                        switch item {
                            
                            case .header(let title):

                                sectionHeader(title)
                                    .padding(
                                        .top,
                                        item.id == firstItemID ? 0 : 24
                                    )
                                    .padding(.leading)
                                    .transition(
                                        .opacity
                                        .combined(
                                            with: .scale(
                                                scale : 0.96,
                                                anchor: .leading
                                            )
                                        )
                                    )

                            case .room(let summary):

                               ChatRowView(summary: summary) {

                               }
                               .equatable()

                        }
                    }
                }
                .animation(
                    .snappy(duration: 0.35),
                    value: items.map(\.id)
                )

            }
            .withProfileToolbar()
            .withNameToolbar(NavigationState.chats.rawValue)
            .toolbar {
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    
                    Button {
                        withAnimation {
                            selectionMode.toggle()
                        }
                                       
                    } label: {
                        Label(
                            selectionMode ? "Done" : "Select Chats",
                            systemImage: selectionMode ? "checkmark.circle.fill" :
                                "checklist"
                        )
                    }
                    .contentTransition(.symbolEffect(.replace))
                    .fontWeight(selectionMode ? .semibold : .regular)
                    
                    if !selectionMode {
                        Button("New Chat", systemImage: "bubble.and.pencil") {
                            print("New chat")
                        }
                    }
                }
                
                ToolbarSpacer(placement: .topBarTrailing)
            }
        }
    }
    
    private func sectionHeader(_ text: String) -> some View {
        
        Text(text)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
        
    }
}
