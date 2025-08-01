import Foundation
import SwiftUI

enum MemoryType: String, Codable {
    case photo = "photo"
    case voice = "voice"
    case video = "video"
    case text = "text"
}

class Memory: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var title: String
    @Published var description: String
    @Published var content: String
    let type: MemoryType
    let timestamp: Date
    @Published var metadata: MemoryMetadata
    let deviceName: String
    @Published var imageUrl: String?
    @Published var audioUrl: String?
    @Published var videoUrl: String?
    @Published var thumbnailUrl: String?
    @Published var faceTags: [FaceTag]
    @Published var faceDetectionCompleted: Bool
    var serverId: Int
    @Published var needsSync: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, description, content, type, timestamp, metadata, deviceName
        case imageUrl, audioUrl, videoUrl, thumbnailUrl, faceTags, faceDetectionCompleted, serverId, needsSync
    }
    
    // Computed property to safely select the correct date for display
    var displayDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // Prioritize the user-provided date
        if !metadata.whenWasThis.isEmpty, let date = formatter.date(from: metadata.whenWasThis) {
            return date
        }
        // Fallback to the creation timestamp if 'whenWasThis' is absent or invalid
        return timestamp
    }

    init(serverId: Int, title: String, description: String, content: String, type: MemoryType,
         timestamp: Date, metadata: MemoryMetadata, deviceName: String,
         imageUrl: String? = nil, audioUrl: String? = nil, videoUrl: String? = nil, thumbnailUrl: String? = nil) {
        self.id = UUID()
        self.serverId = serverId
        self.title = title
        self.description = description
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.metadata = metadata
        self.deviceName = deviceName
        self.imageUrl = imageUrl
        self.audioUrl = audioUrl
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.faceTags = []
        self.faceDetectionCompleted = type != .photo
        self.needsSync = false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(content, forKey: .content)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(deviceName, forKey: .deviceName)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(audioUrl, forKey: .audioUrl)
        try container.encodeIfPresent(videoUrl, forKey: .videoUrl)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encode(faceTags, forKey: .faceTags)
        try container.encode(faceDetectionCompleted, forKey: .faceDetectionCompleted)
        try container.encode(serverId, forKey: .serverId)
        try container.encode(needsSync, forKey: .needsSync)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        content = try container.decode(String.self, forKey: .content)
        type = try container.decode(MemoryType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        metadata = try container.decode(MemoryMetadata.self, forKey: .metadata)
        deviceName = try container.decode(String.self, forKey: .deviceName)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        audioUrl = try container.decodeIfPresent(String.self, forKey: .audioUrl)
        videoUrl = try container.decodeIfPresent(String.self, forKey: .videoUrl)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        faceTags = try container.decode([FaceTag].self, forKey: .faceTags)
        faceDetectionCompleted = try container.decode(Bool.self, forKey: .faceDetectionCompleted)
        serverId = try container.decode(Int.self, forKey: .serverId)
        needsSync = try container.decode(Bool.self, forKey: .needsSync)
    }

    func addFaceTags(_ tags: [FaceTag]) {
        self.faceTags = tags
        self.faceDetectionCompleted = true
    }

    func updateFaceTag(at index: Int, with person: Person) {
        guard index < faceTags.count else { return }
        faceTags[index].tagPerson(person)
    }

    func markSynced(serverId: Int) {
        self.serverId = serverId
        self.needsSync = false
    }

    var hasUntaggedFaces: Bool { faceTags.contains { !$0.isTagged } }
    var taggedPeople: [String] { faceTags.compactMap { $0.personName } }
    var detectedFaceCount: Int { faceTags.count }
    var previewImagePath: String? { return thumbnailUrl ?? imageUrl }
    var audioFilePath: String? { return audioUrl }
}

struct MemoryMetadata: Codable {
    let whoWasThere: String
    let whenWasThis: String
    let whereWasThis: String
    let context: String
    let duration: TimeInterval?
    let photoCount: Int?
    var detectedPeople: [String] { whoWasThere.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
}

struct FamilyMemory: Identifiable, Codable {
    let id: Int
    let type: String
    let title: String
    let description: String
    let content: String?
    let whoWasThere: String?
    let whenWasThis: String?
    let whereWasThis: String?
    let context: String?
    let duration: Double?
    let timestamp: String
    let deviceName: String
    let imageFile: String?
    let audioFile: String?
    let videoFile: String?
    let thumbnailFile: String?
    let imageUrl: String?
    let audioUrl: String?
    let videoUrl: String?
    let thumbnailUrl: String?
    let faceTags: [ServerFaceTag]?

    var asMemory: Memory {
        let memory = Memory(
            serverId: id,
            title: title,
            description: description,
            content: content ?? "",
            type: MemoryType(rawValue: type) ?? .photo,
            // Use the robust parser and a safe fallback to prevent crashes or incorrect dates.
            // `Date.distantPast` makes errors obvious if they occur.
            timestamp: DateParser.fromISO8601(timestamp) ?? Date.distantPast,
            metadata: MemoryMetadata(
                whoWasThere: whoWasThere ?? "",
                whenWasThis: whenWasThis ?? "",
                whereWasThis: whereWasThis ?? "",
                context: context ?? description,
                duration: duration,
                photoCount: nil
            ),
            deviceName: deviceName,
            imageUrl: imageUrl,
            audioUrl: audioUrl,
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl
        )
        if let serverFaceTags = self.faceTags, !serverFaceTags.isEmpty {
            let localFaceTags = serverFaceTags.map { $0.asFaceTag(localMemoryId: memory.id) }
            memory.addFaceTags(localFaceTags)
        }
        return memory
    }
}

struct ServerResponse: Codable {
    let success: Bool
    let memories: [FamilyMemory]?
    let memory: FamilyMemory?
    let message: String?
    let totalMemories: Int?
}
