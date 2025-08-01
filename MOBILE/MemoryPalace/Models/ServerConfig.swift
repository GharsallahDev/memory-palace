import Foundation

struct ServerConfig: Codable, Identifiable {
    let id = UUID()
    let serverIP: String
    let port: Int
    let authToken: String
    
    var baseURL: String {
        return "http://\(serverIP):\(port)"
    }
    
    var healthURL: String {
        return "\(baseURL)/health"
    }
    
    var memoriesURL: String {
        return "\(baseURL)/api/memories"
    }
    
    var peopleURL: String {
        return "\(baseURL)/api/people"
    }
    
    var authURL: String {
        return "\(baseURL)/api/auth"
    }
    
    var uploadsURL: String {
        return "\(baseURL)/uploads"
    }
    
    var isValid: Bool {
        return !serverIP.isEmpty && 
               port > 0 && port < 65536 && 
               !authToken.isEmpty &&
               serverIP.isValidIPAddress
    }
    
    var displayString: String {
        return "\(serverIP):\(port)"
    }
    
    var maskedToken: String {
        return String(authToken.prefix(8)) + "..."
    }
    
    init(serverIP: String, port: Int, authToken: String) {
        self.serverIP = serverIP
        self.port = port
        self.authToken = authToken
    }
    
    init?(from qrData: String) {
        guard let data = qrData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
            return nil
        }
        
        self.serverIP = decoded.serverIP
        self.port = decoded.port
        self.authToken = decoded.authToken
        
        guard isValid else {
            return nil
        }
    }
    
    static let storageKey = Constants.StorageKeys.serverConfig
    
    func save() {
        UserDefaults.standard.setObject(self, forKey: Self.storageKey)
    }
    
    static func load() -> ServerConfig? {
        return UserDefaults.standard.getObject(ServerConfig.self, forKey: storageKey)
    }
    
    static func delete() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    
    static func == (lhs: ServerConfig, rhs: ServerConfig) -> Bool {
        return lhs.serverIP == rhs.serverIP &&
               lhs.port == rhs.port &&
               lhs.authToken == rhs.authToken
    }
}

extension ServerConfig {
    
    enum ValidationError: LocalizedError {
        case invalidIP
        case invalidPort
        case emptyToken
        case invalidFormat
        
        var errorDescription: String? {
            switch self {
            case .invalidIP:
                return "Invalid IP address format"
            case .invalidPort:
                return "Port must be between 1 and 65535"
            case .emptyToken:
                return "Authentication token cannot be empty"
            case .invalidFormat:
                return "Invalid server configuration format"
            }
        }
    }
    
    func validate() throws {
        if !serverIP.isValidIPAddress {
            throw ValidationError.invalidIP
        }
        
        if port <= 0 || port >= 65536 {
            throw ValidationError.invalidPort
        }
        
        if authToken.isEmpty {
            throw ValidationError.emptyToken
        }
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        do {
            try validate()
        } catch {
            if let validationError = error as? ValidationError {
                errors.append(validationError.localizedDescription)
            } else {
                errors.append(error.localizedDescription)
            }
        }
        
        return errors
    }
}

extension ServerConfig {
    
    func testConnection() async -> (success: Bool, message: String) {
        guard isValid else {
            return (false, "Invalid server configuration")
        }
        
        guard let url = URL(string: healthURL) else {
            return (false, "Invalid server URL")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                
                if let responseData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = responseData["status"] as? String {
                    return (true, status)
                } else {
                    return (true, "Connected to server")
                }
            } else {
                return (false, "Server not responding")
            }
        } catch {
            return (false, "Connection failed: \(error.localizedDescription)")
        }
    }
    
    func createAuthenticatedRequest(for url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(authToken, forHTTPHeaderField: Constants.Network.authHeaderName)
        request.setValue(Constants.userAgent, forHTTPHeaderField: Constants.Network.userAgentHeaderName)
        request.timeoutInterval = Constants.Server.connectionTimeout
        
        return request
    }
}

extension ServerConfig {
    
    static var preview: ServerConfig {
        return ServerConfig(
            serverIP: "192.168.1.100",
            port: 3000,
            authToken: "preview_token_123456789"
        )
    }
    
    static var localhost: ServerConfig {
        return ServerConfig(
            serverIP: "127.0.0.1",
            port: 3000,
            authToken: "localhost_token"
        )
    }
}

extension ServerConfig: CustomStringConvertible {
    var description: String {
        return "ServerConfig(ip: \(serverIP), port: \(port), token: \(maskedToken))"
    }
}
