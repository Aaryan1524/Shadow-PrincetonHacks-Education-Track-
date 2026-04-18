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
    @State private var fillScreen = false
    @State private var showContent = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Sky background matching rest of app
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.53, green: 0.81, blue: 0.98), location: 0.0),
                        .init(color: Color(red: 0.78, green: 0.91, blue: 1.00), location: 0.38),
                        .init(color: Color(red: 0.95, green: 0.88, blue: 0.74), location: 0.48)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Color.clear.frame(height: h * 0.50)
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.35, green: 0.62, blue: 0.22), location: 0.0),
                            .init(color: Color(red: 0.20, green: 0.42, blue: 0.12), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxHeight: .infinity)
                }
                .ignoresSafeArea(edges: .bottom)

                // Welcome prompt
                if !fillScreen {
                    VStack(spacing: 32) {
                        Text("Welcome, Student")
                            .font(.custom("CopernicusTrial-Book", size: 30))
                            .foregroundStyle(Color(red: 0.08, green: 0.20, blue: 0.06))
                            .tracking(2)

                        Button {
                            withAnimation(.spring(duration: 0.65, bounce: 0.08)) {
                                fillScreen = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                                withAnimation(.easeIn(duration: 0.28)) {
                                    showContent = true
                                }
                            }
                        } label: {
                            Text("View Courses")
                                .font(.custom("CopernicusTrial-Book", size: 18))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(Color(red: 0.18, green: 0.44, blue: 0.10))
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .position(x: w / 2, y: h * 0.44)
                    .transition(.opacity)
                }

                // Green fill — expands from button area
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.24, green: 0.55, blue: 0.14), location: 0.0),
                        .init(color: Color(red: 0.12, green: 0.34, blue: 0.07), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .scaleEffect(fillScreen ? 1 : 0.001, anchor: UnitPoint(x: 0.5, y: 0.60))
                .zIndex(1)

                // Courses list fades in after fill
                if showContent {
                    CoursesListView()
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: fillScreen)
        }
    }
}

struct CoursesListView: View {
    let courses = [
        ("Intro to Physics",         "person.chalkboard"),
        ("Advanced Mathematics",     "function"),
        ("World History",            "book.closed"),
        ("Chemistry Fundamentals",   "flask"),
        ("Computer Science 101",     "laptopcomputer"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your Courses")
                    .font(.custom("CopernicusTrial-Book", size: 34))
                    .foregroundStyle(.white)
                    .tracking(2)
                    .padding(.top, 80)
                    .padding(.bottom, 8)

                ForEach(courses, id: \.0) { course, icon in
                    HStack(spacing: 16) {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.70))
                            .frame(width: 28)

                        Text(course)
                            .font(.custom("CopernicusTrial-Book", size: 17))
                            .foregroundStyle(.white.opacity(0.92))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.40))
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    UserView()
}

