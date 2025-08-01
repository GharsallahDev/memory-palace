import SwiftUI
import Foundation

struct TextUploadView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    @Environment(\.dismiss) private var dismiss

    @State private var memoryTitle = ""
    @State private var memoryContent = ""
    @State private var memoryDescription = ""
    @State private var selectedPersonIDs: Set<UUID> = []
    @State private var whenWasThis: Date?
    @State private var whereWasThis = ""

    @State private var isUploading = false
    @State private var uploadIsComplete = false
    @State private var uploadMessage = ""

    @State private var currentStep: TextUploadStep = .writeNote
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showTitleError = false

    private let themeColor = Color.green

    enum TextUploadStep {
        case writeNote
        case addMetadata
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextProgressBar(step: currentStep, totalSteps: 2, themeColor: themeColor).padding()

                switch currentStep {
                case .writeNote:
                    NoteInputView(
                        content: $memoryContent,
                        themeColor: themeColor,
                        onComplete: goToNextStep
                    )
                case .addMetadata:
                    if isUploading || uploadIsComplete {
                        TextUploadProgressView(
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
                        Button("Save Note") { startUpload() }.buttonStyle(PrimaryButtonStyle(color: themeColor))
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
        case .writeNote: return "Write Note"
        case .addMetadata: return isUploading || uploadIsComplete ? "Saving" : "Add Details"
        }
    }

    private func goToNextStep() {
        if currentStep == .writeNote {
            if memoryContent.trimmed.isEmpty {
                alertMessage = "Please write something for your note."; showingAlert = true; return
            }
        }
        if currentStep == .addMetadata && memoryTitle.trimmed.isEmpty {
            showTitleError = true; Haptics.shared.error(); return
        }
        showTitleError = false
        withAnimation {
            switch currentStep {
            case .writeNote: currentStep = .addMetadata
            case .addMetadata: startUpload()
            }
        }
    }

    private func goToPreviousStep() {
        withAnimation {
            if currentStep == .addMetadata { currentStep = .writeNote }
        }
    }

    private func startUpload() {
        if memoryTitle.trimmed.isEmpty {
            showTitleError = true; Haptics.shared.error(); return
        }
        showTitleError = false
        withAnimation { isUploading = true }

        Task {
            let serverIDs = selectedPersonIDs.compactMap { personManager.findPerson(by: $0)?.serverId }

            var formattedWhenWasThis = ""
            if let date = whenWasThis {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = .current
                dateFormatter.calendar = Calendar(identifier: .gregorian)
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                formattedWhenWasThis = dateFormatter.string(from: date)
            }

            await MainActor.run { uploadMessage = "" }
            let success = await networkManager.uploadTextMemory(
                title: memoryTitle,
                content: memoryContent,
                peopleIds: serverIDs,
                whenWasThis: formattedWhenWasThis,
                whereWasThis: whereWasThis
            )

            await MainActor.run {
                if success {
                    uploadMessage = "Your note has been successfully added."; uploadIsComplete = true
                    NotificationCenter.default.post(name: Constants.Notifications.memoryUploaded, object: nil)
                } else {
                    alertMessage = networkManager.statusMessage; showingAlert = true
                }
                isUploading = false
            }
        }
    }
}


struct TextProgressBar: View {
    let step: TextUploadView.TextUploadStep; let totalSteps: Int; let themeColor: Color
    private var currentStepNumber: Int {
        switch step {
        case .writeNote: return 1
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

struct NoteInputView: View {
    @Binding var content: String; let themeColor: Color; let onComplete: () -> Void
    @FocusState private var isEditorFocused: Bool
    var body: some View {
        VStack {
            TextEditor(text: $content).padding().background(Color(.systemBackground))
                .cornerRadius(12).shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                .focused($isEditorFocused)
                .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isEditorFocused = true } }
            Button("Next: Add Details") { onComplete() }.buttonStyle(PrimaryButtonStyle(color: themeColor)).padding(.top)
        }.padding()
    }
}

struct MetadataInputView: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var selectedPersonIDs: Set<UUID>
    @Binding var whenWasThis: Date?
    @Binding var whereWasThis: String

    @ObservedObject var personManager: PersonManager
    @ObservedObject var networkManager: NetworkManager
    @Binding var showTitleError: Bool
    let themeColor: Color

    @State private var showDatePicker = false

    var body: some View {
        Form {
            Section(header: Text("Memory Details"), footer: Group { if showTitleError { Text("A title is required.").font(.caption).foregroundColor(.red) } }) {
                HStack {
                    Image(systemName: "text.quote").foregroundColor(themeColor).frame(width: 25)
                    TextField("Title", text: $title)
                }.listRowBackground(showTitleError ? Color.red.opacity(0.15) : nil)

                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "text.alignleft").foregroundColor(themeColor).frame(width: 25)
                        Text("Description").font(.caption).foregroundColor(.secondary)
                    }
                    TextEditor(text: $description).frame(minHeight: 100).padding(.leading, 33)
                }
            }

            Section(header: Text("Context")) {
                PersonMultiSelectorView(
                    personManager: personManager,
                    networkManager: networkManager,
                    selectedPersonIDs: $selectedPersonIDs,
                    themeColor: themeColor
                )

                HStack {
                    Image(systemName: "calendar").foregroundColor(themeColor).frame(width: 25)

                    if showDatePicker {
                        DatePicker("When was this?", selection: Binding<Date>(
                            get: { whenWasThis ?? Date() },
                            set: { whenWasThis = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)

                        Button(action: {
                            whenWasThis = nil
                            showDatePicker = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: {
                            whenWasThis = Date()
                            showDatePicker = true
                        }) {
                            Text("When was this?")
                                .foregroundColor(.primary)
                        }
                    }
                }

                HStack {
                    Image(systemName: "mappin.and.ellipse").foregroundColor(themeColor).frame(width: 25)
                    TextField("Where was this?", text: $whereWasThis)
                }
            }
        }
        .onAppear {
            showDatePicker = (whenWasThis != nil)
        }
    }
}

struct TextUploadProgressView: View {
    @Binding var isUploading: Bool; @Binding var isComplete: Bool; @Binding var message: String; let onDone: () -> Void; let themeColor: Color
    var body: some View {
        VStack(spacing: Constants.UI.largeSpacing) {
            Spacer()
            if isComplete {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 80)).foregroundColor(.green)
                Text("Note Added").font(.title).fontWeight(.bold)
                Text(message).font(.body).foregroundColor(.secondary)
                Button("Done") { onDone() }.buttonStyle(PrimaryButtonStyle(color: themeColor)).padding(.top)
            } else {
                ProgressView().scaleEffect(2.0).padding(.bottom)
                Text("Saving Note...").font(.title2).fontWeight(.semibold)
                Text(message).font(.body).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
