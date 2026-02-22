import SwiftUI

struct PersonaAvatar: View {
    let persona: CoachingPersonaType
    var size: CGFloat = 60
    
    var body: some View {
        Circle()
            .fill(AppTheme.primary)
            .frame(width: size, height: size)
            .overlay(
                Text(String(persona.displayName.prefix(1)))
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.white)
            )
    }
}
