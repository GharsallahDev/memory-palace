import Foundation
import UIKit

struct Constants {
        
    struct App {
        static let name = "Memory Palace"
        static let version = "1.0.0"
        static let buildNumber = "1"
        static let bundleId = "com.memorypalace.ios"
        
        static let faceDetectionEnabled = true
        static let voiceRecognitionEnabled = true
        static let offlineModeEnabled = true
        static let debugMode = false
    }
        
    struct Server {
        static let defaultPort = 3000
        static let connectionTimeout: TimeInterval = 30.0
        static let uploadTimeout: TimeInterval = 120.0
        static let syncInterval: TimeInterval = 10.0
        
        static let healthEndpoint = "/health"
        static let memoriesEndpoint = "/api/memories"
        static let peopleEndpoint = "/api/people"
        static let authEndpoint = "/api/auth"
        static let faceTagsEndpoint = "/api/face-tags"
        static let chatEndpoint = "/api/chat"
    }
        
    struct Files {
        static let maxPhotoSize: Int64 = 50 * 1024 * 1024
        static let maxVoiceSize: Int64 = 100 * 1024 * 1024
        static let maxPhotosPerUpload = 10
        static let compressionQuality: CGFloat = 0.8
        
        static let supportedImageFormats = ["jpg", "jpeg", "png", "heic", "heif"]
        static let supportedAudioFormats = ["m4a", "mp3", "wav", "aac"]
    }
        
    struct FaceDetection {
        static let minFaceSize: Float = 0.05
        static let maxFacesPerPhoto = 20
        static let confidenceThreshold: Float = 0.5
        static let detectionTimeout: TimeInterval = 30.0
        
        static let faceBoxColor = UIColor.systemBlue
        static let selectedFaceBoxColor = UIColor.systemYellow
        static let untaggedFaceBoxColor = UIColor.systemOrange
        static let faceBoxLineWidth: CGFloat = 2.0
    }
    
    
    struct Audio {
        static let sampleRate: Double = 44100
        static let bitRate = 128000
        static let channels = 2
        static let maxRecordingDuration: TimeInterval = 600
        static let format = "m4a"
        
        static let levelUpdateInterval: TimeInterval = 0.05
        static let timeUpdateInterval: TimeInterval = 0.1
    }
        
    struct UI {
        static let primaryColor = UIColor.systemBlue
        static let secondaryColor = UIColor.systemGray
        static let accentColor = UIColor.systemOrange
        static let errorColor = UIColor.systemRed
        static let successColor = UIColor.systemGreen
        
        static let smallSpacing: CGFloat = 8
        static let mediumSpacing: CGFloat = 16
        static let largeSpacing: CGFloat = 24
        static let extraLargeSpacing: CGFloat = 32
        
        static let smallCornerRadius: CGFloat = 8
        static let mediumCornerRadius: CGFloat = 12
        static let largeCornerRadius: CGFloat = 16
        
        static let shortAnimation: TimeInterval = 0.2
        static let mediumAnimation: TimeInterval = 0.3
        static let longAnimation: TimeInterval = 0.5
        
        static let memoryGridColumns = 2
        static let memoryCardAspectRatio: CGFloat = 1.2
        static let memoryCardSpacing: CGFloat = 12
    }
        
    struct Network {
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 2.0
        static let backgroundTaskTimeout: TimeInterval = 30.0
        
        static let authHeaderName = "x-auth-token"
        static let userAgentHeaderName = "User-Agent"
        static let contentTypeHeaderName = "Content-Type"
        
        static let jsonContentType = "application/json"
        static let multipartContentType = "multipart/form-data"
    }
        
    struct StorageKeys {
        static let serverConfig = "ServerConfig"
        static let savedPeople = "SavedPeople"
        static let userPreferences = "UserPreferences"
        static let lastSyncTime = "LastSyncTime"
        static let appLaunchCount = "AppLaunchCount"
        static let firstLaunchDate = "FirstLaunchDate"
        static let debugEnabled = "DebugEnabled"
    }
        
    struct Validation {
        static let minTitleLength = 1
        static let maxTitleLength = 200
        static let maxDescriptionLength = 1000
        static let maxPersonNameLength = 100
        static let minPersonNameLength = 1
        
        static let personNamePattern = "^[a-zA-Z\\s\\-']{1,100}$"
        static let ipAddressPattern = "^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$"
    }
        
    struct Accessibility {
        static let minimumTouchTarget: CGFloat = 44
        static let voiceOverEnabled = UIAccessibility.isVoiceOverRunning
        static let reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        static let largeTextEnabled = UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
    }
        
    struct Debug {
        static let enableLogging = true
        static let enableNetworkLogging = false
        static let enableFaceDetectionLogging = true
        static let enableAudioLogging = false
        
        enum LogLevel: String {
            case debug = "🔍 DEBUG"
            case info = "ℹ️ INFO"
            case warning = "⚠️ WARNING"
            case error = "❌ ERROR"
        }
    }
        
    struct Notifications {
        static let syncCompleted = Notification.Name("SyncCompleted")
        static let connectionStatusChanged = Notification.Name("ConnectionStatusChanged")
        static let memoryUploaded = Notification.Name("MemoryUploaded")
        static let personAdded = Notification.Name("PersonAdded")
        static let faceDetectionCompleted = Notification.Name("FaceDetectionCompleted")
        static let audioRecordingStarted = Notification.Name("AudioRecordingStarted")
        static let audioRecordingStopped = Notification.Name("AudioRecordingStopped")
    }
        
    struct ErrorMessages {
        static let noInternetConnection = "No internet connection available"
        static let serverUnreachable = "Unable to connect to memories hub"
        static let authenticationFailed = "Authentication failed"
        static let fileUploadFailed = "Failed to upload file"
        static let faceDetectionFailed = "Face detection failed"
        static let audioRecordingFailed = "Audio recording failed"
        static let invalidQRCode = "Invalid QR code"
        static let permissionDenied = "Permission denied"
        static let unknownError = "An unknown error occurred"
    }
        
    struct SuccessMessages {
        static let connectionEstablished = "Connected to memories hub"
        static let memoryUploaded = "Memory added to memory collection"
        static let syncCompleted = "Sync completed successfully"
        static let faceDetectionCompleted = "Face detection completed"
        static let audioRecordingCompleted = "Audio recording completed"
        static let personAdded = "Person added"
    }
        
    static var userAgent: String {
        return "\(App.name)/\(App.version) (iOS \(UIDevice.current.systemVersion); \(UIDevice.current.model))"
    }
    
    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var deviceName: String {
        return UIDevice.current.name
    }
    
    static var deviceModel: String {
        return UIDevice.current.model
    }
    
    static var systemVersion: String {
        return UIDevice.current.systemVersion
    }
}

extension Constants {
    
    struct Development {
        static let defaultServerIP = "192.168.1.100"
        static let enableMockData = true
        static let skipAuthentication = false
        static let verboseLogging = true
    }
    
    struct Production {
        static let enableMockData = false
        static let skipAuthentication = false
        static let verboseLogging = false
        static let crashReportingEnabled = true
    }
    
    static var current: (serverIP: String, mockData: Bool, verboseLogging: Bool) {
        if isDebugBuild {
            return (
                serverIP: Development.defaultServerIP,
                mockData: Development.enableMockData,
                verboseLogging: Development.verboseLogging
            )
        } else {
            return (
                serverIP: "",
                mockData: Production.enableMockData,
                verboseLogging: Production.verboseLogging
            )
        }
    }
}
