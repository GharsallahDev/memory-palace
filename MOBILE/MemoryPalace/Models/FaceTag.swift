import Foundation
import Vision

struct FaceTag: Identifiable, Codable {
    var id: UUID
    var memoryId: UUID
    var personId: UUID?
    var personServerId: Int?
    var personName: String?
    var boundingBox: FaceBoundingBox
    var confidence: Float
    var detectedAt: Date
    var taggedAt: Date?
    var serverId: String?
    var isManual: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, memoryId, personServerId, personName, boundingBox, confidence, detectedAt, taggedAt, isManual
    }
    
    init(memoryId: UUID, observation: VNFaceObservation) {
        self.id = UUID()
        self.memoryId = memoryId
        self.personId = nil
        self.personServerId = nil
        self.personName = nil
        self.boundingBox = FaceBoundingBox(from: observation)
        self.confidence = observation.confidence
        self.detectedAt = Date()
        self.taggedAt = nil
        self.serverId = nil
        self.isManual = false
    }
    
    init(memoryId: UUID, boundingBox: FaceBoundingBox, isManual: Bool) {
        self.id = UUID()
        self.memoryId = memoryId
        self.personId = nil
        self.personServerId = nil
        self.personName = nil
        self.boundingBox = boundingBox
        self.confidence = 1.0
        self.detectedAt = Date()
        self.taggedAt = nil
        self.serverId = nil
        self.isManual = isManual
    }
    
    mutating func tagPerson(_ person: Person) {
        self.personId = person.id
        self.personServerId = person.serverId
        self.personName = person.name
        self.taggedAt = Date()
    }
    
    var isTagged: Bool {
        return personId != nil || (personName != nil && !personName!.isEmpty)
    }
}

struct FaceBoundingBox: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    
    init(from observation: VNFaceObservation) {
        self.x = Double(observation.boundingBox.origin.x)
        self.y = 1.0 - Double(observation.boundingBox.origin.y + observation.boundingBox.height)
        self.width = Double(observation.boundingBox.width)
        self.height = Double(observation.boundingBox.height)
    }
    
    init(from rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.width
        self.height = rect.height
    }
}

struct ServerFaceTag: Codable {
    let id: String
    let personId: Int?
    let personName: String?
    let boundingBox: FaceBoundingBox
    let confidence: Float
    let detectedAt: String
    let taggedAt: String?

    func asFaceTag(localMemoryId: UUID) -> FaceTag {
        let dummyObservation = VNFaceObservation()
        var newFaceTag = FaceTag(memoryId: localMemoryId, observation: dummyObservation)

        if let uuid = UUID(uuidString: id) {
             newFaceTag.id = uuid
        }
        
        newFaceTag.memoryId = localMemoryId
        newFaceTag.personName = self.personName
        newFaceTag.personServerId = self.personId
        newFaceTag.boundingBox = self.boundingBox
        newFaceTag.confidence = self.confidence
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: self.detectedAt) {
            newFaceTag.detectedAt = date
        }
        
        if let taggedAtString = self.taggedAt, let date = formatter.date(from: taggedAtString) {
            newFaceTag.taggedAt = date
        }
        
        newFaceTag.serverId = self.id
        
        return newFaceTag
    }
}
