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
        ZStack {
            // Ink wash background
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1.00, green: 1.00, blue: 0.89), location: 0.0),
                    .init(color: Color(red: 0.80, green: 0.80, blue: 0.80), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    // Inline search
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29).opacity(0.5))
                        TextField("Search courses...", text: $searchText)
                            .font(.custom("CopernicusTrial-Book", size: 14))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Category pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(mockCategories) { category in
                                Button(action: { selectedCategory = category.name }) {
                                    Text(category.name)
                                        .font(.custom("CopernicusTrial-Book", size: 13))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(
                                            selectedCategory == category.name
                                                ? Color(red: 0.43, green: 0.51, blue: 0.59)
                                                : Color.white.opacity(0.40)
                                        )
                                        .foregroundStyle(selectedCategory == category.name ? .white : Color(red: 0.29, green: 0.29, blue: 0.29))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    if filteredTutorials.isEmpty {
                        Text("No courses found")
                            .font(.custom("CopernicusTrial-Book", size: 15))
                            .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29).opacity(0.6))
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredTutorials) { tutorial in
                                TutorialCard(tutorial: tutorial)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 80)
                .padding(.bottom, 40)
            }
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
                        .fill(tutorial.thumbnailColor.opacity(0.75).gradient)
                        .frame(height: 110)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(tutorial.title)
                        .font(.custom("CopernicusTrial-Book", size: 12))
                        .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Text(tutorial.expertName)
                        Spacer()
                        Text(tutorial.duration)
                    }
                    .font(.custom("CopernicusTrial-Book", size: 10))
                    .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29).opacity(0.55))
                }
                .padding(10)
            }
            .background(Color.white.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
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
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1.00, green: 1.00, blue: 0.89), location: 0.0),
                    .init(color: Color(red: 0.80, green: 0.80, blue: 0.80), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundStyle(Color(red: 0.43, green: 0.51, blue: 0.59).opacity(0.90))

                Text(tutorial.title)
                    .font(.custom("CopernicusTrial-Book", size: 22))
                    .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29))
                    .multilineTextAlignment(.center)
                    .tracking(1)

                Text("Your AI guide is ready.\nPut on your Meta glasses.")
                    .font(.custom("CopernicusTrial-Book", size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29).opacity(0.65))

                Button { } label: {
                    Text("Start Session")
                        .font(.custom("CopernicusTrial-Book", size: 16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.43, green: 0.51, blue: 0.59))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 32)

                Button("Cancel") { dismiss() }
                    .font(.custom("CopernicusTrial-Book", size: 14))
                    .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29).opacity(0.55))

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    UserView()
}
