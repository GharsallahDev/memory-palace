import SwiftUI
import PhotosUI

struct PhotoUploadView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    @StateObject private var faceDetectionManager = FaceDetectionManager()
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    @State private var memoryTitle = ""
    @State private var memoryDescription = ""
    @State private var selectedPersonIDs: Set<UUID> = []
    @State private var whenWasThis: Date?
    @State private var whereWasThis = ""

    @State private var detectedFaceTags: [FaceTag] = []
    @State private var showingFaceTagging = false
    @State private var faceDetectionInProgress = false

    @State private var isUploading = false
    @State private var uploadIsComplete = false
    @State private var uploadMessage = ""

    @State private var currentStep: UploadStep = .selectPhotos
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showTitleError = false
    
    private let themeColor = Color.blue

    enum UploadStep {
        case selectPhotos
        case addMetadata
        case tagFaces
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ProgressBar(step: currentStep, totalSteps: 3, themeColor: themeColor)
                    .padding()
                    .background(Color(.systemGroupedBackground))

                switch currentStep {
                case .selectPhotos:
                    PhotoSelectionView(
                        selectedPhoto: $selectedPhoto,
                        onPhotosSelected: processSelectedPhoto,
                        onComplete: goToNextStep,
                        themeColor: themeColor
                    )
                case .addMetadata:
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
                case .tagFaces:
                    if isUploading || uploadIsComplete {
                        UploadProgressView(
                            isUploading: $isUploading,
                            isComplete: $uploadIsComplete,
                            message: $uploadMessage,
                            onDone: { dismiss() },
                            themeColor: themeColor
                        )
                        .padding()
                    } else {
                        TagFacesStepView(
                            isDetecting: $faceDetectionInProgress,
                            detectedFaceTags: detectedFaceTags,
                            onStartTagging: { startFaceTagging() },
                            onAddManualTag: { startFaceTagging() },
                            onSkip: { startUpload() },
                            themeColor: themeColor
                        )
                        .padding()
                    }
                }

                if currentStep == .addMetadata {
                    HStack(spacing: 16) {
                        Button("Back") { goToPreviousStep() }.buttonStyle(SecondaryButtonStyle())
                        Button("Next: Tag Faces") { goToNextStep() }.buttonStyle(PrimaryButtonStyle(color: themeColor))
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
        .sheet(isPresented: $showingFaceTagging) {
            if let image = selectedImage {
                FaceTaggingView(
                    memory: createTempMemory(),
                    image: image,
                    faceTags: detectedFaceTags,
                    allowRescan: true,
                    personManager: personManager,
                    networkManager: networkManager,
                    onTaggingComplete: { updatedTags in
                        self.detectedFaceTags = updatedTags
                        showingFaceTagging = false
                        handleFaceTaggingComplete()
                    },
                    onCancel: { showingFaceTagging = false }
                )
            }
        }
    }
    
    private var navigationTitle: String {
        switch currentStep {
        case .selectPhotos: return "Add Photo"
        case .addMetadata: return "Add Details"
        case .tagFaces: return isUploading || uploadIsComplete ? "Uploading" : "Tag Faces"
        }
    }

    private func goToNextStep() {
        if currentStep == .addMetadata {
            if memoryTitle.trimmed.isEmpty {
                showTitleError = true; Haptics.shared.error(); return
            }
        }
        showTitleError = false
        withAnimation {
            switch currentStep {
            case .selectPhotos: currentStep = .addMetadata
            case .addMetadata: currentStep = .tagFaces; startFaceDetection()
            case .tagFaces: startUpload()
            }
        }
    }

    private func goToPreviousStep() {
        withAnimation {
            switch currentStep {
            case .addMetadata: currentStep = .selectPhotos
            case .tagFaces: faceDetectionManager.resetState(); currentStep = .addMetadata
            case .selectPhotos: break
            }
        }
    }

    private func processSelectedPhoto() {
        Task {
            guard let item = selectedPhoto else { return }
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                await MainActor.run { self.selectedImage = image }
            }
        }
    }

    private func startFaceDetection() {
        Task {
            guard let image = selectedImage else { return }
            await MainActor.run { faceDetectionInProgress = true }
            let faces = await faceDetectionManager.detectFaces(in: image)
            let faceTags = faces.map { FaceTag(memoryId: UUID(), observation: $0) }
            await MainActor.run { self.detectedFaceTags = faceTags; faceDetectionInProgress = false }
        }
    }

    private func startFaceTagging() {
        showingFaceTagging = true
    }

    private func handleFaceTaggingComplete() {
        startUpload()
    }
    
    private func startUpload() {
        guard let photo = selectedPhoto else { return }
        withAnimation { isUploading = true }
        Task {
            let serverIDs = selectedPersonIDs.compactMap { personManager.findPerson(by: $0)?.serverId }
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let formattedWhenWasThis = whenWasThis.map { dateFormatter.string(from: $0) } ?? ""

            await MainActor.run { uploadMessage = "" }
            let success = await networkManager.uploadPhotoMemory(
                photos: [photo], title: memoryTitle, description: memoryDescription,
                peopleIds: serverIDs, whenWasThis: formattedWhenWasThis, whereWasThis: whereWasThis,
                faceTags: detectedFaceTags
            )
            await MainActor.run {
                if success {
                    uploadMessage = "Your photo has been successfully added."; uploadIsComplete = true
                    NotificationCenter.default.post(name: Constants.Notifications.memoryUploaded, object: nil)
                } else {
                    alertMessage = networkManager.statusMessage; showingAlert = true
                }
                isUploading = false
            }
        }
    }

    private func createTempMemory() -> Memory {
        let names = selectedPersonIDs.compactMap { personManager.findPerson(by: $0)?.name }.joined(separator: ", ")
        return Memory(serverId: -1, title: memoryTitle, description: memoryDescription, content: "", type: .photo, timestamp: Date(), metadata: MemoryMetadata(whoWasThere: names, whenWasThis: whenWasThis?.formattedForMemory ?? "", whereWasThis: whereWasThis, context: self.memoryDescription, duration: nil, photoCount: nil), deviceName: "temp")
    }
}


struct ProgressBar: View {
    let step: PhotoUploadView.UploadStep
    let totalSteps: Int
    let themeColor: Color
    
    private var currentStepNumber: Int {
        switch step {
        case .selectPhotos: return 1
        case .addMetadata: return 2
        case .tagFaces: return 3
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

struct PhotoSelectionView: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    let onPhotosSelected: () -> Void
    let onComplete: () -> Void
    let themeColor: Color
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.badge.plus").font(.system(size: 80)).foregroundColor(themeColor)
            VStack(spacing: 8) {
                Text("Select Photo").font(.title2).fontWeight(.semibold)
                Text("Choose a photo to add to your memory collection.").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Choose Photo from Library", systemImage: "photo.fill").foregroundColor(themeColor)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .onChange(of: selectedPhoto) { _ in
                onPhotosSelected()
                if selectedPhoto != nil { onComplete() }
            }
            Spacer()
        }.padding()
    }
}

struct TagFacesStepView: View {
    @Binding var isDetecting: Bool
    let detectedFaceTags: [FaceTag]
    let onStartTagging: () -> Void
    let onAddManualTag: () -> Void
    let onSkip: () -> Void
    let themeColor: Color
    
    private var totalFaces: Int { detectedFaceTags.count }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if isDetecting {
                ProgressView().scaleEffect(1.5)
                Text("Detecting Faces...").font(.title2).fontWeight(.semibold)
                Text("Analyzing your photo to find people.").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
            } else {
                Image(systemName: "face.dashed.fill").font(.system(size: 60)).foregroundColor(themeColor)
                Text("Face Tagging").font(.title2).fontWeight(.semibold)
                
                if totalFaces > 0 {
                    Text("Found \(totalFaces) face\(totalFaces == 1 ? "" : "s"). You can tag them now, add more manually, or proceed to upload.")
                        .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
                } else {
                    Text("The automatic detector found no faces. You can add tags manually or proceed directly to upload.")
                        .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    Button { onStartTagging() } label: {
                        Label(totalFaces > 0 ? "Review & Tag Faces" : "Add Manual Tags", systemImage: "tag.fill")
                    }.buttonStyle(PrimaryButtonStyle(color: themeColor))
                    
                    Button("Skip & Upload") { onSkip() }.buttonStyle(SecondaryButtonStyle())
                }.padding(.top)
            }
            
            Spacer()
        }
    }
}

struct UploadProgressView: View {
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
                Text("Photo Added").font(.title).fontWeight(.bold)
                Text(message).font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
                Button("Done") { onDone() }.buttonStyle(PrimaryButtonStyle(color: themeColor)).padding(.top)
            } else {
                ProgressView().scaleEffect(2.0).padding(.bottom)
                Text("Uploading Photo...").font(.title2).fontWeight(.semibold)
                Text(message).font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            Spacer()
        }
    }
}
