import Foundation
import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

enum UploadResult {
    case success(Person)
    case alreadyExists
    case failure
}

@MainActor
class NetworkManager: ObservableObject {
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var statusMessage = ""
    @Published var lastSyncTime: Date?
    
    public var serverConfig: ServerConfig?
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 300.0
        self.session = URLSession(configuration: config)
    }
    
    func updateServerConfig(_ config: ServerConfig) {
        self.serverConfig = config
    }
    
    private func createAuthenticatedRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = serverConfig?.authToken {
            request.setValue(token, forHTTPHeaderField: "x-auth-token")
        }
        return request
    }
    
    func reset() {
        serverConfig = nil
        isConnected = false
        isLoading = false
        statusMessage = ""
        lastSyncTime = nil
        ServerConfig.delete()
    }
    
    func testConnection() async -> Bool {
        guard let config = serverConfig else {
            statusMessage = "No server configuration"; return false
        }
        isLoading = true
        statusMessage = "Testing connection..."
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/health") else {
            statusMessage = "Invalid server URL"; isLoading = false; return false
        }
        do {
            let (_, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                statusMessage = "✅ Connected to memories hub!"; isConnected = true; isLoading = false; return true
            } else {
                statusMessage = "Hub not responding. Check the IP and port."; isConnected = false; isLoading = false; return false
            }
        } catch {
            statusMessage = "Connection failed: \(error.localizedDescription)"; isConnected = false; isLoading = false; return false
        }
    }
    
    func getAllMemories() async -> [Memory] {
        guard let config = serverConfig else { return [] }
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/api/memories") else { return [] }
        let request = createAuthenticatedRequest(url: url)
        
        do {
            let (data, _) = try await session.data(for: request)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
            
            let serverResponse = try decoder.decode(ServerResponse.self, from: data)
            
            if let memories = serverResponse.memories {
                return memories.map { $0.asMemory }
            } else {
                return []
            }
            
        } catch {
            print("❌ DEBUG: getAllMemories failed: \(error)")
            return []
        }
    }
    
    func getMemoriesForPerson(personId: Int) async -> [Memory] {
        guard let config = serverConfig else { return [] }
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/api/people/\(personId)/memories") else { return [] }
        let request = createAuthenticatedRequest(url: url)

        do {
            let (data, _) = try await session.data(for: request)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
            let serverResponse = try decoder.decode(ServerResponse.self, from: data)
            return serverResponse.memories?.map { $0.asMemory } ?? []
        } catch {
            print("❌ DEBUG: getMemoriesForPerson failed: \(error)")
            return []
        }
    }
    
    func uploadPhotoMemory(photos: [PhotosPickerItem], title: String, description: String, peopleIds: [Int], whenWasThis: String, whereWasThis: String, faceTags: [FaceTag] = []) async -> Bool {
        guard let config = serverConfig, let photo = photos.first else { return false }
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/api/memories/photo") else { return false }
        
        do {
            guard let imageData = try await photo.loadTransferable(type: Data.self) else {
                self.statusMessage = "Could not load image data from the selected photo."
                return false
            }
            
            let boundary = UUID().uuidString
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue(config.authToken, forHTTPHeaderField: "x-auth-token")

            var body = Data()
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)

            var metadata: [String: String] = ["title": title, "description": description, "whenWasThis": whenWasThis, "whereWasThis": whereWasThis, "deviceName": UIDevice.current.name]
            
            let encoder = JSONEncoder()
            if !peopleIds.isEmpty, let peopleData = try? encoder.encode(peopleIds), let peopleString = String(data: peopleData, encoding: .utf8) {
                metadata["peopleIds"] = peopleString
            }
            if !faceTags.isEmpty {
                encoder.dateEncodingStrategy = .iso8601
                if let tagsData = try? encoder.encode(faceTags), let tagsString = String(data: tagsData, encoding: .utf8) {
                    metadata["faceTags"] = tagsString
                }
            }
            
            for (key, value) in metadata {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append(value.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }
            
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            let (_, response) = try await session.upload(for: request, from: body)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                self.statusMessage = "Photo uploaded successfully!"
                return true
            } else {
                self.statusMessage = "Photo upload failed. Server responded with an error."
                return false
            }
        } catch {
            self.statusMessage = "Photo upload failed: \(error.localizedDescription)"
            print("❌ Photo upload failed: \(error)");
            return false
        }
    }
    
    func uploadVideoMemory(videoItem: PhotosPickerItem, title: String, description: String, peopleIds: [Int], whenWasThis: String, whereWasThis: String) async -> Bool {
        guard let config = serverConfig else { return false }
        isLoading = true;
        
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/api/memories/video") else {
            isLoading = false; return false
        }
        
        do {
            guard let videoData = try await videoItem.loadTransferable(type: Data.self) else {
                isLoading = false; return false
            }
            
            let boundary = UUID().uuidString
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue(config.authToken, forHTTPHeaderField: "x-auth-token")
            
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"video\"; filename=\"video.mov\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: video/quicktime\r\n\r\n".data(using: .utf8)!)
            body.append(videoData)
            body.append("\r\n".data(using: .utf8)!)
            
            var metadata: [String: String] = [
                "title": title, "description": description,
                "whenWasThis": whenWasThis, "whereWasThis": whereWasThis,
                "deviceName": UIDevice.current.name
            ]

            if let peopleData = try? JSONEncoder().encode(peopleIds), let peopleString = String(data: peopleData, encoding: .utf8) {
                metadata["peopleIds"] = peopleString
            }
            
            for (key, value) in metadata {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append(value.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }
            
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            let (_, response) = try await session.upload(for: request, from: body)
            isLoading = false;
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                self.statusMessage = "Video uploaded successfully!"
                return true
            } else {
                self.statusMessage = "Video upload failed. Server responded with an error."
                return false
            }
        } catch {
            self.statusMessage = "Video upload failed: \(error.localizedDescription)"
            print("❌ Video upload failed: \(error)");
            isLoading = false;
            return false
        }
    }
    
    func uploadTextMemory(title: String, content: String, peopleIds: [Int], whenWasThis: String, whereWasThis: String) async -> Bool {
        guard let config = serverConfig else { return false }
        isLoading = true
        
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/api/memories/text") else {
            isLoading = false; return false
        }
        
        var request = createAuthenticatedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "title": title, "content": content, "peopleIds": peopleIds,
            "whenWasThis": whenWasThis, "whereWasThis": whereWasThis,
            "deviceName": UIDevice.current.name
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            let (_, response) = try await session.data(for: request)
            isLoading = false
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                self.statusMessage = "Note uploaded successfully!"
                return true
            } else {
                self.statusMessage = "Note upload failed. Server responded with an error."
                return false
            }
        } catch {
            self.statusMessage = "Note upload failed: \(error.localizedDescription)"
            print("❌ Note upload failed: \(error)");
            isLoading = false;
            return false
        }
    }
    
    func uploadVoiceMemory(audioData: Data, title: String, context: String, duration: TimeInterval, peopleIds: [Int], whenWasThis: String, whereWasThis: String) async -> Bool {
        guard let config = serverConfig else { return false }
        
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/api/memories/voice") else { return false }
        
        isLoading = true
        
        do {
            let boundary = UUID().uuidString
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue(config.authToken, forHTTPHeaderField: "x-auth-token")
            
            var body = Data()
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"voice\"; filename=\"voice.m4a\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
            
            var metadata: [String: String] = [
                "title": title, "context": context, "duration": String(duration),
                "deviceName": UIDevice.current.name,
                "whenWasThis": whenWasThis,
                "whereWasThis": whereWasThis
            ]

            if let peopleData = try? JSONEncoder().encode(peopleIds), let peopleString = String(data: peopleData, encoding: .utf8) {
                metadata["peopleIds"] = peopleString
            }
            
            for (key, value) in metadata {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append(value.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }
            
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            let (_, response) = try await session.upload(for: request, from: body)
            isLoading = false
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                self.statusMessage = "Voice story uploaded successfully!"
                return true
            } else {
                self.statusMessage = "Voice story upload failed. Server responded with an error."
                return false
            }
        } catch {
            self.statusMessage = "Voice story upload failed: \(error.localizedDescription)"
            print("❌ Voice upload failed: \(error)");
            isLoading = false;
            return false
        }
    }
    
    func uploadPerson(name: String, relationship: String?) async -> UploadResult {
        guard let config = serverConfig else { return .failure }
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/api/people") else { return .failure }
        var request = createAuthenticatedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let personData: [String: Any?] = ["name": name, "relationship": relationship, "deviceName": UIDevice.current.name]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: personData.compactMapValues { $0 })
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
                
                if httpResponse.statusCode == 201,
                   let serverResponse = try? decoder.decode(PersonResponse.self, from: data),
                   let serverPerson = serverResponse.person {
                    self.statusMessage = "Successfully added \(serverPerson.name)."
                    return .success(serverPerson.asPerson)
                } else if httpResponse.statusCode == 409 {
                    self.statusMessage = "'\(name)' already exists."
                    return .alreadyExists
                }
            }
            self.statusMessage = "Failed to add person due to a server error."
            return .failure
        } catch {
            self.statusMessage = "Failed to add person: \(error.localizedDescription)"
            print("❌ Person upload failed: \(error)");
            return .failure
        }
    }

    func deletePerson(personId: Int) async -> Bool {
        guard let config = serverConfig else { return false }
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/api/people/\(personId)") else { return false }
        let request = createAuthenticatedRequest(url: url, method: "DELETE")
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("❌ Delete person failed: \(error)"); return false
        }
    }
    
    func updatePerson(personId: Int, name: String, relationship: String?) async -> Bool {
        guard let config = serverConfig else { return false }
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/api/people/\(personId)") else { return false }
        
        var request = createAuthenticatedRequest(url: url, method: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let updateData: [String: Any?] = [ "name": name, "relationship": relationship ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData.compactMapValues { $0 })
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("❌ Update person failed: \(error)")
            return false
        }
    }
    
    func getAllPeople() async -> [Person] {
        guard let config = serverConfig else { return [] }
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/api/people") else { return [] }
        let request = createAuthenticatedRequest(url: url)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
                
                let personResponse = try decoder.decode(PersonResponse.self, from: data)
                
                if personResponse.success, let serverPeople = personResponse.people {
                    return serverPeople.map { $0.asPerson }
                } else {
                    return []
                }
            } else {
                return []
            }
        } catch {
            print("❌ FAILED TO DECODE PEOPLE: \(error)")
            return []
        }
    }
    
    func updateMemory(memoryId: Int, updateData: [String: String]) async -> Bool {
        guard let config = serverConfig else { return false }
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/api/memories/\(memoryId)") else { return false }
        
        var request = createAuthenticatedRequest(url: url, method: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData, options: [])
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("❌ Update memory failed: \(error)")
            return false
        }
    }

    func deleteMemory(_ memoryId: Int) async -> Bool {
        guard let config = serverConfig else { return false }
        guard let url = URL(string: "http://\(config.serverIP):\(config.port)/api/memories/\(memoryId)") else { return false }
        
        let request = createAuthenticatedRequest(url: url, method: "DELETE")
        
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("❌ Delete memory failed: \(error)")
            return false
        }
    }
}

extension JSONDecoder.DateDecodingStrategy {
    static let iso8601WithFractionalSeconds = custom { decoder -> Date in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        let formatter = ISO8601DateFormatter()
        
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString) is not a valid ISO8601 date format.")
    }
}
