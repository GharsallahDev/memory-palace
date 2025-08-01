import SwiftUI
import PhotosUI
import AVKit

struct VideoUploadView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedVideo: PhotosPickerItem?
    
    @State private var memoryTitle = ""
    @State private var memoryDescription = ""
    @State private var selectedPersonIDs: Set<UUID> = []
    @State private var whenWasThis: Date?
    @State private var whereWasThis = ""
    
    @State private var isUploading = false
    @State private var uploadIsComplete = false
    @State private var uploadMessage = ""
    
    @State private var currentStep: VideoUploadStep = .selectVideo
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showTitleError = false
    
    private let themeColor = Color.purple
    
    enum VideoUploadStep {
        case selectVideo
        case addMetadata
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VideoProgressBar(step: currentStep, totalSteps: 2, themeColor: themeColor).padding()

                switch currentStep {
                case .selectVideo:
                    VideoSelectionView(
                        selectedVideo: $selectedVideo,
                        onComplete: goToNextStep,
                        themeColor: themeColor
                    )
                    
                case .addMetadata:
                    if isUploading || uploadIsComplete {
                        VideoUploadProgressView(
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
                        Button("Upload Video") { startUpload() }.buttonStyle(PrimaryButtonStyle(color: themeColor))
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.bottom))
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
        }
        .alert("Upload Error", isPresented: $showingAlert) { Button("OK") { } } message: { Text(alertMessage) }
    }
    
    private var navigationTitle: String {
        switch currentStep {
        case .selectVideo: return "Add Video"
        case .addMetadata: return isUploading || uploadIsComplete ? "Uploading" : "Add Details"
        }
    }
    
    private func goToNextStep() {
        withAnimation {
            if currentStep == .selectVideo { currentStep = .addMetadata }
        }
    }

    private func goToPreviousStep() {
        withAnimation {
            if currentStep == .addMetadata {
                selectedVideo = nil
                currentStep = .selectVideo
            }
        }
    }

    private func startUpload() {
        guard let video = selectedVideo else { return }
        if memoryTitle.trimmed.isEmpty {
            showTitleError = true; Haptics.shared.error(); return
        }
        showTitleError = false
        withAnimation { isUploading = true }
        
        Task {
            let serverIDs = selectedPersonIDs.compactMap { personManager.findPerson(by: $0)?.serverId }

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let formattedWhenWasThis = whenWasThis.map { dateFormatter.string(from: $0) } ?? ""

            await MainActor.run { uploadMessage = "" }
            let success = await networkManager.uploadVideoMemory(
                videoItem: video,
                title: memoryTitle,
                description: memoryDescription,
                peopleIds: serverIDs,
                whenWasThis: formattedWhenWasThis,
                whereWasThis: whereWasThis
            )
            
            await MainActor.run {
                if success {
                    uploadMessage = "Your video has been successfully added."; uploadIsComplete = true
                    NotificationCenter.default.post(name: Constants.Notifications.memoryUploaded, object: nil)
                } else {
                    alertMessage = networkManager.statusMessage; showingAlert = true
                }
                isUploading = false
            }
        }
    }
}


struct VideoProgressBar: View {
    let step: VideoUploadView.VideoUploadStep
    let totalSteps: Int
    let themeColor: Color
    
    private var currentStepNumber: Int {
        switch step {
        case .selectVideo: return 1
        case .addMetadata: return 2
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(1...totalSteps, id: \.self) { stepNumber in
                    Circle().fill(stepNumber <= currentStepNumber ? themeColor : Color.gray.opacity(0.3)).frame(width: 10, height: 10)
                    if stepNumber < totalSteps {
                        Rectangle().fill(stepNumber < currentStepNumber ? themeColor : Color.gray.opacity(0.3)).frame(height: 2)
                    }
                }
            }
            Text("Step \(currentStepNumber) of \(totalSteps)").font(.caption).foregroundColor(.secondary)
        }
    }
}

struct VideoSelectionView: View {
    @Binding var selectedVideo: PhotosPickerItem?
    let onComplete: () -> Void
    let themeColor: Color
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "video.badge.plus").font(.system(size: 80)).foregroundColor(themeColor)
            VStack(spacing: 8) {
                Text("Select Video").font(.title2).fontWeight(.semibold)
                Text("Choose a video clip to add to your memory collection.").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            }
            PhotosPicker(selection: $selectedVideo, matching: .videos) {
                Label("Choose Video from Library", systemImage: "video.fill").foregroundColor(themeColor)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .onChange(of: selectedVideo) { _ in
                if selectedVideo != nil {
                    onComplete()
                }
            }
            Spacer()
        }.padding()
    }
}

struct VideoUploadProgressView: View {
    @Binding var isUploading: Bool
    @Binding var isComplete: Bool
    @Binding var message: String
    let onDone: () -> Void
    let themeColor: Color
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            if isComplete {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 80)).foregroundColor(.green)
                Text("Video Added").font(.title).fontWeight(.bold)
                Text(message).font(.body).foregroundColor(.secondary)
                Button("Done") { onDone() }.buttonStyle(PrimaryButtonStyle(color: themeColor)).padding(.top)
            } else {
                ProgressView().scaleEffect(2.0).padding(.bottom)
                Text("Uploading Video...").font(.title2).fontWeight(.semibold)
                Text(message).font(.body).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
