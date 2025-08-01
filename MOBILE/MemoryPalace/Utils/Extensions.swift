import SwiftUI
import UIKit
import Foundation

struct DateParser {
    static func fromISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()

        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) {
            return date
        }

        return nil
    }
}

extension String {
    var isValidPersonName: Bool {
        let regex = try? NSRegularExpression(pattern: Constants.Validation.personNamePattern)
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex?.firstMatch(in: self, range: range) != nil
    }

    var isValidIPAddress: Bool {
        let regex = try? NSRegularExpression(pattern: Constants.Validation.ipAddressPattern)
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex?.firstMatch(in: self, range: range) != nil
    }

    var trimmed: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var capitalizingFirstLetter: String {
        return prefix(1).capitalized + dropFirst()
    }

    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count <= length {
            return self
        }
        return String(self.prefix(length)) + trailing
    }

    var sanitizedFileName: String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return components(separatedBy: invalidCharacters).joined(separator: "_")
    }

    func extractNames() -> [String] {
        return components(separatedBy: CharacterSet(charactersIn: ",;&"))
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
            .filter { $0.count >= Constants.Validation.minPersonNameLength }
    }
}

extension Date {
    var timeAgo: String {
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: self, to: now)

        if let years = components.year, years > 0 {
            return "\(years) year\(years == 1 ? "" : "s") ago"
        }

        if let months = components.month, months > 0 {
            return "\(months) month\(months == 1 ? "" : "s") ago"
        }

        if let days = components.day, days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }

        if let hours = components.hour, hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }

        if let minutes = components.minute, minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        }

        return "Just now"
    }

    var formattedForMemory: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var formattedShort: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(self) {
            formatter.timeStyle = .short
            return "Today \(formatter.string(from: self))"
        } else if Calendar.current.isDateInYesterday(self) {
            formatter.timeStyle = .short
            return "Yesterday \(formatter.string(from: self))"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: self)
        }
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(self.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var shortDuration: String {
        let minutes = Int(self) / 60
        let seconds = Int(self.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension Data {
    var sizeFormatted: String {
        return ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    var megabytes: Double {
        return Double(count) / (1024 * 1024)
    }

    func appending(_ string: String) -> Data {
        var newData = self
        if let stringData = string.data(using: .utf8) {
            newData.append(stringData)
        }
        return newData
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }

    func compressedJPEG(quality: CGFloat = Constants.Files.compressionQuality) -> Data? {
        return jpegData(compressionQuality: quality)
    }

    var aspectRatio: CGFloat {
        return size.width / size.height
    }

    func cropped(to rect: CGRect) -> UIImage? {
        guard let cgImage = cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }

    var sizeInMB: Double {
        guard let data = jpegData(compressionQuality: 1.0) else { return 0 }
        return data.megabytes
    }
}

extension Color {
    static let memoryPrimary = Color("MemoryPrimary", bundle: nil)
    static let memorySecondary = Color("MemorySecondary", bundle: nil)
    static let memoryAccent = Color("MemoryAccent", bundle: nil)
    static let memorySuccess = Color("MemorySuccess", bundle: nil)
    static let memoryError = Color("MemoryError", bundle: nil)
    static let memoryBackground = Color("MemoryBackground", bundle: nil)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(Constants.UI.mediumCornerRadius)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    func memoryCardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(Constants.UI.largeCornerRadius)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}

extension Array where Element == Memory {
    func groupedByMonth() -> [(String, [Memory])] {
        guard !self.isEmpty else { return [] }

        let monthYearFormatter = DateFormatter()
        monthYearFormatter.dateFormat = "MMMM yyyy"

        let groupedByString = Dictionary(grouping: self) { memory in
            return monthYearFormatter.string(from: memory.timestamp)
        }

        let sortedKeys = groupedByString.keys.sorted {
            if let date1 = monthYearFormatter.date(from: $0), let date2 = monthYearFormatter.date(from: $1) {
                return date1 > date2
            }
            return false
        }

        return sortedKeys.map { key in
            return (key, groupedByString[key] ?? [])
        }
    }

    func filterByType(_ type: MemoryType) -> [Memory] {
        return filter { $0.type == type }
    }

    func filterByPerson(_ personName: String) -> [Memory] {
        return filter { memory in
            memory.metadata.whoWasThere.lowercased().contains(personName.lowercased())
        }
    }
}

extension Array where Element == Person {
    func sortedByName() -> [Person] {
        return sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    func filteredByName(_ searchText: String) -> [Person] {
        guard !searchText.isEmpty else { return self }
        return filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
}

extension URLRequest {
    mutating func setAuthToken(_ token: String) {
        setValue(token, forHTTPHeaderField: Constants.Network.authHeaderName)
    }

    mutating func setUserAgent() {
        setValue(Constants.userAgent, forHTTPHeaderField: Constants.Network.userAgentHeaderName)
    }

    mutating func setJSONContentType() {
        setValue(Constants.Network.jsonContentType, forHTTPHeaderField: Constants.Network.contentTypeHeaderName)
    }
}

extension UserDefaults {
    func setObject<T: Codable>(_ object: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(object) {
            set(data, forKey: key)
        }
    }

    func getObject<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

extension Error {
    var isNetworkError: Bool {
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain
    }

    var isTimeoutError: Bool {
        let nsError = self as NSError
        return nsError.code == NSURLErrorTimedOut
    }
}

extension CGSize {
    func scaled(by factor: CGFloat) -> CGSize {
        return CGSize(width: width * factor, height: height * factor)
    }

    var aspectRatio: CGFloat {
        return width / height
    }

    func fitting(in boundingSize: CGSize) -> CGSize {
        let aspectRatio = self.aspectRatio
        let boundingAspectRatio = boundingSize.aspectRatio

        if aspectRatio > boundingAspectRatio {
            return CGSize(width: boundingSize.width, height: boundingSize.width / aspectRatio)
        } else {
            return CGSize(width: boundingSize.height * aspectRatio, height: boundingSize.height)
        }
    }
}

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }

    func scaled(by factor: CGFloat) -> CGRect {
        return CGRect(
            x: origin.x * factor,
            y: origin.y * factor,
            width: size.width * factor,
            height: size.height * factor
        )
    }

    func aspectFit(in boundingRect: CGRect) -> CGRect {
        let fittingSize = size.fitting(in: boundingRect.size)
        let origin = CGPoint(
            x: boundingRect.midX - fittingSize.width / 2,
            y: boundingRect.midY - fittingSize.height / 2
        )
        return CGRect(origin: origin, size: fittingSize)
    }
}

extension Notification.Name {
    static func memory(_ name: String) -> Notification.Name {
        return Notification.Name("Memory\(name)")
    }

    static func person(_ name: String) -> Notification.Name {
        return Notification.Name("Person\(name)")
    }

    static func sync(_ name: String) -> Notification.Name {
        return Notification.Name("Sync\(name)")
    }
}

extension NSObject {
    func log(_ message: String, level: Constants.Debug.LogLevel = .info) {
        if Constants.Debug.enableLogging {
            print("\(level.rawValue) [\(String(describing: type(of: self)))] \(message)")
        }
    }

    func logError(_ error: Error, context: String = "") {
        log("❌ \(context.isEmpty ? "" : "\(context): ")\(error.localizedDescription)", level: .error)
    }

    func logNetwork(_ message: String) {
        if Constants.Debug.enableNetworkLogging {
            log("🌐 \(message)", level: .debug)
        }
    }
}

class Haptics {
    static let shared = Haptics()
    private init() { }

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    func light() {
        lightGenerator.impactOccurred()
    }

    func medium() {
        mediumGenerator.impactOccurred()
    }

    func heavy() {
        heavyGenerator.impactOccurred()
    }

    func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    func error() {
        notificationGenerator.notificationOccurred(.error)
    }

    func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }
}
