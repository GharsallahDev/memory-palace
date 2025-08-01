import SwiftUI

struct SetupView: View {
    @ObservedObject var networkManager: NetworkManager
    @Binding var showingScanner: Bool
    
    @State private var manualIP = ""
    @State private var manualPort = "3000"
    @State private var showingManualSetup = false
    @State private var isConnecting = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Constants.UI.largeSpacing) {
                    VStack(spacing: Constants.UI.mediumSpacing) {
                        Image("logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                        
                        Text("Memory Palace")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Memory Collection & AI")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(alignment: .leading, spacing: Constants.UI.mediumSpacing) {
                        Text("Features")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        FeatureRow(
                            icon: "face.dashed",
                            title: "Face Recognition",
                            description: "Automatically detect and tag people in photos"
                        )
                        
                        FeatureRow(
                            icon: "mic.circle",
                            title: "Voice Stories", 
                            description: "Record stories and memories about your photos"
                        )
                        
                        FeatureRow(
                            icon: "icloud.and.arrow.down",
                            title: "People Sync",
                            description: "Share memories across all devices"
                        )
                        
                        FeatureRow(
                            icon: "lock.shield",
                            title: "Private & Secure",
                            description: "All data stays on your home network"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(Constants.UI.mediumCornerRadius)
                    
                    VStack(alignment: .leading, spacing: Constants.UI.mediumSpacing) {
                        Text("Setup Instructions")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        SetupStep(
                            number: "1",
                            title: "Start Memory Hub",
                            description: "Run the Memory Palace Hub on your computer"
                        )
                        
                        SetupStep(
                            number: "2",
                            title: "Scan QR Code",
                            description: "Use the QR code shown on the hub dashboard"
                        )
                        
                        SetupStep(
                            number: "3",
                            title: "Start Collecting",
                            description: "Add photos and voice stories to your collection"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(Constants.UI.mediumCornerRadius)
                    
                    VStack(spacing: Constants.UI.mediumSpacing) {
                        Button("📱 Scan Setup QR Code") {
                            showingScanner = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isConnecting)
                        
                        Button("⚙️ Manual Setup") {
                            showingManualSetup = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(isConnecting)
                    }
                    
                    if !networkManager.statusMessage.isEmpty {
                        VStack(spacing: Constants.UI.smallSpacing) {
                            HStack {
                                Image(systemName: networkManager.statusMessage.contains("Error") ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                    .foregroundColor(networkManager.statusMessage.contains("Error") ? .red : .blue)
                                
                                Text(networkManager.statusMessage)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                        }
                        .padding()
                        .background(networkManager.statusMessage.contains("Error") ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                        .cornerRadius(Constants.UI.smallCornerRadius)
                    }
                    
                    if isConnecting {
                        VStack(spacing: Constants.UI.smallSpacing) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Connecting to memories hub...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingManualSetup) {
            ManualSetupView(
                networkManager: networkManager,
                manualIP: $manualIP,
                manualPort: $manualPort,
                isConnecting: $isConnecting
            )
        }
        .onChange(of: networkManager.isLoading) { loading in
            isConnecting = loading
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: Constants.UI.mediumSpacing) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct SetupStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: Constants.UI.mediumSpacing) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 30, height: 30)
                
                Text(number)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ManualSetupView: View {
    @ObservedObject var networkManager: NetworkManager
    @Binding var manualIP: String
    @Binding var manualPort: String
    @Binding var isConnecting: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var manualToken = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Server Details") {
                    TextField("IP Address (e.g., 192.168.1.100)", text: $manualIP)
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Port", text: $manualPort)
                        .keyboardType(.numberPad)
                    
                    TextField("Auth Token", text: $manualToken)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("Instructions") {
                    VStack(alignment: .leading, spacing: Constants.UI.smallSpacing) {
                        Text("1. Find the server details on your Memory Hub dashboard")
                        Text("2. Enter the IP address, port, and auth token")
                        Text("3. Tap 'Connect' to establish connection")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                if isConnecting {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Connecting...")
                        }
                    }
                }
            }
            .navigationTitle("Manual Setup")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Connect") {
                    connectManually()
                }
                .disabled(manualIP.isEmpty || manualPort.isEmpty || manualToken.isEmpty || isConnecting)
            )
        }
        .alert("Connection Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func connectManually() {
        guard let port = Int(manualPort) else {
            alertMessage = "Invalid port number"
            showingAlert = true
            return
        }
        
        let config = ServerConfig(
            serverIP: manualIP.trimmed,
            port: port,
            authToken: manualToken.trimmed
        )
        
        if !config.isValid {
            alertMessage = config.validationErrors.joined(separator: "\n")
            showingAlert = true
            return
        }
        
        isConnecting = true
        networkManager.updateServerConfig(config)
        
        Task {
            let success = await networkManager.testConnection()
            
            await MainActor.run {
                isConnecting = false
                
                if success {
                    config.save()
                    dismiss()
                } else {
                    alertMessage = networkManager.statusMessage
                    showingAlert = true
                }
            }
        }
    }
}

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView(
            networkManager: NetworkManager(),
            showingScanner: .constant(false)
        )
    }
}
