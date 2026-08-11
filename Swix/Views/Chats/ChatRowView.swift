//
//  ChatRowView.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import SwiftUI
import SwiftUIKit

struct ChatRowView: View, Equatable {
        
    @Environment(\.chatListViewModel)
    private var chatListViewModel
    
    let summary: RoomSummary
    
    let action: () -> Void
    
    var body: some View {
        
        Button {
            action()
        } label: {
            
            HStack(
                alignment: .top,
                spacing  : 12
            ) {
                
                profilePicture
                
                VStack(
                    alignment: .leading,
                    spacing  : 4
                ) {
                    Text(summary.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let preview = summary.preview?.text {
                        Text(preview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.regular)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                VStack(
                    alignment: .trailing,
                    spacing  : 5
                ) {
                    if let lastActivity = summary.lastActivity {
                        Text(
                            lastActivity.formatted(
                                date: .omitted,
                                time: .shortened
                            )
                        )
                        .font(.subheadline)
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                    }
                    
                    if summary.unreadMessages != 0 {
                        Text(String(summary.unreadMessages))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .surface(
                                .accent,
                                in: .capsule
                            )
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
        }
        .buttonStyle(PressableRowButtonStyle())
        .contextMenu {
            
            Button {
                            
                Task {
                    
                    if summary.isMarkedUnread {
                        
                        await chatListViewModel?.markAsRead(roomID: summary.id)
                        
                    } else {
                        await chatListViewModel?.markAsUnread(roomID: summary.id)
                    }
                }
                
            } label: {
                Label(
                    summary.isMarkedUnread ? "Read" : "Unread",
                    systemImage: summary.isMarkedUnread ? "message" : "message.badge"
                )
            }

            if let isMuted = chatListViewModel?.isMuted(roomID: summary.id) {
                
                Button {
                    
                    Task {
                        await chatListViewModel?.loadNotificationSetting(for: summary)
                    }
                    
                } label: {
                    Label(
                        isMuted ? "Unmute" : "Mute",
                        systemImage: isMuted ? "bell" : "bell.slash"
                    )
                }
            }
            
            
            Button {
                
                Task {
                    await chatListViewModel?.toggleFavourite(roomID: summary.id)
                }
                
            } label: {
                Label(
                    summary.isFavourite ? "Unpin" : "Pin",
                    systemImage: summary.isFavourite ? "pin.slash" : "pin"
                )
            }
            
            Button {
                
                Task {
                    await chatListViewModel?.toggleArchive(roomID: summary.id)
                }
                
            } label: {
                Label(
                    summary.isLowPriority ? "shippingbox.and.arrow.backward" : "Archive",
                    systemImage: "archivebox"
                )
            }
            
            Button(role: .destructive) {
                
                Task {
                    await chatListViewModel?.leave(roomID: summary.id)
                }
                
            } label: {
                Label("Leave room", systemImage: "trash")
            }
        }
    }
    
    private var profilePicture: some View {
        
        MatrixImage(
            mediaURI: summary.avatarURL?.absoluteString
        ) { phase in
            switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                    
                case .empty:
                    Color(.secondarySystemFill)

                case .failure:
                    Text(summary.name)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
    
    static func == (lhs: ChatRowView, rhs: ChatRowView) -> Bool {
        lhs.summary == rhs.summary
    }
}

