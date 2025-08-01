import SwiftUI
import AVFoundation

struct VoiceRecorderView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    @StateObject private var audioManager = AudioManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var memoryTitle = ""
    @State private var memoryDescription = ""
    @State private var selectedPersonIDs: Set<UUID> = []
    @State private var whenWasThis: Date?
    @State private var whereWasThis = ""

    @State private var isUploading = false
    @State private var uploadIsComplete = false
    @State private var uploadMessage = ""

    @State private var currentStep: VoiceUploadStep = .record
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDiscardAlert = false
    @State private var showTitleError = false
    
    private let themeColor = Color.orange

    enum VoiceUploadStep {
        case record
        case addMetadata
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VoiceProgressBar(step: currentStep, totalSteps: 2, themeColor: themeColor).padding()

                switch currentStep {
                case .record:
                    RecordStoryView(
                        audioManager: audioManager,
                        themeColor: themeColor,
                        onComplete: goToNextStep
                    )
                case .addMetadata:
                    if isUploading || uploadIsComplete {
                        VoiceUploadProgressView(
                            isUploading: $isUploading,
                            isComplete: $uploadIsComplete,
                            message: $uploadMessage,
                            onDone: { dismiss() },
                            themeColor: themeColor
                        ).padding()
                    } else {
                        MetadataInputView(
                            title: $memoryTitle,
                            description: $memoryDescription,
                            selectedPersonIDs: $selectedPersonIDs,
                            whenWasThis: $whenWasThis,
                            whereWasThis: $whereWasThis,
                            personManager: personManager,
                            networkManager: networkManager,
                            showTitleError: $showTitleError,
                            themeColor: themeColor
                        )
                    }
                }

                if currentStep == .addMetadata && !isUploading && !uploadIsComplete {
                    HStack(spacing: 16) {
                        Button("Back") { goToPreviousStep() }.buttonStyle(SecondaryButtonStyle())
                        Button("Save Story") { startUpload() }.buttonStyle(PrimaryButtonStyle(color: themeColor))
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.bottom))
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") { self.handleCancel() })
        }
        .alert("Discard Recording?", isPresented: self.$showingDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Recording", role: .cancel) { }
        } message: { Text("Are you sure you want to discard this recording? This action cannot be undone.") }
        .onDisappear { audioManager.fullReset() }
    }
    
    private var navigationTitle: String {
        switch currentStep {
        case .record: return "Record Story"
        case .addMetadata: return isUploading || uploadIsComplete ? "Saving" : "Add Details"
        }
    }
    
    private func goToNextStep() {
        if currentStep == .record {
            withAnimation { currentStep = .addMetadata }
        }
    }

    private func goToPreviousStep() {
        withAnimation {
            if currentStep == .addMetadata { currentStep = .record }
        }
    }
    
    private func startUpload() {
        if memoryTitle.trimmed.isEmpty {
            showTitleError = true; Haptics.shared.error(); return
        }
        showTitleError = false
        withAnimation { isUploading = true }

        Task {
            guard let audioData = await audioManager.getRecordingData() else {
                await MainActor.run {
                    self.alertMessage = "Failed to prepare recording."; self.showingAlert = true; withAnimation { self.isUploading = false }
                }
                return
            }
            
            let serverIDs = selectedPersonIDs.compactMap { personManager.findPerson(by: $0)?.serverId }

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let formattedWhenWasThis = whenWasThis.map { dateFormatter.string(from: $0) } ?? ""
            
            await MainActor.run { self.uploadMessage = "" }
            
            let success = await networkManager.uploadVoiceMemory(
                audioData: audioData,
                title: memoryTitle,
                context: memoryDescription,
                duration: audioManager.currentRecordingDuration,
                peopleIds: serverIDs,
                whenWasThis: formattedWhenWasThis,
                whereWasThis: whereWasThis
            )
            
            await MainActor.run {
                if success {
                    self.uploadMessage = "Your voice story has been successfully added."; self.uploadIsComplete = true
                    NotificationCenter.default.post(name: Constants.Notifications.memoryUploaded, object: nil)
                } else {
                    self.alertMessage = networkManager.statusMessage; self.showingAlert = true
                    withAnimation { self.isUploading = false }
                }
            }
        }
    }
    
    private func handleCancel() {
        if audioManager.currentRecordingDuration > 0 { self.showingDiscardAlert = true }
        else { dismiss() }
    }
}


struct VoiceProgressBar: View {
    let step: VoiceRecorderView.VoiceUploadStep; let totalSteps: Int; let themeColor: Color
    private var currentStepNumber: Int {
        switch step {
        case .record: return 1
        case .addMetadata: return 2
        }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(1...totalSteps, id: \.self) { stepNumber in
                    Circle().fill(stepNumber <= currentStepNumber ? themeColor : Color.gray.opacity(0.3)).frame(width: 10, height: 10)
                    if stepNumber < totalSteps { Rectangle().fill(stepNumber < currentStepNumber ? themeColor : Color.gray.opacity(0.3)).frame(height: 2) }
                }
            }
            Text("Step \(currentStepNumber) of \(totalSteps)").font(.caption).foregroundColor(.secondary)
        }
    }
}

struct RecordStoryView: View {
    @ObservedObject var audioManager: AudioManager
    let themeColor: Color
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: Constants.UI.largeSpacing) {
            Image(systemName: "waveform.circle.fill").font(.system(size: 80)).foregroundColor(themeColor)
            VStack(spacing: Constants.UI.smallSpacing) {
                Text("Record a Story").font(.title2).fontWeight(.semibold)
                Text("Share a memory, tell a story, or record a moment that matters.").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            }
            
            VStack(spacing: Constants.UI.mediumSpacing) {
                Text(audioManager.formatTime(audioManager.recordingTime))
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundColor(audioManager.isRecording ? themeColor : .secondary)
                
                Button(action: handleRecordingAction) {
                    Image(systemName: audioManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(themeColor)
                }
                
                if audioManager.isRecording {
                    Text("Tap to stop").font(.caption).foregroundColor(.secondary)
                } else {
                    Text("Tap to record").font(.caption).foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }.padding()
    }
    
    private func handleRecordingAction() {
        if audioManager.isRecording {
            audioManager.stopRecording()
            if audioManager.currentRecordingDuration > 1.0 {
                onComplete()
            }
        } else {
            Task { await audioManager.startRecording() }
        }
    }
}

struct VoiceUploadProgressView: View {
    @Binding var isUploading: Bool; @Binding var isComplete: Bool; @Binding var message: String; let onDone: () -> Void; let themeColor: Color
    var body: some View {
        VStack(spacing: Constants.UI.largeSpacing) {
            Spacer()
            if isComplete {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 80)).foregroundColor(.green)
                Text("Story Added").font(.title).fontWeight(.bold)
                Text(message).font(.body).foregroundColor(.secondary)
                Button("Done") { onDone() }.buttonStyle(PrimaryButtonStyle(color: themeColor)).padding(.top)
            } else {
                ProgressView().scaleEffect(2.0).padding(.bottom)
                Text("Saving Story...").font(.title2).fontWeight(.semibold)
                Text(message).font(.body).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
