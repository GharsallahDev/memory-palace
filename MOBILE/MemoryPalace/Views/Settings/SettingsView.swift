import SwiftUI

struct SettingsView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    
    @State private var showingConnectionSetup = false
    @State private var showingResetAlert = false
    @State private var showingClearDataAlert = false
    @State private var showingAbout = false
    @State private var showingDebugOptions = false
    
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("enableFaceDetection") private var enableFaceDetection = true
    @AppStorage("autoSync") private var autoSync = true
    @AppStorage("compressPhotos") private var compressPhotos = true
    @AppStorage("enableDebugMode") private var enableDebugMode = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Connection") {
                    ConnectionStatusRow(networkManager: networkManager)
                    
                    if networkManager.serverConfig != nil {
                        ServerDetailsRow(networkManager: networkManager)
                        Button("Change Server") { showingConnectionSetup = true }.foregroundColor(.blue)
                    } else {
                        Button("Setup Connection") { showingConnectionSetup = true }.foregroundColor(.blue)
                    }
                    
                    Button("Test Connection") {
                        Task { await networkManager.testConnection() }
                    }
                    .disabled(networkManager.isLoading || networkManager.serverConfig == nil)
                }
                
                Section("Preferences") {
                    ToggleRow(icon: "bell.fill", title: "Notifications", description: "Get notified about sync and uploads", isOn: $enableNotifications)
                    ToggleRow(icon: "face.dashed", title: "Face Detection", description: "Automatically detect faces in photos", isOn: $enableFaceDetection)
                    ToggleRow(icon: "arrow.clockwise", title: "Auto Sync", description: "Automatically sync when connected", isOn: $autoSync)
                    ToggleRow(icon: "photo.circle", title: "Compress Photos", description: "Reduce photo size for faster uploads", isOn: $compressPhotos)
                }
                
                Section("Data Management") {
                    Button("Clear Local Data") { showingClearDataAlert = true }.foregroundColor(.red)
                }
                
                Section("Advanced") {
                    Button("Reset Connection") { showingResetAlert = true }.foregroundColor(.red)
                    if Constants.isDebugBuild {
                        ToggleRow(icon: "ladybug.fill", title: "Debug Mode", description: "Enable detailed logging", isOn: $enableDebugMode)
                        if enableDebugMode {
                            Button("Debug Options") { showingDebugOptions = true }.foregroundColor(.orange)
                        }
                    }
                }
                
                Section("About") {
                    Button("About Memory Palace") { showingAbout = true }.foregroundColor(.blue)
                    HStack {
                        Text("Version"); Spacer(); Text(Constants.App.version).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Device"); Spacer(); Text(Constants.deviceName).foregroundColor(.secondary).lineLimit(1)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingConnectionSetup) {
            ConnectionSetupView(networkManager: networkManager, personManager: personManager)
        }
        .sheet(isPresented: $showingAbout) { AboutView() }
        .sheet(isPresented: $showingDebugOptions) { DebugOptionsView(networkManager: networkManager, personManager: personManager) }
        .alert("Reset Connection", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                networkManager.reset()
                personManager.clearAllPeople()
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This will remove your server connection and clear all local data. You'll need to scan the QR code again to reconnect.") }
        .alert("Clear Local Data", isPresented: $showingClearDataAlert) {
            Button("Clear", role: .destructive) { personManager.clearAllPeople() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This will remove all locally stored people data. Your data on the hub will remain safe.") }
    }
}

struct ConnectionStatusRow: View {
    @ObservedObject var networkManager: NetworkManager
    var body: some View {
        HStack {
            Image(systemName: "network").foregroundColor(networkManager.isConnected ? .green : .red).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connection Status")
                Text(networkManager.isConnected ? "Connected" : "Disconnected").font(.caption).foregroundColor(networkManager.isConnected ? .green : .red)
            }
            Spacer()
            if networkManager.isLoading { ProgressView().scaleEffect(0.8) } else { Circle().fill(networkManager.isConnected ? Color.green : Color.red).frame(width: 8, height: 8) }
        }
    }
}

struct ServerDetailsRow: View {
    @ObservedObject var networkManager: NetworkManager
    var body: some View {
        if let config = networkManager.serverConfig {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "server.rack").foregroundColor(.blue).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Server Details")
                        Text(config.displayString).font(.caption).foregroundColor(.secondary)
                    }
                }
                if let lastSync = networkManager.lastSyncTime {
                    HStack {
                        Text("Last Sync:").font(.caption).foregroundColor(.secondary)
                        Text(lastSync, style: .relative).font(.caption).foregroundColor(.secondary)
                        Text("ago").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct ToggleRow: View {
    let icon: String; let title: String; let description: String; @Binding var isOn: Bool
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
        }
    }
}

struct FamilyManagementView: View {
    @ObservedObject var personManager: PersonManager
    @ObservedObject var networkManager: NetworkManager
    @State private var showingAddPerson = false
    
    var body: some View {
        List {
            Section(header: Text("People (\(personManager.peopleCount))")) {
                ForEach(personManager.people.sorted { $0.name < $1.name }) { person in
                    PersonRowView(person: person, action: {})
                }
                .onDelete(perform: deletePeople)
            }
            
            Section { Button("Add Person") { showingAddPerson = true }.foregroundColor(.blue) }
        }
        .navigationTitle("People Management")
        .navigationBarItems(trailing: EditButton())
        .sheet(isPresented: $showingAddPerson) {
            AddPersonView(
                personManager: personManager,
                networkManager: networkManager,
                onPersonAdded: { _ in }
            )
        }
    }
    
    private func deletePeople(offsets: IndexSet) {
        let sortedPeople = personManager.people.sorted { $0.name < $1.name }
        for index in offsets {
            let person = sortedPeople[index]
            Task { await personManager.deletePerson(person, networkManager: networkManager) }
        }
    }
}

struct ConnectionSetupView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingScanner = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Setup Connection").font(.title).fontWeight(.bold)
                Text("Connect to your Memory Palace Hub").foregroundColor(.secondary)
                Button("Scan QR Code") { showingScanner = true }.buttonStyle(PrimaryButtonStyle())
                Spacer()
            }
            .padding()
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
        }
        .sheet(isPresented: $showingScanner) {
            QRScannerView { result in
                handleQRScan(result: result)
                showingScanner = false
                dismiss()
            }
        }
    }
    
    private func handleQRScan(result: String) {
        guard let data = result.data(using: .utf8),
              let config = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
            networkManager.statusMessage = "Invalid QR code format"
            return
        }
        networkManager.updateServerConfig(config)
        Task {
            if await networkManager.testConnection() {
                config.save()
                await personManager.fetchAllPeopleFromServer(networkManager: networkManager)
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "brain.head.profile").font(.system(size: 80)).foregroundColor(.blue)
                    Text("Memory Palace").font(.largeTitle).fontWeight(.bold)
                    Text("Memory Collection & AI").font(.subheadline).foregroundColor(.secondary)
                    
                    VStack(spacing: 16) {
                        InfoRow(title: "Version", value: Constants.App.version)
                        InfoRow(title: "Build", value: Constants.App.buildNumber)
                    }
                    .padding().background(Color(.systemGray6)).cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarItems(leading: Button("Done") { dismiss() })
        }
    }
}

struct InfoRow: View {
    let title: String; let value: String
    var body: some View {
        HStack { Text(title); Spacer(); Text(value).foregroundColor(.secondary) }
    }
}

struct DebugOptionsView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Network Debug") {
                    Button("Force Sync") { Task { await personManager.fetchAllPeopleFromServer(networkManager: networkManager) } }
                }
                Section("Data Debug") {
                    Button("Generate Test Data") { generateTestData() }
                }
            }
            .navigationTitle("Debug Options")
            .navigationBarItems(leading: Button("Done") { dismiss() })
        }
    }
    
    private func generateTestData() {
        let testPeople = ["Alice", "Bob", "Charlie", "Diana"]
        for name in testPeople {
            Task {
                _ = await personManager.addPerson(name: name, relationship: "Friend", networkManager: networkManager)
            }
        }
    }
}
