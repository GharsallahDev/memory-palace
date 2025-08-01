# iOS Mobile App - Memory Palace Family Collector

**Native Swift application enabling family members to capture and contribute memories to the shared collection.**

## 🎯 Overview

The iOS Mobile App serves as the primary memory collection tool for Memory Palace, allowing family members to capture, enrich, and upload photos, videos, voice recordings, and text memories to the shared family hub. Built with SwiftUI and featuring on-device AI capabilities, it transforms mobile devices into powerful memory collection tools.

## ✨ Key Features

- **📷 Multi-Modal Capture**: Upload photos, videos, voice recordings, and text notes.
- **🧠 On-Device AI**: Face detection using Apple's Vision framework to identify faces in photos locally.
- **👥 People Management**: Add, view, and manage family members, and tag them in memories.
- **📊 Rich Metadata**: Add titles, descriptions, dates, locations, and context for each memory.
- **🔗 Seamless Integration**: Simple QR code scanning for initial server setup.
- **🔒 Privacy-First**: Face detection happens on-device; no facial data is sent to the cloud.
- **🔄 Event-Driven Sync**: Refresh memory and people lists manually or after new uploads.

## 🏗️ Architecture

### Technology Stack

- **SwiftUI**: Modern, declarative UI framework for building the app's interface.
- **Swift 5.7+**: Utilizes modern concurrency features like `async/await`.
- **Vision Framework**: Powers on-device face detection for photos.
- **AVFoundation**: Used for audio recording/playback and QR code scanning.
- **PhotosUI**: Modern and secure integration with the user's photo library.

### Manager-Based Architecture

The app is structured around a set of managers that handle specific domains of functionality, promoting a clean and scalable architecture.

```
MemoryPalace/
├── Managers/
│   ├── NetworkManager.swift          # Handles all backend API communication.
│   ├── PersonManager.swift           # Manages local state for people.
│   ├── FaceDetectionManager.swift    # Wraps the Vision framework for on-device AI.
│   └── AudioManager.swift            # Manages voice recording and playback.
├── Models/
│   ├── Memory.swift                  # Data models for memories, including server mapping.
│   ├── Person.swift                  # Data models for people, including server mapping.
│   ├── FaceTag.swift                 # Represents a detected face and its tag.
│   └── ServerConfig.swift            # Stores hub connection configuration.
├── Views/
│   ├── Setup/
│   │   ├── SetupView.swift           # Initial onboarding and feature explanation.
│   │   └── QRScannerView.swift       # Camera view for hub connection setup.
│   ├── Upload/
│   │   ├── PhotoUploadView.swift     # Multi-step photo upload flow.
│   │   ├── VideoUploadView.swift     # Multi-step video upload flow.
│   │   ├── VoiceRecorderView.swift   # Voice recording and upload flow.
│   │   └── TextUploadView.swift      # Text note creation and upload flow.
│   ├── Browse/
│   │   ├── MemoryListView.swift      # Main browser for all memories.
│   │   ├── MemoryDetailView.swift    # Detailed view of a single memory.
│   │   ├── PersonListView.swift      # List of all people in the hub.
│   │   └── PersonDetailView.swift    # Profile view for a person and their memories.
│   ├── Settings/
│   │   └── SettingsView.swift        # App configuration and data management.
│   └── Shared/
│       ├── FlexibleView.swift        # A view for creating tag-like layouts.
│       └── PersonMultiSelectorView.swift # Reusable component for selecting people.
└── Utils/
    ├── Constants.swift               # App-wide constants and static values.
    └── Extensions.swift              # Utility extensions for various Swift types.
```

## 🚀 Quick Start

### Prerequisites

- **iOS 16.0+** (for latest SwiftUI features)
- **Xcode 15.0+** (for Swift 5.7+ support)
- **Active Memory Palace Hub** (Backend + AI services running on the local network)

### Installation

```bash
# Clone the repository
git clone https://github.com/YourUsername/memory-palace.git
cd memory-palace/MOBILE/

# Open in Xcode
open MemoryPalace.xcodeproj
```

### Configuration

1.  **Backend Hub Setup**: Ensure your Memory Palace Hub is running and accessible on your local network.
2.  **QR Code Generation**: Access your hub's dashboard to display the setup QR code.
3.  **iOS App Build**: Build and run the `MemoryCollectorApp` target on your iOS device or simulator.

### First-Time Setup

1.  **Launch App**: First-time users are greeted with the `SetupView`.
2.  **QR Code Scan**: Scan the QR code from the Memory Palace Hub dashboard.
3.  **Automatic Configuration**: The app parses the QR code to configure the server IP, port, and auth token.
4.  **Connection Test**: The app automatically verifies connectivity to the hub.
5.  **Ready to Collect**: Once connected, the main interface appears, ready for memory collection.

## 📱 Core Features

### Multi-Modal Memory Capture

#### Photo Memories

The photo upload process is a guided, multi-step workflow that includes on-device face detection.

```swift
// In PhotoUploadView.swift
enum UploadStep {
    case selectPhotos
    case addMetadata
    case tagFaces
}

private func startFaceDetection() {
    Task {
        guard let image = selectedImage else { return }
        // The FaceDetectionManager is used to find faces in the selected image.
        let faces = await faceDetectionManager.detectFaces(in: image)
        // The results are converted into FaceTag models for the tagging UI.
        let faceTags = faces.map { FaceTag(memoryId: UUID(), observation: $0) }
        await MainActor.run { self.detectedFaceTags = faceTags }
    }
}
```

**Photo Capture Flow:**

1.  **Source Selection**: Select a photo from the library using `PhotosPicker`.
2.  **Metadata Entry**: Input title, description, date, and location.
3.  **Face Detection**: `FaceDetectionManager` runs an on-device `VNDetectFaceRectanglesRequest`.
4.  **People Tagging**: An interactive `FaceTaggingView` allows the user to associate detected faces with known people.
5.  **Upload**: The image and all its metadata (including face tags) are sent to the hub via a multipart form upload.

#### Voice Recordings

`AudioManager` provides a robust wrapper around `AVFoundation` for high-quality audio capture.

```swift
// In AudioManager.swift
class AudioManager: ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?

    func startRecording() async -> Bool {
        // Configures the audio session for recording.
        // Starts the AVAudioRecorder with AAC format.
        // Provides real-time updates for the UI via @Published properties.
    }

    func stopRecording() -> URL? {
        // Stops the recorder and returns the URL of the temporary audio file.
        // The audio data is then prepared for upload.
    }
}
```

**Voice Recording Features:**

- **High-Quality Capture**: Records in `.m4a` (AAC) format for a good balance of quality and size.
- **Real-Time Feedback**: The UI displays a running timer and a visual level meter.
- **Story Context**: Allows users to add a title, description, and people tags to give context to the audio story.

#### Video Memories

The app supports uploading video memories selected from the user's photo library.

```swift
// In VideoUploadView.swift
struct VideoUploadView: View {
    @State private var selectedVideo: PhotosPickerItem?

    // The view guides the user to select a video and then add metadata.
    // The selected PhotosPickerItem is passed directly to the NetworkManager
    // for efficient data loading and uploading.
}
```

### On-Device Face Detection

The `FaceDetectionManager` is responsible for all on-device face analysis, ensuring user privacy.

```swift
// In FaceDetectionManager.swift
class FaceDetectionManager: ObservableObject {
    func detectFaces(in image: UIImage) async -> [VNFaceObservation] {
        // The request is configured to use the high-accuracy revision 3.
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3

        guard let cgImage = image.cgImage else { return [] }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // The request is performed, and results are processed in a continuation.
        // This process is entirely on-device.
        try? handler.perform([request])

        return request.results as? [VNFaceObservation] ?? []
    }
}
```

**Face Detection Pipeline:**

1.  **Image Analysis**: The Vision framework processes the `UIImage` locally.
2.  **Face Extraction**: Bounding box coordinates and confidence scores are extracted for each detected face.
3.  **Privacy Protection**: No face data leaves the device. The app only stores the coordinates of the detected rectangles.
4.  **User Tagging**: The `FaceTaggingView` provides an interactive interface for associating the rectangles with known people.
5.  **Upload**: Once tagged by the user, the bounding box coordinates and associated `personId` are sent to the backend.

### People & Relationship Management

`PersonManager` maintains the local state of people and orchestrates communication with the `NetworkManager`.

```swift
// In PersonManager.swift
@MainActor
class PersonManager: ObservableObject {
    @Published var people: [Person] = []

    func fetchAllPeopleFromServer(networkManager: NetworkManager) async {
        // GET /api/people - Syncs with the backend.
        self.people = await networkManager.getAllPeople()
    }

    func addPerson(name: String, relationship: String?, networkManager: NetworkManager) async -> Person? {
        // POST /api/people - Creates a new person.
        // Handles 409 Conflict status by informing the user.
        let result = await networkManager.uploadPerson(name: name, relationship: relationship)
        // ... updates local state based on the result
    }

    func deletePerson(_ person: Person, networkManager: NetworkManager) async {
        // DELETE /api/people/{id} - Removes a person.
        // ...
    }
}
```

**People Management Features:**

- **Centralized State**: The `people` array acts as the source of truth for the UI.
- **Relationship Tracking**: Supports defining relationships (e.g., Father, Spouse, Friend).
- **Conflict Handling**: Informs the user if a person with the same name already exists on the server.
- **Avatar Display**: Displays avatars using the `avatarUrl` provided by the server.

### NetworkManager - API Integration

`NetworkManager` is an `ObservableObject` that encapsulates all API calls using Swift's modern concurrency.

```swift
// In NetworkManager.swift
@MainActor
class NetworkManager: ObservableObject {
    // ... serverConfig and session properties

    // Memory Management
    func uploadPhotoMemory(photos: [PhotosPickerItem], title: String, ...) async -> Bool
    func uploadVideoMemory(videoItem: PhotosPickerItem, title: String, ...) async -> Bool
    func uploadVoiceMemory(audioData: Data, title: String, ...) async -> Bool
    func uploadTextMemory(title: String, content: String, ...) async -> Bool

    // People Management
    func getAllPeople() async -> [Person]
    func uploadPerson(name: String, relationship: String?) async -> UploadResult
    func deletePerson(personId: Int) async -> Bool
    func updatePerson(personId: Int, name: String, relationship: String?) async -> Bool

    // Memory Browsing
    func getAllMemories() async -> [Memory]
    func getMemoriesForPerson(personId: Int) async -> [Memory]
    func deleteMemory(_ memoryId: Int) async -> Bool

    // System
    func testConnection() async -> Bool
}
```

### QR Code Setup System

The initial setup is made effortless through a secure QR code scanning system.

```swift
// In QRScannerView.swift
// A UIViewControllerRepresentable wraps AVCaptureSession for camera access.
struct QRCodeScannerView: UIViewControllerRepresentable { ... }

// In ContentView.swift or SetupView.swift
private func handleQRScan(result: String) {
    // 1. The scanned string is decoded from JSON into a ServerConfig object.
    guard let data = result.data(using: .utf8),
          let config = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
        // Handle invalid format
        return
    }

    // 2. The config is used to test the connection.
    networkManager.updateServerConfig(config)
    Task {
        if await networkManager.testConnection() {
            // 3. If successful, the config is saved to UserDefaults.
            config.save()
            // 4. Initial data (like people) is fetched.
            await personManager.fetchAllPeopleFromServer(networkManager: networkManager)
        }
    }
}
```

## 🎨 User Interface Design

### SwiftUI Modern Design

The app uses a standard `TabView` for its main navigation, providing easy access to core features.

```swift
// In ContentView.swift
struct MainTabView: View {
    var body: some View {
        TabView {
            UploadTabView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Memories")
                }
            BrowseTabView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Memories")
                }
            PersonListView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("People")
                }
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}
```

### Upload Flow Design

The upload process for each memory type is broken down into clear, sequential steps to guide the user.

```swift
// In PhotoUploadView.swift
struct PhotoUploadView: View {
    @State private var currentStep: UploadStep = .selectPhotos

    // This enum drives the multi-step UI.
    enum UploadStep {
        case selectPhotos
        case addMetadata
        case tagFaces
    }

    // The UI is a switch statement over 'currentStep', showing the
    // appropriate view for each stage of the process.
    // Progress is indicated by a custom ProgressBar view.
}
```

### Family-Focused Interface

- **Large Touch Targets**: Buttons and interactive elements are designed to be easily tappable.
- **Clear Visual Hierarchy**: Key actions are presented using prominent button styles and colors.
- **Intuitive Navigation**: Follows standard iOS patterns within a `NavigationView` and `TabView`.
- **Progress Feedback**: Uploads show a dedicated progress screen with status messages.
- **Error Recovery**: Non-critical errors are displayed in alerts, allowing the user to retry.