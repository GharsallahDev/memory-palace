import Foundation

@MainActor
class PersonManager: ObservableObject {
    @Published var people: [Person] = []
    @Published var isLoading = false
    @Published var statusMessage = ""
    
    init() {}
    
    func addPerson(name: String, relationship: String?, networkManager: NetworkManager) async -> Person? {
        guard !isLoading else {
            statusMessage = "Please wait for the current operation to finish."
            return nil
        }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusMessage = "Person name cannot be empty"
            return nil
        }
        
        isLoading = true
        
        let result = await networkManager.uploadPerson(name: trimmedName, relationship: relationship)
        
        isLoading = false
        
        switch result {
        case .success(let newPerson):
            self.people.append(newPerson)
            self.people.sort { $0.name < $1.name }
            statusMessage = "Added '\(trimmedName)'"
            return newPerson
            
        case .alreadyExists:
            statusMessage = "'\(trimmedName)' already exists."
            await fetchAllPeopleFromServer(networkManager: networkManager)
            return people.first { $0.name.lowercased() == trimmedName.lowercased() }
            
        case .failure:
            statusMessage = networkManager.statusMessage.isEmpty ? "Failed to add person." : networkManager.statusMessage
            return nil
        }
    }
    
    func deletePerson(_ person: Person, networkManager: NetworkManager) async {
        guard let serverId = person.serverId else {
            statusMessage = "Cannot delete a person without a server ID."
            return
        }
        
        let success = await networkManager.deletePerson(personId: serverId)
        
        if success {
            people.removeAll { $0.id == person.id }
            statusMessage = "Removed '\(person.name)'"
        } else {
            statusMessage = "Failed to remove '\(person.name)' from server."
            await fetchAllPeopleFromServer(networkManager: networkManager)
        }
    }
    
    func findPerson(by name: String) -> Person? {
        return people.first { $0.name.lowercased() == name.lowercased() }
    }
    
    func findPerson(by id: UUID) -> Person? {
        return people.first { $0.id == id }
    }
    
    func fetchAllPeopleFromServer(networkManager: NetworkManager) async {
        guard !isLoading else {
            return
        }
        
        isLoading = true
        statusMessage = "Fetching people from memories hub..."
        
        self.people = await networkManager.getAllPeople()
        
        isLoading = false
        statusMessage = "✅ Fetched \(people.count) people"
    }
    
    func clearAllPeople() {
        people.removeAll()
        statusMessage = "Cleared all people from memory."
    }
    
    var peopleCount: Int {
        return people.count
    }
        
    func suggestPeopleForFaces(faceCount: Int, existingMetadata: String = "") -> [String] {
        var suggestions: [String] = []
        
        let metadataPeople = extractNamesFromMetadata(existingMetadata)
        
        for name in metadataPeople {
            if people.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                suggestions.append(name)
            }
        }
        
        let frequentPeople = people
            .sorted { $0.lastSeenAt > $1.lastSeenAt }
            .prefix(faceCount)
            .map { $0.name }
            .filter { !suggestions.contains($0) }
        
        suggestions.append(contentsOf: frequentPeople)
        
        return Array(suggestions.prefix(faceCount))
    }
    
    private func extractNamesFromMetadata(_ metadata: String) -> [String] {
        let commonWords = Set(["and", "with", "the", "a", "an", "in", "at", "on", "for", "to", "of"])
        
        let names = metadata
            .components(separatedBy: CharacterSet(charactersIn: ",;&"))
            .flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 1 && !commonWords.contains($0.lowercased()) }
            .filter { $0.first?.isUppercase == true }
        
        return Array(Set(names))
    }
    
    func getAutocompleteSuggestions(for partial: String) -> [String] {
        guard !partial.isEmpty else { return [] }
        
        let matches = people
            .filter { $0.name.lowercased().hasPrefix(partial.lowercased()) }
            .sorted { $0.lastSeenAt > $1.lastSeenAt }
            .map { $0.name }
        
        return Array(matches.prefix(5))
    }
}
