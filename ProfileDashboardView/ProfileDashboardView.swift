import SwiftUI

// MARK: - Models
struct DashUserProfile {
    let username: String
    let displayName: String
    let avatarSystemIcon: String
}

struct DashUploadedTutorial: Identifiable {
    let id = UUID()
    let title: String
    let stepCount: Int
    let category: String
    let categoryIcon: String
    let viewCount: Int
    let thumbnailSystemIcon: String
}

struct DashFavoritedTutorial: Identifiable {
    let id = UUID()
    let title: String
    let authorUsername: String
    let stepCount: Int
    let thumbnailSystemIcon: String
}

enum ProfileTab: String, CaseIterable {
    case uploads = "My Uploads"
    case favorites = "Favorites"
    case stats = "Stats"

    var icon: String {
        switch self {
        case .uploads: return "play.rectangle.fill"
        case .favorites: return "heart.fill"
        case .stats: return "chart.bar.fill"
        }
    }
}

// MARK: - Main Profile View
struct ProfileDashboardView: View {
    @State private var selectedTab: ProfileTab = .uploads
    @Namespace private var tabNamespace
    @Environment(\.dismiss) var dismiss

    let profile = DashUserProfile(
        username: "@jordan_dev",
        displayName: "Jordan Lee",
        avatarSystemIcon: "person.crop.circle.fill"
    )

    let uploads: [DashUploadedTutorial] = [
        .init(title: "How to tie a Windsor Knot", stepCount: 6, category: "Home", categoryIcon: "house", viewCount: 312, thumbnailSystemIcon: "tshirt"),
        .init(title: "Perfect Scrambled Eggs", stepCount: 4, category: "Cooking", categoryIcon: "fork.knife", viewCount: 874, thumbnailSystemIcon: "frying.pan"),
        .init(title: "Set Up Git SSH Keys", stepCount: 5, category: "Tech", categoryIcon: "laptopcomputer", viewCount: 1023, thumbnailSystemIcon: "key")
    ]

    let favorites: [DashFavoritedTutorial] = [
        .init(title: "Sourdough Bread from Scratch", authorUsername: "@bakerbee", stepCount: 12, thumbnailSystemIcon: "birthday.cake"),
        .init(title: "Beginner Watercolour Flowers", authorUsername: "@artflow", stepCount: 7, thumbnailSystemIcon: "paintpalette")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        headerIdentitySection
                        slidingTabBar
                        tabContentSection
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        // Action for logout
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Log Out")
                                .font(.system(size: 13, weight: .bold))
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Minimal Header Identity
    private var headerIdentitySection: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 90, height: 90)
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                    
                    Image(systemName: profile.avatarSystemIcon)
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "4F46E5"), Color(hex: "7C3AED")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color(.systemGroupedBackground), lineWidth: 2.5))
                    Image(systemName: "glasses")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, 24)

            VStack(spacing: 2) {
                Text(profile.displayName)
                    .font(.title3.bold())
                Text(profile.username)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    // MARK: - Tab Bar
    private var slidingTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(duration: 0.35)) { selectedTab = tab }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon).font(.system(size: 12, weight: .semibold))
                            Text(tab.rawValue).font(.subheadline.bold())
                        }
                        .foregroundStyle(selectedTab == tab ? .white : Color(hex: "4F46E5"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(LinearGradient(colors: [Color(hex: "4F46E5"), Color(hex: "7C3AED")], startPoint: .leading, endPoint: .trailing))
                                    .matchedGeometryEffect(id: "tab", in: tabNamespace)
                            } else {
                                Capsule().fill(Color(hex: "4F46E5").opacity(0.08))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Tab Content
    @ViewBuilder
    private var tabContentSection: some View {
        switch selectedTab {
        case .uploads:
            LazyVStack(spacing: 12) {
                ForEach(uploads) { tutorial in
                    UploadCard(tutorial: tutorial)
                }
            }
            .padding(.horizontal, 16)
        case .favorites:
            LazyVStack(spacing: 12) {
                ForEach(favorites) { tutorial in
                    FavoriteCard(tutorial: tutorial)
                }
            }
            .padding(.horizontal, 16)
        case .stats:
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    BigStatCard(value: "2,749", label: "Total Views", icon: "eye.fill", gradient: [Color(hex: "4F46E5"), Color(hex: "7C3AED")])
                    BigStatCard(value: "154", label: "Users Guided", icon: "person.2.fill", gradient: [Color(hex: "7C3AED"), Color(hex: "A855F7")])
                }
                HStack(spacing: 12) {
                    BigStatCard(value: "32", label: "Skills Mastered", icon: "graduationcap.fill", gradient: [Color(hex: "0EA5E9"), Color(hex: "4F46E5")])
                    BigStatCard(value: "4", label: "Published", icon: "play.rectangle.fill", gradient: [Color(hex: "EF4444"), Color(hex: "7C3AED")])
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Sub-components (BigStatCard, UploadCard, FavoriteCard kept same as above)
private struct BigStatCard: View {
    let value: String
    let label: String
    let icon: String
    let gradient: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(gradient[0].opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(gradient[0])
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title2.bold())
                Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
}

private struct UploadCard: View {
    let tutorial: DashUploadedTutorial
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: tutorial.thumbnailSystemIcon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(LinearGradient(colors: [Color(hex: "4F46E5"), Color(hex: "7C3AED")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tutorial.title).font(.subheadline.bold())
                Text("\(tutorial.category) · \(tutorial.stepCount) Steps").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
    }
}

private struct FavoriteCard: View {
    let tutorial: DashFavoritedTutorial
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: tutorial.thumbnailSystemIcon)
                .font(.title2)
                .foregroundStyle(Color(hex: "4F46E5"))
                .frame(width: 50, height: 50)
                .background(Color(hex: "4F46E5").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tutorial.title).font(.subheadline.bold())
                Text("by \(tutorial.authorUsername)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "heart.fill").foregroundStyle(.red).font(.subheadline)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
    }
}

#Preview {
    ProfileDashboardView()
}

