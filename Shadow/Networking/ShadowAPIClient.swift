import Foundation
import UIKit

// MARK: - Configuration

enum ShadowAPI {
    // TODO: Replace with your Mac's local IP (System Settings > Wi-Fi > Details)
    static var baseURL = "http://192.168.1.100:8000"
}

// MARK: - API Models

struct APIStep: Codable, Identifiable {
    let id: String
    let order: Int
    let instruction: String
    let successCriteria: String
    let referenceImageB64: String?

    enum CodingKeys: String, CodingKey {
        case id, order, instruction
        case successCriteria = "success_criteria"
        case referenceImageB64 = "reference_image_b64"
    }
}

struct APILesson: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let createdAt: String
    let steps: [APIStep]

    enum CodingKeys: String, CodingKey {
        case id, title, description, steps
        case createdAt = "created_at"
    }
}

struct CoachResponse: Codable {
    let stepCompleted: Bool
    let confidence: Double
    let coachingMessage: String
    let errorDetail: String
    let nextStepHint: String

    enum CodingKeys: String, CodingKey {
        case stepCompleted = "step_completed"
        case confidence
        case coachingMessage = "coaching_message"
        case errorDetail = "error_detail"
        case nextStepHint = "next_step_hint"
    }
}

struct ConversationMessage: Codable {
    let role: String
    let content: String
}

struct CoachRequest: Codable {
    let frameB64: String?
    let stepIndex: Int
    let lessonId: String
    let conversationHistory: [ConversationMessage]
    let userMessage: String

    enum CodingKeys: String, CodingKey {
        case frameB64 = "frame_b64"
        case stepIndex = "step_index"
        case lessonId = "lesson_id"
        case conversationHistory = "conversation_history"
        case userMessage = "user_message"
    }
}

struct CoachConversationResponse: Codable {
    let reply: String
    let updatedHistory: [ConversationMessage]

    enum CodingKeys: String, CodingKey {
        case reply
        case updatedHistory = "updated_history"
    }
}

struct LessonCreateRequest: Codable {
    let title: String
    let description: String
    let steps: [StepCreateRequest]
}

struct StepCreateRequest: Codable {
    let instruction: String
    let successCriteria: String

    enum CodingKeys: String, CodingKey {
        case instruction
        case successCriteria = "success_criteria"
    }
}

// MARK: - API Client

final class ShadowAPIClient {
    static let shared = ShadowAPIClient()
    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    private init() {}

    // MARK: - Lessons

    func fetchLessons() async throws -> [APILesson] {
        let url = URL(string: "\(ShadowAPI.baseURL)/lessons")!
        let (data, _) = try await session.data(from: url)
        return try decoder.decode([APILesson].self, from: data)
    }

    func fetchLesson(id: String) async throws -> APILesson {
        let url = URL(string: "\(ShadowAPI.baseURL)/lessons/\(id)")!
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(APILesson.self, from: data)
    }

    func createLesson(_ request: LessonCreateRequest) async throws -> APILesson {
        let url = URL(string: "\(ShadowAPI.baseURL)/lessons")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(request)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(APILesson.self, from: data)
    }

    // MARK: - Verify Step (multipart frame upload)

    func verifyStep(lessonId: String, stepIndex: Int, frame: UIImage) async throws -> CoachResponse {
        let url = URL(string: "\(ShadowAPI.baseURL)/sessions/\(lessonId)/verify-step")!
        let boundary = UUID().uuidString

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15

        var body = Data()

        // step_index field
        body.appendMultipart(boundary: boundary, name: "step_index", value: "\(stepIndex)")

        // frame file
        if let jpegData = frame.jpegData(compressionQuality: 0.5) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"frame\"; filename=\"frame.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(jpegData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, _) = try await session.data(for: req)
        return try decoder.decode(CoachResponse.self, from: data)
    }

    // MARK: - Coach Conversation (JSON body)

    func coach(lessonId: String, request: CoachRequest) async throws -> CoachConversationResponse {
        let url = URL(string: "\(ShadowAPI.baseURL)/sessions/\(lessonId)/coach")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        req.httpBody = try JSONEncoder().encode(request)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(CoachConversationResponse.self, from: data)
    }
}

// MARK: - Data Helpers

private extension Data {
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}
