import SwiftUI

struct PersonDetailView: View {
    @State var person: Person
    @ObservedObject var personManager: PersonManager
    @ObservedObject var networkManager: NetworkManager
    @Environment(\.dismiss) private var dismiss

    let onUpdate: (Person) -> Void
    let onDelete: (Int) -> Void

    @State private var showingEditPerson = false
    @State private var showingDeleteAlert = false
    
    @State private var recentMemories: [Memory] = []
    @State private var isLoadingMemories = false
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.blue.opacity(0.1), .clear, .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Constants.UI.largeSpacing) {
                    personHeader
                    statisticsSection
                    recentActivitySection
                }
                .padding(.vertical)
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    
                    if person.isPrimary == false {
                        Menu {
                            Button("Edit Person") { showingEditPerson = true }
                            Button("Delete Person", role: .destructive) { showingDeleteAlert = true }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 5)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            fetchRecentMemories()
        }
        .sheet(isPresented: $showingEditPerson) {
            EditPersonView(
                person: person,
                personManager: personManager,
                networkManager: networkManager,
                onUpdate: { updatedPerson in
                    self.person = updatedPerson
                    self.onUpdate(updatedPerson)
                }
            )
        }
        .alert("Delete Person", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deletePerson() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(person.name)'? This will remove them from all memories.")
        }
    }
    
    private var personHeader: some View {
        VStack(spacing: Constants.UI.mediumSpacing) {
            AvatarView(person: person, size: 120)
                .shadow(color: .blue.opacity(0.4), radius: 10, y: 5)
            
            VStack {
                Text(person.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let relationship = person.relationship, !relationship.isEmpty {
                    Text(relationship)
                        .font(.title3)
                        .foregroundColor(.secondary)
                } else {
                    Text("No relationship specified")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Constants.UI.mediumSpacing)
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: Constants.UI.mediumSpacing) {
            Text("Information")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            VStack(spacing: Constants.UI.mediumSpacing) {
                DetailRow(icon: "calendar.badge.plus", title: "Added", content: person.createdAt.formattedForMemory)
                DetailRow(icon: "sparkles", title: "Last Seen", content: person.lastSeenAt.timeAgo)
                if let serverId = person.serverId, serverId != -1 {
                    DetailRow(icon: "number", title: "Person ID", content: "#\(serverId)")
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(Constants.UI.largeCornerRadius)
            .padding(.horizontal)
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Constants.UI.mediumSpacing) {
            HStack {
                Text("Appears In")
                    .font(.title2)
                    .fontWeight(.semibold)
                if !recentMemories.isEmpty {
                    Text("(\(recentMemories.count))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            if isLoadingMemories {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if recentMemories.isEmpty {
                PlaceholderView(icon: "photo.badge.plus", title: "No Memories Yet", message: "This person hasn't been tagged in any memories yet.")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(Constants.UI.largeCornerRadius)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(recentMemories) { memory in
                            MemoryGridCard(memory: memory) {
                            }
                            .frame(width: 150)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func deletePerson() {
        guard let serverId = person.serverId else { return }
        Task {
            let success = await networkManager.deletePerson(personId: serverId)
            if success {
                await MainActor.run {
                    onDelete(serverId)
                    dismiss()
                }
            }
        }
    }
    
    private func fetchRecentMemories() {
        guard let serverId = person.serverId, serverId != -1 else { return }
        isLoadingMemories = true
        Task {
            let fetched = await networkManager.getMemoriesForPerson(personId: serverId)
            await MainActor.run {
                self.recentMemories = fetched
                self.isLoadingMemories = false
            }
        }
    }
}

struct EditPersonView: View {
    let person: Person
    @ObservedObject var personManager: PersonManager
    @ObservedObject var networkManager: NetworkManager
    @Environment(\.dismiss) private var dismiss
    
    let onUpdate: (Person) -> Void

    @State private var name: String
    @State private var relationship: RelationshipType
    @State private var otherRelationship: String = ""
    @State private var isSaving = false
    @State private var showNameError = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

   enum RelationshipType: String, CaseIterable, Identifiable {
    case none = "None"
    case friend = "Friend", father = "Father", mother = "Mother", spouse = "Spouse"
    case son = "Son", daughter = "Daughter", brother = "Brother", sister = "Sister"
    case grandfather = "Grandfather", grandmother = "Grandmother"
    case grandson = "Grandson", granddaughter = "Granddaughter"
    case uncle = "Uncle", aunt = "Aunt"
    case cousin = "Cousin", nephew = "Nephew", niece = "Niece"
    case other = "Other"
    
    var id: String { self.rawValue }
}
    
    init(person: Person, personManager: PersonManager, networkManager: NetworkManager, onUpdate: @escaping (Person) -> Void) {
        self.person = person
        self.personManager = personManager
        self.networkManager = networkManager
        self.onUpdate = onUpdate
        
        _name = State(initialValue: person.name)
        
        if let personRel = person.relationship, !personRel.isEmpty {
            if let matchingType = RelationshipType(rawValue: personRel) {
                _relationship = State(initialValue: matchingType)
            } else {
                _relationship = State(initialValue: .other)
                _otherRelationship = State(initialValue: personRel)
            }
        } else {
            _relationship = State(initialValue: .none)
        }
    }

    private var finalRelationship: String? {
        switch relationship {
        case .none:
            return nil
        case .other:
            let trimmed = otherRelationship.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        default:
            return relationship.rawValue
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Person Details"),
                    footer: Group {
                        if showNameError {
                            Text("A name is required.").font(.caption).foregroundColor(.red)
                        }
                    }
                ) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .frame(width: 25)
                        TextField("Full Name", text: $name)
                    }
                    .listRowBackground(showNameError ? Color.red.opacity(0.15) : nil)
                    
                    HStack {
                        Image(systemName: "heart.text.square.fill")
                            .foregroundColor(.pink)
                            .frame(width: 25)
                        Picker("Relationship", selection: $relationship) {
                            ForEach(RelationshipType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                    }
                    
                    if relationship == .other {
                        HStack {
                            Image(systemName: "text.cursor")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            TextField("Custom Relationship", text: $otherRelationship)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.default, value: relationship)
                
                if isSaving {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("Saving...")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Person")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    Task { await saveChanges() }
                }.disabled(isSaving)
            )
        }
        .alert("Update Failed", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    private func saveChanges() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            withAnimation { showNameError = true }
            return
        }
        showNameError = false
        
        guard let serverId = person.serverId else {
            alertMessage = "Cannot update person: missing a valid server ID."
            showingAlert = true
            return
        }
        
        isSaving = true
        
        let success = await networkManager.updatePerson(
            personId: serverId,
            name: trimmedName,
            relationship: finalRelationship
        )
        
        isSaving = false
        
        if success {
            var updatedPerson = self.person
            updatedPerson.name = trimmedName
            updatedPerson.relationship = finalRelationship
            
            onUpdate(updatedPerson)
            dismiss()
        } else {
            alertMessage = "There was a problem saving the changes. Please check your connection and try again."
            showingAlert = true
        }
    }
}
