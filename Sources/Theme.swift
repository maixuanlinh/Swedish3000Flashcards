import SwiftUI

enum Palette {
    static let background = Color(red: 0.965, green: 0.957, blue: 0.933)
    static let ink = Color(red: 0.12, green: 0.20, blue: 0.18)
    static let forest = Color(red: 0.19, green: 0.39, blue: 0.31)
    static let sage = Color(red: 0.88, green: 0.92, blue: 0.86)
    static let muted = Color(red: 0.43, green: 0.47, blue: 0.43)
    static let clay = Color(red: 0.73, green: 0.36, blue: 0.25)
    static let peach = Color(red: 0.98, green: 0.90, blue: 0.84)
    static let line = Color(red: 0.88, green: 0.89, blue: 0.85)
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
            .foregroundStyle(status == .known ? Palette.forest : status == .learning ? Palette.clay : Palette.muted)
            .background(status == .known ? Palette.sage : status == .learning ? Palette.peach : Palette.background, in: Capsule())
    }
}

struct FilledActionStyle: ButtonStyle {
    var color: Color = Palette.forest
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
