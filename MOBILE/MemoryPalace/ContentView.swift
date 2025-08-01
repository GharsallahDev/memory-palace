import SwiftUI

struct ContentView: View {
    @StateObject private var networkManager = NetworkManager()
    @StateObject private var personManager = PersonManager()
    @StateObject private var faceDetectionManager = FaceDetectionManager()
    @StateObject private var audioManager = AudioManager()
    
    @State private var showingScanner = false
    @State private var isInitialized = false
    
    var body: some View {
        Group {
            if !isInitialized {
                SplashView().onAppear { initializeApp() }
            } else if networkManager.serverConfig == nil {
                SetupView(networkManager: networkManager, showingScanner: $showingScanner)
            } else {
                MainTabView(
                    networkManager: networkManager,
                    personManager: personManager,
                    faceDetectionManager: faceDetectionManager,
                    audioManager: audioManager
                )
            }
        }
        .sheet(isPresented: $showingScanner) {
            QRScannerView { result in
                handleQRScan(result: result)
                showingScanner = false
            }
        }
    }
    
    private func initializeApp() {
        Task {
            if let savedConfig = ServerConfig.load() {
                networkManager.updateServerConfig(savedConfig)
                await networkManager.testConnection()
            }
            if networkManager.isConnected {
                await personManager.fetchAllPeopleFromServer(networkManager: networkManager)
            }
            await MainActor.run { isInitialized = true }
        }
    }
    
    private func handleQRScan(result: String) {
        guard let data = result.data(using: .utf8) else {
            networkManager.statusMessage = "Invalid QR code format"; return
        }
        do {
            let config = try JSONDecoder().decode(ServerConfig.self, from: data)
            networkManager.updateServerConfig(config)
            Task {
                let connected = await networkManager.testConnection()
                if connected {
                    config.save()
                    await personManager.fetchAllPeopleFromServer(networkManager: networkManager)
                }
            }
        } catch {
            networkManager.statusMessage = "Failed to parse QR code: \(error.localizedDescription)"
        }
    }
}

struct MainTabView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    @ObservedObject var faceDetectionManager: FaceDetectionManager
    @ObservedObject var audioManager: AudioManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            UploadTabView(networkManager: networkManager, personManager: personManager, audioManager: audioManager)
                .tabItem { Image(systemName: "plus.circle.fill"); Text("Add Memories") }.tag(0)
            
            BrowseTabView(networkManager: networkManager, personManager: personManager)
                .tabItem { Image(systemName: "heart.fill"); Text("Memories") }.tag(1)
            
            PersonListView(personManager: personManager, networkManager: networkManager)
                .tabItem { Image(systemName: "person.2.fill"); Text("People") }.tag(2)
            
            SettingsView(networkManager: networkManager, personManager: personManager)
                .tabItem { Image(systemName: "gear"); Text("Settings") }.tag(3)
        }
    }
}

struct UploadTabView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    @ObservedObject var audioManager: AudioManager
    
    @State private var showingPhotoPicker = false
    @State private var showingVoiceRecorder = false
    @State private var showingVideoPicker = false
    @State private var showingTextEditor = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Constants.UI.largeSpacing) {
                    ConnectionStatusCard(networkManager: networkManager)
                    
                    VStack(alignment: .leading, spacing: Constants.UI.mediumSpacing) {
                        Text("Add to Collection")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        UploadOptionCard(icon: "photo.on.rectangle.angled", title: "Add Photo", description: "Share a picture with face detection.", color: .blue) { showingPhotoPicker = true }
                        UploadOptionCard(icon: "video.fill", title: "Add a Video", description: "Share a video clip from your library.", color: .purple) { showingVideoPicker = true }
                        UploadOptionCard(icon: "mic.circle.fill", title: "Record a Voice Story", description: "Record audio memories and stories.", color: .orange) { showingVoiceRecorder = true }
                        UploadOptionCard(icon: "doc.text.fill", title: "Write a Note", description: "Jot down a memory or story as text.", color: .green) { showingTextEditor = true }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Memory Collection")
        }
        .sheet(isPresented: $showingPhotoPicker) { PhotoUploadView(networkManager: networkManager, personManager: personManager) }
        .sheet(isPresented: $showingVoiceRecorder) { VoiceRecorderView(networkManager: networkManager, personManager: personManager) }
        .sheet(isPresented: $showingVideoPicker) { VideoUploadView(networkManager: networkManager, personManager: personManager) }
        .sheet(isPresented: $showingTextEditor) { TextUploadView(networkManager: networkManager, personManager: personManager) }
    }
}

struct BrowseTabView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    var body: some View {
        NavigationView { MemoryListView(networkManager: networkManager, personManager: personManager) }
    }
}

struct SplashView: View {
    var body: some View {
        VStack(spacing: Constants.UI.largeSpacing) {
            Image(systemName: "brain.head.profile").font(.system(size: 80)).foregroundColor(.blue)
            Text("Memory Palace").font(.largeTitle).fontWeight(.bold)
            Text("Loading...").font(.subheadline).foregroundColor(.secondary)
            ProgressView().scaleEffect(1.5)
        }
    }
}

struct ConnectionStatusCard: View {
    @ObservedObject var networkManager: NetworkManager
    
    var body: some View {
        HStack(spacing: Constants.UI.mediumSpacing) {
            Image(systemName: networkManager.isConnected ? "wifi" : "wifi.slash")
                .font(.title2)
                .foregroundColor(networkManager.isConnected ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Connected to Memories Hub")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(networkManager.isConnected ? "Ready to sync" : "Connection failed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if networkManager.isLoading {
                ProgressView()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(Constants.UI.largeCornerRadius)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        .onTapGesture {
            if !networkManager.isLoading {
                Task {
                    await networkManager.testConnection()
                }
            }
        }
    }
}

struct UploadOptionCard: View {
    let icon: String; let title: String; let description: String; let color: Color; let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Constants.UI.mediumSpacing) {
                Image(systemName: icon).font(.title).foregroundColor(color).frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundColor(.primary)
                    Text(description).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.callout).foregroundColor(.secondary.opacity(0.5))
            }
            .padding().background(Color(.systemBackground)).cornerRadius(Constants.UI.mediumCornerRadius)
        }.buttonStyle(PlainButtonStyle()).padding(.horizontal)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
