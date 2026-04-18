import SwiftUI

// MARK: - Models
struct TutorialCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
}

struct Tutorial: Identifiable {
    let id = UUID()
    let title: String
    let expertName: String
    let thumbnailColor: Color
    let category: String
    let duration: String
}

// MARK: - Mock Data
let mockCategories: [TutorialCategory] = [
    .init(name: "All", icon: "square.grid.2x2"),
    .init(name: "Home", icon: "house"),
    .init(name: "Cooking", icon: "fork.knife"),
    .init(name: "Fitness", icon: "figure.run"),
    .init(name: "Tech", icon: "laptopcomputer"),
    .init(name: "Crafts", icon: "scissors"),
]

let mockTutorials: [Tutorial] = [
    .init(title: "How to Tie a Shoe", expertName: "Jordan M.", thumbnailColor: .blue, category: "Home", duration: "3 min"),
    .init(title: "Perfect Scrambled Eggs", expertName: "Sara K.", thumbnailColor: .orange, category: "Cooking", duration: "5 min"),
    .init(title: "Fix a Leaky Faucet", expertName: "Mike T.", thumbnailColor: .teal, category: "Home", duration: "8 min"),
    .init(title: "Morning Stretch Routine", expertName: "Lia R.", thumbnailColor: .green, category: "Fitness", duration: "10 min"),
    .init(title: "Set Up Your Router", expertName: "Dev P.", thumbnailColor: .purple, category: "Tech", duration: "6 min"),
    .init(title: "Knit a Basic Stitch", expertName: "Anna W.", thumbnailColor: .pink, category: "Crafts", duration: "12 min"),
]

struct UserView: View {
    @State private var searchText = ""
    @State private var selectedCategory = "All"

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var filteredTutorials: [Tutorial] {
        mockTutorials.filter { tutorial in
            let matchesCategory = selectedCategory == "All" || tutorial.category == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                tutorial.title.localizedCaseInsensitiveContains(searchText) ||
                tutorial.expertName.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(mockCategories) { category in
                                Button(action: { selectedCategory = category.name }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 12))
                                        Text(category.name)
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category.name ? Color.blue : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedCategory == category.name ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if filteredTutorials.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No tutorials found")
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredTutorials) { tutorial in
                                TutorialCard(tutorial: tutorial)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Learn")
            .searchable(text: $searchText, prompt: "Search...")
        }
    }
}

struct TutorialCard: View {
    let tutorial: Tutorial
    @State private var showAgentSheet = false

    var body: some View {
        Button { showAgentSheet = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tutorial.thumbnailColor.gradient)
                        .frame(height: 110)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(tutorial.title)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Text(tutorial.expertName)
                        Spacer()
                        Text(tutorial.duration)
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
                .padding(10)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showAgentSheet) {
            AgentLaunchView(tutorial: tutorial)
        }
    }
}

struct AgentLaunchView: View {
    let tutorial: Tutorial
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text(tutorial.title)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)

            Text("Your AI guide is ready.\nPut on your Meta glasses.")
                .font(.system(size: 14, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button { } label: {
                Text("Start Session")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Button("Cancel") { dismiss() }
                .font(.system(size: 14, design: .monospaced))

            Spacer()
        }
        .padding()
    }
}

#Preview {
    UserView()
}
