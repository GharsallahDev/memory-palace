import Foundation

struct Person: Identifiable, Hashable {
    let id: UUID
    var name: String
    var relationship: String?
    let createdAt: Date
    var lastSeenAt: Date
    
    var avatarUrl: String?
    
    var serverId: Int?
    var isPrimary: Bool

    init(name: String, relationship: String? = nil) {
        self.id = UUID()
        self.name = name
        self.relationship = relationship
        self.createdAt = Date()
        self.lastSeenAt = Date()
        self.avatarUrl = nil
        self.serverId = nil
        self.isPrimary = false
    }
    
    init(from serverPerson: ServerPerson) {
        self.id = UUID()
        self.serverId = serverPerson.id
        self.name = serverPerson.name
        self.relationship = serverPerson.relationship
        self.createdAt = serverPerson.createdAt
        self.lastSeenAt = serverPerson.lastSeenAt
        self.avatarUrl = serverPerson.avatarUrl
        self.isPrimary = serverPerson.isPrimary ?? false
    }
}


struct ServerPerson: Codable {
    let id: Int
    let name: String
    let relationship: String?
    let createdAt: Date
    let lastSeenAt: Date
    let avatarUrl: String?
    let isPrimary: Bool?
    
    var asPerson: Person {
        return Person(from: self)
    }
}

struct PersonResponse: Codable {
    let success: Bool
    let people: [ServerPerson]?
    let person: ServerPerson?
    let message: String?
}
