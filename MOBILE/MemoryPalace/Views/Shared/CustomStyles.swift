import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? color.opacity(0.8) : color)
            .foregroundColor(.white)
            .cornerRadius(Constants.UI.mediumCornerRadius)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? Color.gray.opacity(0.4) : Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(Constants.UI.mediumCornerRadius)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SuggestionButtonStyle: ButtonStyle {
    var color: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
