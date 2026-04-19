import Foundation
import UIKit

// MARK: - Configuration

enum ShadowAPI {
    // TODO: Replace with your Mac's local IP (System Settings > Wi-Fi > Details)
    static var baseURL = "http://10.29.88.53:8000"
}

// MARK: - API Models

struct APIStep: Codable, Identifiable {
    let id: String
    let order: Int
    let instruction: String
    let timestampStart: String
    let timestampEnd: String
    let tempoDescription: String
    let techniqueNotes: String
    let context: String
    let successCriteria: String
    let visualLandmarks: String
    let commonFailurePoints: String
    let failureTriggers: String
    let arOverlayAnchor: String
    let referenceImageB64: String?

    enum CodingKeys: String, CodingKey {
        case id, order, instruction, context
        case timestampStart = "timestamp_start"
        case timestampEnd = "timestamp_end"
        case tempoDescription = "tempo_description"
        case techniqueNotes = "technique_notes"
        case successCriteria = "success_criteria"
        case visualLandmarks = "visual_landmarks"
        case commonFailurePoints = "common_failure_points"
        case failureTriggers = "failure_triggers"
        case arOverlayAnchor = "ar_overlay_anchor"
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
    let advanceStep: Bool

    enum CodingKeys: String, CodingKey {
        case reply
        case updatedHistory = "updated_history"
        case advanceStep = "advance_step"
    }
}

struct GenerateStepsResponse: Codable {
    let suggestedSteps: [APIStep]

    enum CodingKeys: String, CodingKey {
        case suggestedSteps = "suggested_steps"
    }
}

struct LessonCreateRequest: Codable {
    let title: String
    let description: String
    let steps: [StepCreateRequest]
}

struct StepCreateRequest: Codable {
    let instruction: String
    let timestampStart: String
    let timestampEnd: String
    let tempoDescription: String
    let techniqueNotes: String
    let context: String
    let successCriteria: String
    let visualLandmarks: String
    let commonFailurePoints: String
    let failureTriggers: String
    let arOverlayAnchor: String

    enum CodingKeys: String, CodingKey {
        case instruction, context
        case timestampStart = "timestamp_start"
        case timestampEnd = "timestamp_end"
        case tempoDescription = "tempo_description"
        case techniqueNotes = "technique_notes"
        case successCriteria = "success_criteria"
        case visualLandmarks = "visual_landmarks"
        case commonFailurePoints = "common_failure_points"
        case failureTriggers = "failure_triggers"
        case arOverlayAnchor = "ar_overlay_anchor"
    }
}

// MARK: - API Client

final class ShadowAPIClient {
    static let shared = ShadowAPIClient()
    private let session: URLSession
    private let decoder = JSONDecoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes for Gemini video analysis
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    // MARK: - Lessons

    func fetchLessons() async throws -> [APILesson] {
        let url = URL(string: "\(ShadowAPI.baseURL)/lessons")!
        print("[Shadow] Fetching lessons from \(url)")
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        do {
            let (data, _) = try await session.data(for: request)
            let lessons = try decoder.decode([APILesson].self, from: data)
            print("[Shadow] Fetched \(lessons.count) lessons")
            return lessons
        } catch {
            print("[Shadow] fetchLessons failed: \(error)")
            throw error
        }
    }

    func fetchLesson(id: String) async throws -> APILesson {
        let url = URL(string: "\(ShadowAPI.baseURL)/lessons/\(id)")!
        print("[Shadow] Fetching lesson \(id)")
        do {
            let (data, _) = try await session.data(from: url)
            let lesson = try decoder.decode(APILesson.self, from: data)
            print("[Shadow] Fetched lesson: \(lesson.title)")
            return lesson
        } catch {
            print("[Shadow] fetchLesson failed: \(error)")
            throw error
        }
    }

    func createLesson(_ request: LessonCreateRequest) async throws -> APILesson {
        let url = URL(string: "\(ShadowAPI.baseURL)/lessons")!
        print("[Shadow] Creating lesson: \(request.title)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(request)
        do {
            let (data, _) = try await session.data(for: req)
            let lesson = try decoder.decode(APILesson.self, from: data)
            print("[Shadow] Created lesson: \(lesson.id)")
            return lesson
        } catch {
            print("[Shadow] createLesson failed: \(error)")
            throw error
        }
    }

    // MARK: - Generate Steps (expert flow)

    func generateSteps(videoURL: URL, taskDescription: String) async throws -> [APIStep] {
        let url = URL(string: "\(ShadowAPI.baseURL)/lessons/generate-steps")!
        print("[Shadow] Generating steps from video: \(videoURL.lastPathComponent)")
        let boundary = UUID().uuidString

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // task_description field
        body.appendMultipart(boundary: boundary, name: "task_description", value: taskDescription)

        // video file
        let videoData = try Data(contentsOf: videoURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"recording.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        do {
            let (data, _) = try await session.data(for: req)
            let response = try decoder.decode(GenerateStepsResponse.self, from: data)
            print("[Shadow] Generated \(response.suggestedSteps.count) blueprint steps")
            return response.suggestedSteps
        } catch {
            print("[Shadow] generateSteps failed: \(error)")
            throw error
        }
    }

    // Deprecated - kept for compatibility but will be removed
    func generateSteps(frames: [UIImage], taskDescription: String) async throws -> [APIStep] {
        return try await generateSteps(videoURL: URL(string: "file:///dummy")!, taskDescription: taskDescription)
    }

    // MARK: - Verify Step (multipart frame upload)

    func verifyStep(lessonId: String, stepIndex: Int, frame: UIImage) async throws -> CoachResponse {
        let url = URL(string: "\(ShadowAPI.baseURL)/sessions/\(lessonId)/verify-step")!
        print("[Shadow] Verifying step \(stepIndex) for lesson \(lessonId)")
        let boundary = UUID().uuidString

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60

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

        do {
            let (data, _) = try await session.data(for: req)
            let response = try decoder.decode(CoachResponse.self, from: data)
            print("[Shadow] Step \(stepIndex) verified — completed: \(response.stepCompleted), confidence: \(response.confidence)")
            return response
        } catch {
            print("[Shadow] verifyStep failed: \(error)")
            throw error
        }
    }

    // MARK: - Coach Conversation (JSON body)

    func coach(lessonId: String, request: CoachRequest) async throws -> CoachConversationResponse {
        let url = URL(string: "\(ShadowAPI.baseURL)/sessions/\(lessonId)/coach")!
        print("[Shadow] Sending coach request for lesson \(lessonId), step \(request.stepIndex)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        req.httpBody = try JSONEncoder().encode(request)
        do {
            let (data, _) = try await session.data(for: req)
            let response = try decoder.decode(CoachConversationResponse.self, from: data)
            print("[Shadow] Coach reply received (\(response.reply.prefix(80))...)")
            return response
        } catch {
            print("[Shadow] coach request failed: \(error)")
            throw error
        }
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
