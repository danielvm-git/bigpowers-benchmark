import Foundation

public struct BenchRow: Codable, Identifiable, Sendable {
    public let id: UUID
    public let schemaVersion: Int
    public let timestamp: Date
    public let bigpowersRef: String
    public let modelId: String
    public let taskId: String
    public let codePass: Int
    public let artifactScore: Int
    public let conventionScore: Int
    public let duration: Double
    public let cost: Double
    public let workspace: String

    public var overallScore: Double {
        Double(codePass * 2 + artifactScore + conventionScore) / 4.0
    }

    public init(
        id: UUID,
        schemaVersion: Int,
        timestamp: Date,
        bigpowersRef: String,
        modelId: String,
        taskId: String,
        codePass: Int,
        artifactScore: Int,
        conventionScore: Int,
        duration: Double,
        cost: Double,
        workspace: String
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.timestamp = timestamp
        self.bigpowersRef = bigpowersRef
        self.modelId = modelId
        self.taskId = taskId
        self.codePass = codePass
        self.artifactScore = artifactScore
        self.conventionScore = conventionScore
        self.duration = duration
        self.cost = cost
        self.workspace = workspace
    }

    enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion = "schema_version"
        case timestamp
        case bigpowersRef = "bigpowers_ref"
        case modelId = "model_id"
        case taskId = "task_id"
        case codePass = "code_pass"
        case artifactScore = "artifact_score"
        case conventionScore = "convention_score"
        case overallScore = "overall_score"
        case duration
        case cost
        case workspace
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(bigpowersRef, forKey: .bigpowersRef)
        try container.encode(modelId, forKey: .modelId)
        try container.encode(taskId, forKey: .taskId)
        try container.encode(codePass, forKey: .codePass)
        try container.encode(artifactScore, forKey: .artifactScore)
        try container.encode(conventionScore, forKey: .conventionScore)
        try container.encode(overallScore, forKey: .overallScore)
        try container.encode(duration, forKey: .duration)
        try container.encode(cost, forKey: .cost)
        try container.encode(workspace, forKey: .workspace)
    }

    public init(from decoder: any Decoder) throws {
        let con = try decoder.container(keyedBy: CodingKeys.self)
        id = try con.decode(UUID.self, forKey: .id)
        schemaVersion = try con.decode(Int.self, forKey: .schemaVersion)
        timestamp = try con.decode(Date.self, forKey: .timestamp)
        bigpowersRef = try con.decode(String.self, forKey: .bigpowersRef)
        modelId = try con.decode(String.self, forKey: .modelId)
        taskId = try con.decode(String.self, forKey: .taskId)
        codePass = try con.decode(Int.self, forKey: .codePass)
        artifactScore = try con.decode(Int.self, forKey: .artifactScore)
        conventionScore = try con.decode(Int.self, forKey: .conventionScore)
        duration = try con.decode(Double.self, forKey: .duration)
        cost = try con.decode(Double.self, forKey: .cost)
        workspace = try con.decode(String.self, forKey: .workspace)
        // overallScore is computed — skip decoding the stored value
    }
}
