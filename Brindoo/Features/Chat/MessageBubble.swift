//
//  MessageBubble.swift
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    let isOwn: Bool
    let repliedTo: Message?
    let otherUserReadReceiptsEnabled: Bool
    let myReadReceiptsEnabled: Bool
    
    let onTapImage: (String) -> Void
    let onTapBomb: () -> Void
    let onReply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    /// Callback per segnalare il messaggio (mostrato solo per messaggi NON propri).
    /// Lasciato opzionale per non rompere altre call-site del componente.
    var onReport: (() -> Void)? = nil
    
    private var bubbleColor: Color {
        isOwn ? Color.brindooCoral : Color.brindooSurface
    }
    
    private var textColor: Color {
        isOwn ? .white : Color.brindooTextPrimary
    }
    
    private var timeLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "it_IT")
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: message.createdAt)
    }
    
    /// Mostra check di lettura solo se ENTRAMBI gli utenti hanno read receipts attivi
    private var showReadReceipt: Bool {
        isOwn && otherUserReadReceiptsEnabled && myReadReceiptsEnabled
    }
    
    var body: some View {
        HStack {
            if isOwn { Spacer(minLength: 60) }
            
            bubbleContent
                .contextMenu {
                    if !message.isDeleted {
                        Button { onReply() } label: {
                            Label("Rispondi", systemImage: "arrowshape.turn.up.left")
                        }

                        if isOwn && message.isEditable {
                            Button { onEdit() } label: {
                                Label("Modifica", systemImage: "pencil")
                            }
                        }

                        if isOwn {
                            Button(role: .destructive) { onDelete() } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }

                        // Segnalazione disponibile solo per messaggi altrui.
                        if !isOwn, let onReport {
                            Divider()
                            Button(role: .destructive) { onReport() } label: {
                                Label("Segnala", systemImage: "exclamationmark.bubble")
                            }
                        }
                    }
                }
            
            if !isOwn { Spacer(minLength: 60) }
        }
    }
    
    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: BrindooSpacing.xxs) {
                
                // Quote (reply)
                if let repliedTo {
                    quoteView(repliedTo)
                }
                
                // Body
                if message.isDeleted {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Messaggio eliminato")
                            .italic()
                            .font(BrindooFont.bodySmall)
                    }
                    .foregroundStyle(isOwn ? .white.opacity(0.7) : Color.brindooTextSecondary)
                } else {
                    switch message.messageType {
                    case .text:
                        Text(message.content)
                            .font(BrindooFont.bodyMedium)
                            .foregroundStyle(textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    case .image:
                        imageContent
                    case .bombImage:
                        bombContent
                    case .system:
                        Text(message.content)
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                }
            }
            .padding(.horizontal, message.messageType == .text || message.isDeleted ? 12 : 4)
            .padding(.vertical, message.messageType == .text || message.isDeleted ? 8 : 4)
            .background(bubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            
            // Footer (orario + check + edited)
            HStack(spacing: 4) {
                if message.isEdited && !message.isDeleted {
                    Text("modificato")
                        .font(.system(size: 10))
                        .italic()
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                Text(timeLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.brindooTextSecondary)
                
                if showReadReceipt {
                    Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(message.isRead ? Color.brindooSuccess : Color.brindooTextSecondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private func quoteView(_ replied: Message) -> some View {
        HStack(spacing: BrindooSpacing.xs) {
            Rectangle()
                .fill(isOwn ? .white.opacity(0.8) : Color.brindooCoral)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Risposta")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isOwn ? .white.opacity(0.9) : Color.brindooCoral)
                Text(quotePreview(replied))
                    .font(.system(size: 12))
                    .foregroundStyle(isOwn ? .white.opacity(0.85) : Color.brindooTextSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isOwn ? Color.white.opacity(0.15) : Color.brindooBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func quotePreview(_ replied: Message) -> String {
        if replied.isDeleted { return "Messaggio eliminato" }
        switch replied.messageType {
        case .image: return "📷 Foto"
        case .bombImage: return "💣 Foto bomba"
        default: return replied.content
        }
    }
    
    // MARK: - Image content
    
    @ViewBuilder
    private var imageContent: some View {
        if let urlString = message.imageUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 240, maxHeight: 320)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .onTapGesture { onTapImage(urlString) }
                case .failure:
                    imageNotAvailable
                case .empty:
                    ProgressView()
                        .frame(width: 200, height: 200)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            imageNotAvailable
        }
    }
    
    @ViewBuilder
    private var imageNotAvailable: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo.badge.exclamationmark")
            Text("Immagine eliminata")
                .italic()
                .font(BrindooFont.bodySmall)
        }
        .foregroundStyle(isOwn ? .white.opacity(0.7) : Color.brindooTextSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Bomb content
    
    @ViewBuilder
    private var bombContent: some View {
        let alreadyViewed = message.bombViewedAt != nil
        
        Button {
            guard !alreadyViewed && !isOwn else { return }
            onTapBomb()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isOwn ? .white.opacity(0.25) : Color.brindooCoral.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: alreadyViewed ? "flame" : "flame.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(alreadyViewed ? Color.brindooTextSecondary : .orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(alreadyViewed ? "Foto bomba aperta" : "Foto bomba")
                        .font(BrindooFont.bodySmall.weight(.semibold))
                        .foregroundStyle(textColor)
                    Text(alreadyViewed ? "Non più disponibile" : (isOwn ? "Tap del destinatario per aprirla" : "Tocca per visualizzare"))
                        .font(.system(size: 11))
                        .foregroundStyle(isOwn ? .white.opacity(0.8) : Color.brindooTextSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .disabled(alreadyViewed || isOwn)
        .buttonStyle(.plain)
    }
}
