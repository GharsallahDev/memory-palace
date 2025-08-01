import SwiftUI

struct PersonMultiSelectorView: View {
    @ObservedObject var personManager: PersonManager
    @ObservedObject var networkManager: NetworkManager
    @Binding var selectedPersonIDs: Set<UUID>
    let themeColor: Color

    @State private var showingPersonSelector = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(themeColor)
                    .frame(width: 25, alignment: .center)
                Text("Who was there?")
                
                Spacer()
                
                Text("Select")
                    .font(.callout)
                    .foregroundColor(.blue)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingPersonSelector = true
            }
            
            if selectedPersonIDs.isEmpty {
                Text("Tap 'Select' to add people")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 33)
            } else {
                FlexibleView(data: Array(selectedPersonIDs)) { personID in
                    if let person = personManager.findPerson(by: personID) {
                        PersonSelectorChip(
                            name: person.name,
                            onRemove: {
                                selectedPersonIDs.remove(personID)
                            }
                        )
                    }
                }
                .padding(.leading, 33)
            }
        }
        .sheet(isPresented: $showingPersonSelector) {
            MultiSelectSheetView(
                personManager: personManager,
                networkManager: networkManager,
                selectedPersonIDs: $selectedPersonIDs
            )
        }
    }
}

struct PersonSelectorChip: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(16)
    }
}

struct MultiSelectSheetView: View {
    @ObservedObject var personManager: PersonManager
    @ObservedObject var networkManager: NetworkManager
    @Binding var selectedPersonIDs: Set<UUID>
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddPersonSheet = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: { showingAddPersonSheet = true }) {
                        Label("Add New Person", systemImage: "plus.circle.fill")
                    }
                }
                
                Section(header: Text("Select from existing")) {
                    ForEach(personManager.people.sorted(by: {
                        if $0.isPrimary { return true }
                        if $1.isPrimary { return false }
                        return $0.name.lowercased() < $1.name.lowercased()
                    }), id: \.id) { person in
                        Button(action: {
                            toggleSelection(for: person)
                        }) {
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
                                if selectedPersonIDs.contains(person.id) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                                } else {
                                    Image(systemName: "circle").foregroundColor(.secondary)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                        .listRowBackground(person.isPrimary ? Color.blue.opacity(0.1) : nil)
                    }
                }
            }
            .navigationTitle("Select People")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .sheet(isPresented: $showingAddPersonSheet) {
                AddPersonView(
                    personManager: personManager,
                    networkManager: networkManager,
                    onPersonAdded: { newPerson in
                        selectedPersonIDs.insert(newPerson.id)
                        showingAddPersonSheet = false
                    }
                )
            }
        }
    }

    private func toggleSelection(for person: Person) {
        if selectedPersonIDs.contains(person.id) {
            selectedPersonIDs.remove(person.id)
        } else {
            selectedPersonIDs.insert(person.id)
        }
    }
}
