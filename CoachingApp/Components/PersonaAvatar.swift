import SwiftUI

struct PersonaAvatar: View {
    let persona: CoachingPersonaType
    var size: CGFloat = 60
    
    var body: some View {
        Circle()
            .fill(AppTheme.primary)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}
