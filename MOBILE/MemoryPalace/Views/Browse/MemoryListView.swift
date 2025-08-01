import SwiftUI
import AVKit

struct MemoryListView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var personManager: PersonManager
    
    @State private var memories: [Memory] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedFilter: MemoryFilter = .all
    @State private var showingMemoryDetail: Memory?
    @State private var viewMode: ViewMode = .grid
    
    enum MemoryFilter: String, CaseIterable {
        case all = "All", photos = "Photos", videos = "Videos", voices = "Stories", texts = "Notes"
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .photos: return "photo"
            case .videos: return "video"
            case .voices: return "mic"
            case .texts: return "doc.text"
            }
        }
    }
    
    enum ViewMode: String, CaseIterable {
        case grid = "Grid", list = "List"
        var icon: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
    }
    
    var filteredMemories: [Memory] {
        var filtered = memories
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.description.localizedCaseInsensitiveContains(searchText) || $0.content.localizedCaseInsensitiveContains(searchText) }
        }
        switch selectedFilter {
        case .all: break
        case .photos: filtered = filtered.filterByType(.photo)
        case .videos: filtered = filtered.filterByType(.video)
        case .voices: filtered = filtered.filterByType(.voice)
        case .texts: filtered = filtered.filterByType(.text)
        }
        return filtered.sorted { $0.timestamp > $1.timestamp }
    }
    
    var groupedMemories: [(String, [Memory])] { filteredMemories.groupedByMonth() }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                SearchBar(text: $searchText, placeholder: "Search memories...")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(MemoryFilter.allCases, id: \.self) { filter in
                            FilterButton(filter: filter, isSelected: selectedFilter == filter, count: getFilterCount(filter)) { selectedFilter = filter }
                        }
                    }.padding(.horizontal)
                }
                .frame(height: 44)
                .clipped()
            }.padding().background(Color(.systemGroupedBackground))
            
            HStack {
                Spacer()
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }.pickerStyle(SegmentedPickerStyle()).frame(width: 120)
            }.padding([.horizontal, .top, .bottom], 8)
            
            ZStack {
                if viewMode == .grid {
                    GridMemoryView(groupedMemories: groupedMemories, onMemoryTap: { showingMemoryDetail = $0 })
                } else {
                    ListMemoryView(
                        groupedMemories: groupedMemories,
                        onMemoryTap: { showingMemoryDetail = $0 },
                        onDelete: { memory in deleteMemory(memory: memory) }
                    )
                }
                if filteredMemories.isEmpty && !isLoading { EmptyMemoriesView(filter: selectedFilter, searchText: searchText) }
                if isLoading { LoadingView() }
            }
        }
        .navigationTitle("Memories")
        .navigationBarItems(trailing: Button(action: refreshMemories) { Image(systemName: "arrow.clockwise") }.disabled(isLoading))
        .refreshable { await refreshMemoriesAsync() }
        .sheet(item: $showingMemoryDetail) { memory in
            MemoryDetailView(memory: memory, networkManager: networkManager, personManager: personManager) { deletedId in
                memories.removeAll { $0.serverId == deletedId }
            }
        }
        .onAppear { if memories.isEmpty { refreshMemories() } }
        .onReceive(NotificationCenter.default.publisher(for: Constants.Notifications.memoryUploaded)) { _ in refreshMemories() }
    }
    
    private func getFilterCount(_ filter: MemoryFilter) -> Int {
        switch filter {
        case .all: return memories.count
        case .photos: return memories.filterByType(.photo).count
        case .videos: return memories.filterByType(.video).count
        case .voices: return memories.filterByType(.voice).count
        case .texts: return memories.filterByType(.text).count
        }
    }
    
    private func refreshMemories() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            let fetchedMemories = await networkManager.getAllMemories()
            await MainActor.run { memories = fetchedMemories; isLoading = false }
        }
    }
    
    private func refreshMemoriesAsync() async {
        let fetchedMemories = await networkManager.getAllMemories()
        await MainActor.run { memories = fetchedMemories }
    }
    
    private func deleteMemory(memory: Memory) {
        Task {
            let success = await networkManager.deleteMemory(memory.serverId)
            if success {
                await MainActor.run {
                    memories.removeAll { $0.id == memory.id }
                }
            }
        }
    }
}

struct GridMemoryView: View {
    let groupedMemories: [(String, [Memory])]; let onMemoryTap: (Memory) -> Void
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(groupedMemories, id: \.0) { month, memories in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(month).font(.title2).fontWeight(.semibold)
                            Spacer()
                            Text("\(memories.count) memories").font(.caption).foregroundColor(.secondary)
                        }.padding(.horizontal)
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(memories) { memory in MemoryGridCard(memory: memory) { onMemoryTap(memory) } }
                        }.padding(.horizontal)
                    }
                }
            }.padding(.vertical)
        }
    }
}

struct ListMemoryView: View {
    let groupedMemories: [(String, [Memory])]
    let onMemoryTap: (Memory) -> Void
    let onDelete: (Memory) -> Void

    var body: some View {
        List {
            ForEach(groupedMemories, id: \.0) { month, memories in
                Section(month) {
                    ForEach(memories) { memory in
                        MemoryListRow(memory: memory) { onMemoryTap(memory) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDelete(memory)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                    }
                }
            }
        }.listStyle(PlainListStyle())
    }
}

struct MemoryGridCard: View {
    @ObservedObject var memory: Memory
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Use GeometryReader to ensure consistent sizing
                GeometryReader { geometry in
                    mediaPreview
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .frame(height: 120)  // Fixed height
                .overlay(alignment: .topTrailing) { faceTagBadge }
                .overlay(alignment: .bottomTrailing) { videoDurationBadge }

                VStack(alignment: .leading, spacing: 6) {
                    Text(memory.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(memory.timestamp.formattedShort)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        // Ensure consistent card width
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var mediaPreview: some View {
        if let previewUrlString = memory.previewImagePath, let url = URL(string: previewUrlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                        )
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                }
            }
        } else {
            Rectangle()
                .fill(gradientFor(type: memory.type))
                .overlay(
                    Image(systemName: iconFor(type: memory.type, filled: true))
                        .font(.largeTitle)
                        .foregroundColor(.white)
                )
        }
    }

    @ViewBuilder
    private var faceTagBadge: some View {
        let taggedCount = memory.faceTags.filter { $0.isTagged }.count
        if memory.type == .photo && taggedCount > 0 {
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                Text("\(taggedCount)")
            }
            .font(.caption.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.6))
            .clipShape(Capsule())
            .padding(8)
        }
    }

    @ViewBuilder
    private var videoDurationBadge: some View {
        if memory.type == .video, let duration = memory.metadata.duration {
            Text(duration.shortDuration)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .padding(8)
        }
    }
    
    private func colorFor(type: MemoryType) -> Color {
        switch type {
        case .photo: .blue
        case .video: .purple
        case .voice: .orange
        case .text: .green
        }
    }
    
    private func gradientFor(type: MemoryType) -> LinearGradient {
        LinearGradient(
            colors: [colorFor(type: type).opacity(0.7), colorFor(type: type).opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func iconFor(type: MemoryType, filled: Bool) -> String {
        switch type {
        case .photo: return filled ? "photo.fill" : "photo"
        case .video: return filled ? "play.rectangle.fill" : "video"
        case .voice: return filled ? "waveform" : "mic"
        case .text: return filled ? "doc.text.fill" : "doc.text"
        }
    }
}

struct MemoryListRow: View {
    let memory: Memory
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                thumbnailView
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(memory.description.isEmpty ? memory.content : memory.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(memory.timestamp.formattedShort)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }.buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let urlString = memory.previewImagePath, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    iconView
                case .empty:
                    Rectangle().fill(Color.gray.opacity(0.2)).overlay(ProgressView())
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            iconView
        }
    }
    
    private var iconView: some View {
        ZStack {
            Rectangle().fill(colorFor(type: memory.type).opacity(0.2))
            Image(systemName: iconFor(type: memory.type))
                .font(.title3)
                .foregroundColor(colorFor(type: memory.type))
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
    
    private func iconFor(type: MemoryType) -> String {
        switch type {
        case .photo: return "photo"
        case .video: return "video"
        case .voice: return "mic"
        case .text: return "doc.text"
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("Loading memories...").font(.body).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(.systemBackground).opacity(0.8))
    }
}

struct EmptyMemoriesView: View {
    let filter: MemoryListView.MemoryFilter
    let searchText: String
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: searchText.isEmpty ? filter.icon : "magnifyingglass").font(.system(size: 60)).foregroundColor(.gray.opacity(0.5))
            VStack(spacing: 8) {
                Text(emptyTitle).font(.title2).foregroundColor(.secondary)
                Text(emptyMessage).font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
        }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyTitle: String {
        if !searchText.isEmpty { return "No memories found" }
        switch filter {
        case .all: return "No memories yet"
        case .photos: return "No photos yet"
        case .videos: return "No videos yet"
        case .voices: return "No voice stories yet"
        case .texts: return "No notes yet"
        }
    }
    
    private var emptyMessage: String {
        if !searchText.isEmpty { return "Try adjusting your search terms or check your filters" }
        switch filter {
        case .all: return "Start collecting memories"
        default: return "Add memories of this type to see them here"
        }
    }
}

struct FilterButton: View {
    let filter: MemoryListView.MemoryFilter; let isSelected: Bool; let count: Int; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon).font(.caption)
                Text(filter.rawValue).font(.subheadline).fontWeight(.medium)
                if count > 0 {
                    Text("\(count)").font(.caption).fontWeight(.bold).foregroundColor(isSelected ? .white : .secondary).padding(.horizontal, 6).padding(.vertical, 2).background(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2)).cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .white : .blue)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
            .cornerRadius(20)
        }
    }
}
