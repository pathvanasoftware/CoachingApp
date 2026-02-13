import SwiftUI

struct PersonaAvatar: View {
    let persona: CoachingPersonaType
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(persona.accentColor.gradient)
                .frame(width: size, height: size)

            Image(systemName: persona.icon)
                .font(.system(size: size * 0.4))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        PersonaAvatar(persona: .directChallenger, size: 60)
        PersonaAvatar(persona: .supportiveStrategist, size: 60)
    }
}
