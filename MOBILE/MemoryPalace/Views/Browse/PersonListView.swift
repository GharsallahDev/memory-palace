import SwiftUI

struct PersonListView: View {
    @ObservedObject var personManager: PersonManager
    @ObservedObject var networkManager: NetworkManager
    
    @State private var searchText = ""
    @State private var showingAddPerson = false
    @State private var showingPersonDetail: Person?
    @State private var personToEdit: Person?
    @State private var selectedFilter: PersonFilter = .all
    @State private var isLoading = false
    
    enum PersonFilter: String, CaseIterable {
        case all = "All", family = "Family", friends = "Friends", recent = "Recent"
        var icon: String {
            switch self {
            case .all: return "person.2"
            case .family: return "house"
            case .friends: return "person.3"
            case .recent: return "clock"
            }
        }
    }
    
    var filteredPeople: [Person] {
        var filtered = personManager.people
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        switch selectedFilter {
        case .all:
            break
        case .family:
            let familyTerms = ["father", "mother", "son", "daughter", "brother", "sister", "spouse", "grandson","granddaughter","grandfather", "grandmother", "uncle", "aunt", "cousin", "nephew", "niece"]
            filtered = filtered.filter { person in
                guard let relationship = person.relationship?.lowercased() else { return false }
                return familyTerms.contains(relationship)
            }
        case .friends:
            filtered = filtered.filter { person in
                let relationship = person.relationship?.lowercased() ?? ""
                return relationship == "friend" || relationship.isEmpty
            }
        case .recent:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            filtered = filtered.filter { $0.lastSeenAt > sevenDaysAgo }
        }
        
        return filtered.sorted {
            if $0.isPrimary { return true }
            if $1.isPrimary { return false }
            return $0.name.lowercased() < $1.name.lowercased()
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: Constants.UI.mediumSpacing) {
                    SearchBar(text: $searchText, placeholder: "Search people...")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Constants.UI.mediumSpacing) {
                            ForEach(PersonFilter.allCases, id: \.self) { filter in
                                Button(action: { selectedFilter = filter }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: filter.icon).font(.caption)
                                        Text(filter.rawValue).font(.subheadline).fontWeight(.medium)
                                        if getFilterCount(filter) > 0 {
                                            Text("\(getFilterCount(filter))")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(selectedFilter == filter ? .white : .secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(selectedFilter == filter ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                                                .cornerRadius(8)
                                        }
                                    }
                                    .foregroundColor(selectedFilter == filter ? .white : .blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedFilter == filter ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(20)
                                }
                            }
                        }.padding(.horizontal)
                    }
                    .frame(height: 44)
                    .clipped()
                }.padding().background(Color(.systemGroupedBackground))
                
                ZStack {
                    List {
                        ForEach(filteredPeople) { person in
                            PersonListRow(person: person) {
                                showingPersonDetail = person
                            }
                            .listRowBackground(person.isPrimary ? Color.blue.opacity(0.1) : nil)
                            .if(person.isPrimary == false) { view in
                                view.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deletePerson(person: person)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        personToEdit = person
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    
                    if filteredPeople.isEmpty && !isLoading {
                        EmptyPeopleView(filter: selectedFilter, searchText: searchText)
                    }
                    if isLoading { LoadingView() }
                }
            }
            .refreshable { await refreshPeopleAsync() }
            .navigationTitle("People")
            .navigationBarItems(trailing:
                HStack(spacing: 16) {
                    Button(action: refreshPeople) {
                        Image(systemName: "arrow.clockwise")
                    }.disabled(isLoading)
                    Button(action: { showingAddPerson = true }) {
                        Image(systemName: "plus")
                    }
                }
            )
            .sheet(isPresented: $showingAddPerson) {
                AddPersonView(
                    personManager: personManager,
                    networkManager: networkManager,
                    onPersonAdded: { _ in
                     }
                )
            }
            .sheet(item: $showingPersonDetail) { person in
                 PersonDetailView(
                    person: person,
                    personManager: personManager,
                    networkManager: networkManager,
                    onUpdate: { updatedPerson in
                        if let index = personManager.people.firstIndex(where: { $0.id == updatedPerson.id }) {
                            personManager.people[index] = updatedPerson
                        }
                    },
                    onDelete: { deletedPersonId in
                        personManager.people.removeAll(where: { $0.serverId == deletedPersonId })
                    }
                )
            }
            .sheet(item: $personToEdit) { person in
                EditPersonView(
                    person: person,
                    personManager: personManager,
                    networkManager: networkManager,
                    onUpdate: { updatedPerson in
                        if let index = personManager.people.firstIndex(where: { $0.id == updatedPerson.id }) {
                            personManager.people[index] = updatedPerson
                        }
                    }
                )
            }
            .onAppear {
                if personManager.people.isEmpty {
                    refreshPeople()
                }
            }
        }
    }
    
    private func getFilterCount(_ filter: PersonFilter) -> Int {
        switch filter {
        case .all: return personManager.people.count
        case .family:
            let familyTerms = ["father", "mother", "son", "daughter", "brother", "sister", "spouse", "grandson","granddaughter", "grandfather", "grandmother", "uncle", "aunt", "cousin", "nephew", "niece"]
            return personManager.people.filter { person in
                guard let relationship = person.relationship?.lowercased() else { return false }
                return familyTerms.contains(relationship)
            }.count
        case .friends:
            return personManager.people.filter { person in
                let relationship = person.relationship?.lowercased() ?? ""
                return relationship == "friend" || relationship.isEmpty
            }.count
        case .recent:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return personManager.people.filter { $0.lastSeenAt > sevenDaysAgo }.count
        }
    }
    
    private func refreshPeople() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            await personManager.fetchAllPeopleFromServer(networkManager: networkManager)
            await MainActor.run { isLoading = false }
        }
    }
    
    private func refreshPeopleAsync() async {
        await personManager.fetchAllPeopleFromServer(networkManager: networkManager)
    }
    
    private func deletePerson(person: Person) {
        Task {
            await personManager.deletePerson(person, networkManager: networkManager)
        }
    }
}

struct PersonListRow: View {
    let person: Person
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Constants.UI.mediumSpacing) {
                AvatarView(person: person, size: 44)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if person.isPrimary {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                        Text(person.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    if let relationship = person.relationship, !relationship.isEmpty {
                        Text(relationship)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No relationship specified")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(person.lastSeenAt.formattedShort)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AvatarView: View {
    let person: Person
    let size: CGFloat
    
    var body: some View {
        if let avatarUrlString = person.avatarUrl, let url = URL(string: avatarUrlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    DefaultAvatar(person: person, size: size)
                case .empty:
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: size, height: size)
                        .overlay(ProgressView())
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            DefaultAvatar(person: person, size: size)
        }
    }
}

struct DefaultAvatar: View {
    let person: Person
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: size, height: size)
            
            Text(String(person.name.prefix(1)))
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(.white)
        }
    }
}


struct EmptyPeopleView: View {
    let filter: PersonListView.PersonFilter
    let searchText: String
    
    var body: some View {
        VStack(spacing: Constants.UI.largeSpacing) {
            Image(systemName: searchText.isEmpty ? filter.icon : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: Constants.UI.smallSpacing) {
                Text(emptyTitle)
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text(emptyMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyTitle: String {
        if !searchText.isEmpty { return "No people found" }
        switch filter {
        case .all: return "No people yet"
        case .family: return "No family members"
        case .friends: return "No friends yet"
        case .recent: return "No recent activity"
        }
    }
    
    private var emptyMessage: String {
        if !searchText.isEmpty { return "Try adjusting your search terms or check your filters" }
        switch filter {
        case .all: return "Add people to start building your network"
        case .family: return "Add family members to see them here"
        case .friends: return "Add friends to see them here"
        case .recent: return "People seen in the last 7 days will appear here"
        }
    }
}

struct AddPersonView: View {
    @ObservedObject var personManager: PersonManager
    @ObservedObject var networkManager: NetworkManager
    let onPersonAdded: (Person) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var personName = ""
    @State private var relationship: RelationshipType = .friend
    @State private var otherRelationship = ""
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showTitleError = false

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

    private var finalRelationship: String {
        let trimmedOther = otherRelationship.trimmingCharacters(in: .whitespacesAndNewlines)
        if relationship == .other {
            return trimmedOther.isEmpty ? "Other" : trimmedOther
        }
        return relationship.rawValue
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Person Details"),
                    footer: Group {
                        if showTitleError {
                            Text("A name is required.").font(.caption).foregroundColor(.red)
                        }
                    }
                ) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .frame(width: 25)
                        TextField("Full Name", text: $personName)
                    }
                    .listRowBackground(showTitleError ? Color.red.opacity(0.15) : nil)
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                            .frame(width: 25)
                        Picker("Relationship", selection: $relationship) {
                            ForEach(RelationshipType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
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
                
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("Adding person...")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    Task { await addPerson() }
                }.disabled(isLoading)
            )
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: { Text(alertMessage) }
    }

    private func addPerson() async {
        let trimmedName = personName.trimmed
        if trimmedName.isEmpty {
            showTitleError = true
            Haptics.shared.error()
            return
        }
        showTitleError = false

        isLoading = true
        if let newPerson = await personManager.addPerson(name: trimmedName, relationship: finalRelationship, networkManager: networkManager) {
            onPersonAdded(newPerson)
            dismiss()
        } else {
            alertMessage = personManager.statusMessage
            showingAlert = true
        }
        isLoading = false
    }
}
