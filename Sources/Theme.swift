import SwiftUI

enum Palette {
    static let background = Color(red: 0.961, green: 0.973, blue: 0.988)
    static let ink = Color(red: 0.078, green: 0.169, blue: 0.259)
    // Swedish-flag-inspired blue and yellow; yellow is decorative on blue.
    static let accent = Color(red: 0, green: 106.0 / 255, blue: 167.0 / 255)
    static let accentSoft = Color(red: 0.878, green: 0.929, blue: 0.969)
    static let flagYellow = Color(red: 254.0 / 255, green: 204.0 / 255, blue: 0)
    static let muted = Color(red: 0.322, green: 0.392, blue: 0.467)
    static let clay = Color(red: 0.65, green: 0.30, blue: 0.16)
    static let peach = Color(red: 0.98, green: 0.90, blue: 0.84)
    static let line = Color(red: 0.843, green: 0.886, blue: 0.925)
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(2)
            .foregroundStyle(Palette.muted)
    }
}

struct StatusBadge: View {
    let status: LearningStatus
    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .foregroundStyle(status == .known ? Palette.accent : status == .learning ? Palette.clay : Palette.muted)
            .background(status == .known ? Palette.accentSoft : status == .learning ? Palette.peach : Palette.background, in: Capsule())
    }
}

struct FilledActionStyle: ButtonStyle {
    var color: Color = Palette.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(color, in: RoundedRectangle(cornerRadius: 18))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
