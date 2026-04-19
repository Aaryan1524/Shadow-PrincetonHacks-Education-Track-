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

// MARK: - Knot Transaction Models
struct KnotTransaction: Codable, Identifiable {
    let id: String
    let datetime: String
    let orderStatus: String
    let price: KnotPrice
    let products: [KnotProduct]

    enum CodingKeys: String, CodingKey {
        case id, datetime, products, price
        case orderStatus = "order_status"
    }

    var displayName: String {
        guard !products.isEmpty else { return "DoorDash Order" }
        return products.prefix(2).map { $0.name }.joined(separator: ", ")
    }

    var restaurantName: String {
        products.first?.seller?.name ?? "DoorDash"
    }

    var displayDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: datetime) {
            let display = DateFormatter()
            display.dateStyle = .medium
            return display.string(from: date)
        }
        return datetime
    }

    var amount: Double {
        Double(price.total) ?? 0
    }
}

struct KnotPrice: Codable {
    let total: String
    let currency: String?
}

struct KnotProduct: Codable {
    let name: String
    let quantity: Int
    let seller: KnotSeller?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, quantity, seller
        case imageUrl = "image_url"
    }
}

struct KnotSeller: Codable {
    let name: String
}

struct KnotTransactionsResponse: Codable {
    let transactions: [KnotTransaction]
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

let mockKnotTransactions: [KnotTransaction] = [
    KnotTransaction(id: "m1", datetime: "2026-04-17T12:00:00+00:00", orderStatus: "COMPLETED",
        price: KnotPrice(total: "34.99", currency: "USD"),
        products: [KnotProduct(name: "Burrito Bowl", quantity: 1, seller: KnotSeller(name: "Chipotle"), imageUrl: nil)]),
    KnotTransaction(id: "m2", datetime: "2026-04-15T18:30:00+00:00", orderStatus: "COMPLETED",
        price: KnotPrice(total: "22.50", currency: "USD"),
        products: [KnotProduct(name: "Chicken Sandwich", quantity: 1, seller: KnotSeller(name: "Chick-fil-A"), imageUrl: nil)]),
    KnotTransaction(id: "m3", datetime: "2026-04-12T20:00:00+00:00", orderStatus: "COMPLETED",
        price: KnotPrice(total: "41.10", currency: "USD"),
        products: [KnotProduct(name: "ShackBurger", quantity: 2, seller: KnotSeller(name: "Shake Shack"), imageUrl: nil)]),
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
    @State private var showWalmartLogin = false
    @State private var knotSessionId: String? = nil
    @State private var isLoadingSession = false
    @State private var transactions: [KnotTransaction] = []

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
                    // Connect Walmart button
                    Button(action: {
                        guard !isLoadingSession else { return }
                        isLoadingSession = true
                        Task { @MainActor in
                            if let sessionId = try? await fetchKnotSession(userId: "user_001") {
                                knotSessionId = sessionId
                                showWalmartLogin = true
                            }
                            isLoadingSession = false
                        }
                    }) {
                        HStack {
                            if isLoadingSession {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "bag.fill")
                                Text("Connect DoorDash Account")
                                    .font(.custom("CopernicusTrial-Book", size: 14))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.0, green: 0.42, blue: 0.24))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .sheet(isPresented: $showWalmartLogin) {
                        if let sessionId = knotSessionId {
                            KnotView(
                                sessionId: sessionId,
                                clientId: "a390e79d-2920-4440-9ba1-b747bc92790b",
                                onSuccess: { _ in
                                    // Show mock data immediately so user sees history right away
                                    transactions = mockKnotTransactions
                                    Task { @MainActor in
                                        let fetched = await fetchTransactions(userId: "user_001")
                                        if !fetched.isEmpty { transactions = fetched }
                                    }
                                },
                                onExitHandler: {
                                    showWalmartLogin = false
                                }
                            )
                        }
                    }

                    // Transactions section
                    if transactions.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "bag")
                                .font(.system(size: 28))
                                .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29).opacity(0.35))
                            Text("Purchase history will appear here")
                                .font(.custom("CopernicusTrial-Book", size: 13))
                                .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29).opacity(0.45))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent DoorDash Orders")
                                .font(.custom("CopernicusTrial-Book", size: 15))
                                .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29))
                                .padding(.horizontal)

                            ForEach(transactions) { txn in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(txn.restaurantName)
                                            .font(.custom("CopernicusTrial-Book", size: 13))
                                            .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29))
                                            .lineLimit(1)
                                        Text(txn.displayName)
                                            .font(.custom("CopernicusTrial-Book", size: 11))
                                            .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29).opacity(0.6))
                                            .lineLimit(1)
                                        Text(txn.displayDate)
                                            .font(.custom("CopernicusTrial-Book", size: 10))
                                            .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29).opacity(0.45))
                                    }
                                    Spacer()
                                    Text(String(format: "$%.2f", txn.amount))
                                        .font(.custom("CopernicusTrial-Book", size: 13))
                                        .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal)
                            }
                        }
                    }

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

// MARK: - Knot session fetch
private func fetchKnotSession(userId: String) async throws -> String {
    let url = URL(string: "http://localhost:8000/knot/session")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(["external_user_id": userId])

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw URLError(.badServerResponse)
    }
    let json = try JSONDecoder().decode([String: String].self, from: data)
    guard let sessionId = json["session_id"] else {
        throw URLError(.cannotParseResponse)
    }
    return sessionId
}

// MARK: - Knot transactions fetch
private func fetchTransactions(userId: String) async -> [KnotTransaction] {
    guard let url = URL(string: "http://localhost:8000/knot/transactions/\(userId)") else { return [] }
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            print("[Knot] Transactions request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            return []
        }
        if let raw = String(data: data, encoding: .utf8) {
            print("[Knot] Raw transactions JSON:\n\(raw)")
        }
        let decoded = try JSONDecoder().decode(KnotTransactionsResponse.self, from: data)
        print("[Knot] Decoded \(decoded.transactions.count) transactions")
        return decoded.transactions
    } catch {
        print("[Knot] Failed to fetch/decode transactions: \(error)")
        return []
    }
}

// MARK: - Walmart Login Sheet
struct WalmartLoginSheet: View {
    var onConnected: () -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 8)

            Image(systemName: "cart.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(red: 0.0, green: 0.42, blue: 0.24))

            Text("Connect Walmart Account")
                .font(.custom("CopernicusTrial-Book", size: 20))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))

            Text("Sign in to import your recent purchases")
                .font(.custom("CopernicusTrial-Book", size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                TextField("Walmart email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)

            Button(action: {
                guard !email.isEmpty, !password.isEmpty else { return }
                isConnecting = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onConnected()
                }
            }) {
                Group {
                    if isConnecting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Connect Account")
                            .font(.custom("CopernicusTrial-Book", size: 15))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.0, green: 0.42, blue: 0.24))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .disabled(email.isEmpty || password.isEmpty || isConnecting)

            Spacer()
        }
        .padding(.top)
    }
}

// MARK: - Tutorial Card
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
