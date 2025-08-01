import SwiftUI
import AVKit

struct MemoryDetailView: View {
    @ObservedObject var memory: Memory
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    @Environment(\.dismiss) private var dismiss
    let onDelete: (Int) -> Void

    @State private var showingEditMemory = false
    @State private var showingDeleteAlert = false
    
    @State private var showFaceOverlays = false
    @State private var loadedImage: UIImage? = nil
    
    private var hasDetailsContent: Bool {
        !memory.description.isEmpty || !memory.metadata.whenWasThis.isEmpty || !memory.metadata.whereWasThis.isEmpty
    }
    
    private var formattedWhenDate: String {
        guard !memory.metadata.whenWasThis.isEmpty else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        return formatter.date(from: memory.metadata.whenWasThis).map { dateFormatter.string(from: $0) } ?? memory.metadata.whenWasThis
    }
    
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    mediaSection
                    memoryDetailsSection
                    peopleSection
                    technicalDetailsSection
                }
                .padding()
            }
            .navigationTitle(memory.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Memory") { showingEditMemory = true }
                        Button("Delete Memory", role: .destructive) { showingDeleteAlert = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .sheet(isPresented: $showingEditMemory) {
            EditMemoryView(memory: memory, networkManager: networkManager, personManager: personManager, themeColor: colorFor(type: memory.type))
        }
        .alert("Delete Memory", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteMemory() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Are you sure you want to delete '\(memory.title)'?") }
    }
    
    @ViewBuilder
    private var mediaSection: some View {
        switch memory.type {
        case .photo: PhotoMediaView(memory: memory, showFaceOverlays: $showFaceOverlays, loadedImage: $loadedImage)
        case .video: VideoMediaView(memory: memory)
        case .text: TextMediaView(memory: memory)
        case .voice: VoiceMediaView(memory: memory)
        }
    }
    
    private var memoryDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details").font(.title2).fontWeight(.semibold)
            VStack(alignment: .leading, spacing: 16) {
                if hasDetailsContent {
                    if !memory.description.isEmpty {
                        DetailRow(icon: "text.alignleft", title: "Description", content: memory.description)
                    }
                    
                    if !memory.metadata.whenWasThis.isEmpty {
                        DetailRow(icon: "clock", title: "When", content: formattedWhenDate)
                    }
                    
                    if !memory.metadata.whereWasThis.isEmpty {
                        DetailRow(icon: "mappin.and.ellipse", title: "Where", content: memory.metadata.whereWasThis)
                    }
                } else {
                    PlaceholderView(
                        icon: "square.text.square.fill",
                        title: "No Details Provided",
                        message: "You can add a description, time, or place by editing this memory."
                    )
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("People").font(.title2).fontWeight(.semibold)
                Spacer()
                if memory.detectedFaceCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "face.dashed")
                        Text("\(memory.faceTags.filter { $0.isTagged }.count) / \(memory.detectedFaceCount) tagged")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                let textPeople = Set(memory.metadata.detectedPeople)
                let taggedPeopleInFaces = Set(memory.faceTags.compactMap { $0.personName })
                let allPeopleWithNames = Array(textPeople.union(taggedPeopleInFaces)).sorted()
                let hasAnyPeopleInfo = !allPeopleWithNames.isEmpty || memory.hasUntaggedFaces
                
                if hasAnyPeopleInfo {
                    if !allPeopleWithNames.isEmpty {
                        FlexibleView(data: allPeopleWithNames) { personName in
                            PersonChip(name: personName, isKnown: personManager.findPerson(by: personName) != nil)
                        }
                    }
                    
                    if memory.hasUntaggedFaces {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Some faces haven't been tagged yet.")
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, allPeopleWithNames.isEmpty ? 0 : 8)
                    }
                } else {
                    PlaceholderView(
                        icon: "person.2.slash.fill",
                        title: "No People Mentioned",
                        message: "You can tag faces or add people by editing this memory."
                    )
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var technicalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Technical Details").font(.title2).fontWeight(.semibold)
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(icon: "number", title: "Memory ID", content: "#\(memory.serverId)")
                DetailRow(icon: "calendar", title: "Added", content: memory.timestamp.formattedForMemory)
                DetailRow(icon: "iphone", title: "Device", content: memory.deviceName)
                if let duration = memory.metadata.duration, (memory.type == .voice || memory.type == .video) {
                    DetailRow(icon: "hourglass", title: "Duration", content: duration.formattedDuration)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func deleteMemory() {
        Task {
            let success = await networkManager.deleteMemory(memory.serverId)
            if success {
                await MainActor.run { onDelete(memory.serverId); dismiss() }
            }
        }
    }
    
    private func colorFor(type: MemoryType) -> Color {
        switch type {
        case .photo: return .blue
        case .video: return .purple
        case .voice: return .orange
        case .text: return .green
        }
    }
}

struct PlaceholderView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.bottom, 4)
            
            Text(title).font(.headline).foregroundColor(.primary.opacity(0.8))
            Text(message).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).frame(maxWidth: 300)
        }
        .padding()
    }
}
struct PhotoMediaView: View {
    @ObservedObject var memory: Memory
    @Binding var showFaceOverlays: Bool
    @Binding var loadedImage: UIImage?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let imageUrlString = memory.imageUrl, let imageUrl = URL(string: imageUrlString) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        Rectangle().fill(Color.gray.opacity(0.2)).aspectRatio(4/3, contentMode: .fit).cornerRadius(12).overlay(ProgressView())
                    case .success(let image):
                        ZStack {
                            image.resizable().aspectRatio(contentMode: .fit)
                                .onAppear {
                                    let renderer = ImageRenderer(content: image)
                                    self.loadedImage = renderer.uiImage
                                }
                            if showFaceOverlays, let loadedImage = loadedImage {
                                GeometryReader { geometry in
                                    let imageFrame = AVMakeRect(aspectRatio: loadedImage.size, insideRect: geometry.frame(in: .local))
                                    ForEach(memory.faceTags) { faceTag in
                                        FaceBoundingBoxView(
                                            faceTag: faceTag,
                                            imageFrame: imageFrame,
                                            isSelected: false,
                                            imageScale: 1.0
                                        )
                                    }
                                }
                            }
                        }
                    case .failure:
                        Rectangle().fill(Color.red.opacity(0.2)).aspectRatio(4/3, contentMode: .fit).cornerRadius(12).overlay(Text("Failed to load"))
                    @unknown default: EmptyView()
                    }
                }.cornerRadius(12)
            }
            
            if !memory.faceTags.isEmpty {
                Button(action: { withAnimation { showFaceOverlays.toggle() } }) {
                    Image(systemName: showFaceOverlays ? "person.fill.viewfinder" : "person.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
                .padding(10)
            }
        }
    }
}

struct VoiceMediaView: View {
    let memory: Memory
    @StateObject private var audioManager = AudioManager()
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [.orange.opacity(0.7), .red.opacity(0.7)], startPoint: .top, endPoint: .bottom)).frame(height: 120)
                VStack(spacing: 8) {
                    Image(systemName: "waveform").font(.largeTitle).foregroundColor(.white)
                    if let duration = memory.metadata.duration { Text(duration.formattedDuration).font(.title2).fontWeight(.bold).foregroundColor(.white) }
                }
            }
            HStack(spacing: 24) {
                Button(action: togglePlayback) { Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 50)).foregroundColor(.orange) }
                if let duration = memory.metadata.duration { ProgressView(value: audioManager.playbackTime, total: duration).progressViewStyle(LinearProgressViewStyle(tint: .orange)) }
            }
        }.onDisappear { audioManager.stopPlayback() }
    }
    private func togglePlayback() { guard let urlString = memory.audioUrl, let url = URL(string: urlString) else { return }; if audioManager.isPlaying { audioManager.pausePlayback() } else { Task { await audioManager.playAudio(from: url) } } }
}

struct VideoMediaView: View {
    let memory: Memory
    var body: some View {
        VStack {
            if let videoUrlString = memory.videoUrl, let videoUrl = URL(string: videoUrlString) {
                VideoPlayer(player: AVPlayer(url: videoUrl)).aspectRatio(16/9, contentMode: .fit).cornerRadius(12)
            } else {
                Rectangle().fill(Color.gray.opacity(0.2)).aspectRatio(16/9, contentMode: .fit).cornerRadius(12).overlay(Text("Video not available").foregroundColor(.secondary))
            }
        }
    }
}

struct TextMediaView: View {
    let memory: Memory
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content").font(.title2).fontWeight(.semibold)
            Text(memory.content).font(.body).frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.systemGray6)).cornerRadius(12)
        }
    }
}

struct EditMemoryView: View {
    @ObservedObject var memory: Memory
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    let themeColor: Color
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var content: String
    @State private var selectedPersonIDs: Set<UUID>
    @State private var whenWasThis: Date?
    @State private var whereWasThis: String
    @State private var isSaving = false
    @State private var showTitleError = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    @State private var showDatePicker = false

    init(memory: Memory, networkManager: NetworkManager, personManager: PersonManager, themeColor: Color) {
        self._memory = ObservedObject(initialValue: memory)
        self.networkManager = networkManager
        self.personManager = personManager
        self.themeColor = themeColor
        
        _title = State(initialValue: memory.title)
        _description = State(initialValue: memory.description)
        _content = State(initialValue: memory.content)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        _whenWasThis = State(initialValue: dateFormatter.date(from: memory.metadata.whenWasThis))
        
        _whereWasThis = State(initialValue: memory.metadata.whereWasThis)
        
        let namesFromString = memory.metadata.whoWasThere.extractNames()
        let allNames = Set(namesFromString).union(Set(memory.taggedPeople))
        
        var initialIDs = Set<UUID>()
        for name in allNames {
            if let person = personManager.findPerson(by: name) {
                initialIDs.insert(person.id)
            }
        }
        _selectedPersonIDs = State(initialValue: initialIDs)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Memory Details"), footer: Group { if showTitleError { Text("A title is required.").font(.caption).foregroundColor(.red) } }) {
                    HStack { Image(systemName: "text.quote").foregroundColor(themeColor).frame(width: 25); TextField("Title", text: $title) }.listRowBackground(showTitleError ? Color.red.opacity(0.15) : nil)
                    VStack(alignment: .leading) { HStack { Image(systemName: "text.alignleft").foregroundColor(themeColor).frame(width: 25); Text("Description").font(.caption).foregroundColor(.secondary) }; TextEditor(text: $description).frame(minHeight: 100).padding(.leading, 33) }
                }
                if memory.type == .text { Section(header: Text("Note Content")) { TextEditor(text: $content).frame(minHeight: 200) } }
                Section(header: Text("Context")) {
                    PersonMultiSelectorView(personManager: personManager, networkManager: networkManager, selectedPersonIDs: $selectedPersonIDs, themeColor: themeColor)
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
                    HStack { Image(systemName: "mappin.and.ellipse").foregroundColor(themeColor).frame(width: 25); TextField("Where was this?", text: $whereWasThis) }
                }
                if isSaving { Section { HStack { Spacer(); ProgressView(); Text("Saving..."); Spacer() } } }
            }
            .navigationTitle("Edit Memory").navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") { dismiss() }, trailing: Button("Save") { Task { await saveChanges() } }.disabled(isSaving))
            .onAppear {
                showDatePicker = (whenWasThis != nil)
            }
        }
        .alert("Update Memory", isPresented: $showingAlert) { Button("OK") { } } message: { Text(alertMessage) }
    }

    private func saveChanges() async {
        if title.trimmed.isEmpty { showTitleError = true; return }
        showTitleError = false
        isSaving = true
        
        let whoWasThereNames = selectedPersonIDs.compactMap { personManager.findPerson(by: $0)?.name }
        let whoWasThereString = whoWasThereNames.joined(separator: ", ")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formattedWhenWasThis = whenWasThis.map { dateFormatter.string(from: $0) } ?? ""
        
        let updateData: [String: String] = [
            "title": title,
            "description": description,
            "content": content,
            "whoWasThere": whoWasThereString,
            "whenWasThis": formattedWhenWasThis,
            "whereWasThis": whereWasThis
        ]
        
        let success = await networkManager.updateMemory(memoryId: memory.serverId, updateData: updateData)
        isSaving = false
        if success {
            memory.title = title
            memory.description = description
            memory.content = content
            memory.metadata = MemoryMetadata(whoWasThere: whoWasThereString, whenWasThis: formattedWhenWasThis, whereWasThis: whereWasThis, context: description, duration: memory.metadata.duration, photoCount: memory.metadata.photoCount)
            dismiss()
        } else {
            alertMessage = "Failed to update memory on the server."
            showingAlert = true
        }
    }
}

struct DetailRow: View {
    let icon: String; let title: String; let content: String
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon).font(.subheadline).foregroundColor(.blue).frame(width: 20, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                Text(content).font(.body).foregroundColor(.primary)
            }
            Spacer()
        }
    }
}
struct PersonChip: View {
    let name: String; let isKnown: Bool
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(isKnown ? Color.green : Color.orange).frame(width: 8, height: 8)
            Text(name).font(.subheadline).fontWeight(.medium)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(isKnown ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(16)
        .foregroundColor(isKnown ? .green : .orange)
    }
}

struct FaceBoundingBoxView: View {
    let faceTag: FaceTag
    let imageFrame: CGRect
    let isSelected: Bool
    let imageScale: CGFloat
    
    private var boxRect: CGRect {
        return CGRect(
            x: imageFrame.origin.x + (faceTag.boundingBox.x * imageFrame.width),
            y: imageFrame.origin.y + (faceTag.boundingBox.y * imageFrame.height),
            width: faceTag.boundingBox.width * imageFrame.width,
            height: faceTag.boundingBox.height * imageFrame.height
        )
    }
    
    private var borderColor: Color {
        if isSelected { return .yellow }
        else if faceTag.isTagged { return .blue }
        else { return .orange }
    }
    
    private var borderWidth: CGFloat { isSelected ? 4 / imageScale : 2 / imageScale }
    
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .stroke(borderColor, lineWidth: borderWidth)
                .overlay(alignment: .top) {
                    if let name = faceTag.personName {
                        Text(name)
                            .font(.system(size: 12 / imageScale))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.init(top: 2/imageScale, leading: 6/imageScale, bottom: 2/imageScale, trailing: 6/imageScale))
                            .background(Color.blue)
                            .cornerRadius(4 / imageScale)
                            .fixedSize()
                            .offset(y: -15 / imageScale)
                    }
                }
        }
        .frame(width: boxRect.width, height: boxRect.height)
        .position(x: boxRect.midX, y: boxRect.midY)
    }
}
