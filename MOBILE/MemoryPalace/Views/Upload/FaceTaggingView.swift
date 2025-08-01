import SwiftUI
import Vision
import AVFoundation

struct FaceTaggingView: View {
    @ObservedObject var memory: Memory
    let image: UIImage
    let initialFaceTags: [FaceTag]
    let allowRescan: Bool
    
    let onTaggingComplete: ([FaceTag]) -> Void
    let onCancel: () -> Void
    
    @StateObject private var faceDetectionManager = FaceDetectionManager()
    @ObservedObject var personManager: PersonManager
    @ObservedObject var networkManager: NetworkManager
    
    @State private var allFaceTags: [FaceTag]
    @State private var selectedFaceID: UUID?
    @State private var showingPersonSelector = false
    @State private var isRescanning = false
    
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    
    @State private var editingManualTagID: UUID? = nil
    
    init(memory: Memory, image: UIImage, faceTags: [FaceTag], allowRescan: Bool = false, personManager: PersonManager, networkManager: NetworkManager,
         onTaggingComplete: @escaping ([FaceTag]) -> Void,
         onCancel: @escaping () -> Void) {
        self.memory = memory
        self.image = image
        self.initialFaceTags = faceTags
        self.allowRescan = allowRescan
        self.personManager = personManager
        self.networkManager = networkManager
        self.onTaggingComplete = onTaggingComplete
        self.onCancel = onCancel
        self._allFaceTags = State(initialValue: faceTags)
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let imageFrame = AVMakeRect(aspectRatio: image.size, insideRect: geometry.frame(in: .local))

                ZStack {
                    Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
                    
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .allowsHitTesting(editingManualTagID == nil)

                        ForEach($allFaceTags) { $faceTag in
                            FaceOverlayView(
                                faceTag: $faceTag,
                                imageFrame: imageFrame,
                                isSelected: selectedFaceID == faceTag.id,
                                scale: imageScale,
                                editingManualTagID: $editingManualTagID,
                                onTap: {
                                    selectedFaceID = faceTag.id
                                    showingPersonSelector = true
                                },
                                onDelete: {
                                    deleteFaceTag(faceTag.id)
                                }
                            )
                        }
                    }
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .scaleEffect(imageScale)
                    .offset(imageOffset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                if editingManualTagID == nil {
                                    imageScale = max(1.0, value)
                                }
                            }
                            .simultaneously(with:
                                DragGesture()
                                    .onChanged { value in
                                        if editingManualTagID == nil && imageScale > 1.0 {
                                            imageOffset = value.translation
                                        }
                                    }
                            )
                    )

                    if isRescanning {
                        Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                            .overlay(ProgressView("Re-scanning...").progressViewStyle(CircularProgressViewStyle(tint: .white)))
                    }
                }
            }
            .navigationTitle("Tag People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Done") { onTaggingComplete(allFaceTags) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                FaceTaggingToolbar(
                    taggedFaces: $allFaceTags,
                    selectedFaceID: $selectedFaceID,
                    allowRescan: allowRescan,
                    onAddManual: addManualFaceTag,
                    onFaceSelected: { id in selectedFaceID = id; showingPersonSelector = true },
                    onRescan: { Task { await rescanFaces() } },
                    onResetZoom: { withAnimation(.easeInOut(duration: 0.3)) { imageScale = 1.0; imageOffset = .zero } }
                )
            }
        }
        .sheet(isPresented: $showingPersonSelector) {
            if let selectedID = selectedFaceID, let index = allFaceTags.firstIndex(where: { $0.id == selectedID }) {
                PersonSelectorView(
                    personManager: personManager,
                    networkManager: networkManager,
                    onPersonSelected: { person in
                        allFaceTags[index].tagPerson(person)
                        showingPersonSelector = false
                        selectedFaceID = nil
                    },
                    onPersonAdded: { newPerson in
                        allFaceTags[index].tagPerson(newPerson)
                        showingPersonSelector = false
                        selectedFaceID = nil
                    },
                    onCancel: {
                        showingPersonSelector = false
                        selectedFaceID = nil
                    }
                )
            }
        }
    }
    
    private func deleteFaceTag(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.3)) {
            allFaceTags.removeAll { $0.id == id }
            if selectedFaceID == id {
                selectedFaceID = nil
            }
        }
        Haptics.shared.medium()
    }
    
    private func rescanFaces() async {
        isRescanning = true
        let observations = await faceDetectionManager.detectFaces(in: image)
        let newFaceTags = observations.map { FaceTag(memoryId: memory.id, observation: $0) }
        self.allFaceTags = newFaceTags
        isRescanning = false
    }

    private func addManualFaceTag() {
        let defaultBox = FaceBoundingBox(from: CGRect(x: 0.45, y: 0.45, width: 0.1, height: 0.15))
        let manualTag = FaceTag(memoryId: memory.id, boundingBox: defaultBox, isManual: true)
        allFaceTags.append(manualTag)
    }
}

struct FaceOverlayView: View {
    @Binding var faceTag: FaceTag
    let imageFrame: CGRect
    let isSelected: Bool
    let scale: CGFloat
    @Binding var editingManualTagID: UUID?
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var rect: CGRect = .zero
    @State private var resizeOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Rectangle()
                .stroke(borderColor, lineWidth: borderWidth / scale)
                .background(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .overlay(alignment: .top) {
                    if let personName = faceTag.personName {
                        Text(personName)
                            .font(.system(size: 12 / scale))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.init(top: 2/scale, leading: 6/scale, bottom: 2/scale, trailing: 6/scale))
                            .background(Color.blue)
                            .cornerRadius(4 / scale)
                            .fixedSize()
                            .offset(y: -15 / scale)
                    }
                }
                .overlay(alignment: .topLeading) {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20 / scale))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.red.opacity(0.8)))
                    }
                    .offset(x: -10 / scale, y: -10 / scale)
                }
            
            if faceTag.isManual {
                Circle().fill(Color.white.opacity(0.6)).frame(width: 30 / scale, height: 30 / scale)
                    .position(x: (rect.width + resizeOffset.width) / 2, y: (rect.height + resizeOffset.height) / 2)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            editingManualTagID = faceTag.id
                            rect.origin.x += value.translation.width
                            rect.origin.y += value.translation.height
                        }
                        .onEnded { value in
                            faceTag.boundingBox.x = rect.origin.x / imageFrame.width
                            faceTag.boundingBox.y = rect.origin.y / imageFrame.height
                            editingManualTagID = nil
                        }
                    )
                
                Circle().fill(Color.white.opacity(0.8)).frame(width: 30 / scale, height: 30 / scale)
                    .overlay(Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 12 / scale)))
                    .position(x: rect.width + resizeOffset.width, y: rect.height + resizeOffset.height)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            editingManualTagID = faceTag.id
                            resizeOffset = value.translation
                        }
                        .onEnded { value in
                            let newWidth = rect.width + value.translation.width
                            let newHeight = rect.height + value.translation.height
                            
                            faceTag.boundingBox.width = min(max(20, newWidth), imageFrame.width - rect.origin.x) / imageFrame.width
                            faceTag.boundingBox.height = min(max(20, newHeight), imageFrame.height - rect.origin.y) / imageFrame.height
                            
                            resizeOffset = .zero
                            updateLocalRect()
                            editingManualTagID = nil
                        }
                    )
            }
        }
        .frame(width: rect.width + resizeOffset.width, height: rect.height + resizeOffset.height)
        .position(x: rect.midX, y: rect.midY)
        .onAppear(perform: updateLocalRect)
        .onChange(of: faceTag.boundingBox.x) { _ in updateLocalRect() }
        .onChange(of: faceTag.boundingBox.y) { _ in updateLocalRect() }
        .onChange(of: faceTag.boundingBox.width) { _ in updateLocalRect() }
        .onChange(of: faceTag.boundingBox.height) { _ in updateLocalRect() }
    }
    
    private func updateLocalRect() {
        self.rect = CGRect(
            x: faceTag.boundingBox.x * imageFrame.width,
            y: faceTag.boundingBox.y * imageFrame.height,
            width: faceTag.boundingBox.width * imageFrame.width,
            height: faceTag.boundingBox.height * imageFrame.height
        )
    }
    
    private var borderColor: Color {
        if isSelected { return .yellow }
        else if faceTag.isTagged { return .blue }
        else { return .orange }
    }
    
    private var borderWidth: CGFloat { isSelected ? 4 : 2 }
}



struct FaceTaggingToolbar: View {
    @Binding var taggedFaces: [FaceTag]; @Binding var selectedFaceID: UUID?; let allowRescan: Bool
    let onAddManual: () -> Void
    let onFaceSelected: (UUID) -> Void; let onRescan: () -> Void; let onResetZoom: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                Button(action: onAddManual) { Image(systemName: "face.smiling.inverse") }.buttonStyle(ToolbarButtonStyle())
                if allowRescan {
                    Button(action: onRescan) { Image(systemName: "arrow.clockwise.circle") }.buttonStyle(ToolbarButtonStyle())
                }
                Button(action: onResetZoom) { Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left") }.buttonStyle(ToolbarButtonStyle())
            }
            .padding(.leading, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if taggedFaces.isEmpty {
                         Text("No faces detected. Add one manually.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else {
                        ForEach($taggedFaces) { $faceTag in
                            FaceTagButton(faceTag: faceTag, isSelected: selectedFaceID == faceTag.id) { onFaceSelected(faceTag.id) }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            VStack {
                Text("\(taggedFaces.filter(\.isTagged).count)/\(taggedFaces.count)")
                    .font(.caption.bold())
                Text("Tagged")
                    .font(.caption2)
            }
            .frame(width: 60)
            .foregroundColor(.secondary)
            .padding(.trailing, 8)
        }
        .frame(height: 75)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }
}


struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .foregroundColor(.accentColor)
            .frame(width: 44, height: 44)
            .background(configuration.isPressed ? Color.gray.opacity(0.2) : Color.clear)
            .clipShape(Circle())
    }
}


struct FaceTagButton: View {
    let faceTag: FaceTag; let isSelected: Bool; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(faceTag.isTagged ? Color.blue.opacity(0.8) : Color.orange.opacity(0.8)).frame(width: 44, height: 44).overlay(Circle().stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 3))
                    if faceTag.isTagged { Text(faceTag.personName?.prefix(1) ?? "?").font(.title3).fontWeight(.bold).foregroundColor(.white) }
                    else { Text("?").font(.title3).fontWeight(.bold).foregroundColor(.white) }
                }
                Text(faceTag.personName ?? "Untagged").font(.caption2).lineLimit(1).truncationMode(.tail).foregroundColor(faceTag.isTagged ? .primary : .orange)
            }
        }.frame(width: 60)
    }
}

struct PersonSelectorView: View {
    @ObservedObject var personManager: PersonManager
    @ObservedObject var networkManager: NetworkManager
    
    let onPersonSelected: (Person) -> Void
    let onPersonAdded: (Person) -> Void
    let onCancel: () -> Void
    
    @State private var searchText = ""
    @State private var showingAddPersonSheet = false
    
    var filteredPeople: [Person] {
        let sortedPeople = personManager.people.sorted {
            if $0.isPrimary { return true }
            if $1.isPrimary { return false }
            return $0.name.lowercased() < $1.name.lowercased()
        }
        
        if searchText.isEmpty {
            return sortedPeople
        } else {
            return sortedPeople.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: { showingAddPersonSheet = true }) {
                        Label("Add New Person", systemImage: "plus.circle.fill")
                    }
                }
                
                Section(header: Text("Select Person")) {
                    ForEach(filteredPeople) { person in
                        Button(action: { onPersonSelected(person) }) {
                             HStack {
                                if person.isPrimary {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                }
                                Text(person.name)
                                if let relationship = person.relationship {
                                    Text("(\(relationship))").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .foregroundColor(.primary)
                        .listRowBackground(person.isPrimary ? Color.blue.opacity(0.1) : nil)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Select Person")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel", action: onCancel))
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .sheet(isPresented: $showingAddPersonSheet) {
                AddPersonView(
                    personManager: personManager,
                    networkManager: networkManager,
                    onPersonAdded: { newPerson in
                        onPersonAdded(newPerson)
                        showingAddPersonSheet = false
                    }
                )
            }
        }
    }
}
