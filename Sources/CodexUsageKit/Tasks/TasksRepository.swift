import Foundation
import GRDB

public final class TasksRepository: @unchecked Sendable {
    private let dbQueue: DatabaseQueue

    public init(databasePath: String) throws {
        var configuration = Configuration()
        configuration.readonly = true
        configuration.label = "app.codexusage.tasks-db"
        dbQueue = try DatabaseQueue(path: databasePath, configuration: configuration)
    }

    public func fetchBreakdown(
        now: Date = Date(),
        topN: Int = 5
    ) throws -> TaskBreakdownSnapshot {
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)
        let fiveHourCutoff = nowMs - Int64(5 * 60 * 60 * 1000)
        let sevenDayCutoff = nowMs - Int64(7 * 24 * 60 * 60 * 1000)

        return try dbQueue.read { db in
            let fiveProjects = try Self.fetchBuckets(
                db: db,
                groupColumn: "cwd",
                cutoffMs: fiveHourCutoff,
                topN: topN
            )
            let fiveModels = try Self.fetchBuckets(
                db: db,
                groupColumn: "model",
                cutoffMs: fiveHourCutoff,
                topN: topN
            )
            let sevenProjects = try Self.fetchBuckets(
                db: db,
                groupColumn: "cwd",
                cutoffMs: sevenDayCutoff,
                topN: topN
            )
            let sevenModels = try Self.fetchBuckets(
                db: db,
                groupColumn: "model",
                cutoffMs: sevenDayCutoff,
                topN: topN
            )

            return TaskBreakdownSnapshot(
                fiveHours: .init(projects: fiveProjects, models: fiveModels),
                sevenDays: .init(projects: sevenProjects, models: sevenModels)
            )
        }
    }

    private static func fetchBuckets(
        db: Database,
        groupColumn: String,
        cutoffMs: Int64,
        topN: Int
    ) throws -> [UsageBucket] {
        let sql = """
        SELECT
            COALESCE(NULLIF(\(groupColumn), ''), 'Unknown') AS bucket_name,
            CAST(SUM(tokens_used) AS INTEGER) AS bucket_tokens,
            COUNT(*) AS bucket_threads
        FROM threads
        WHERE tokens_used > 0
          AND COALESCE(updated_at_ms, updated_at * 1000) >= ?
        GROUP BY bucket_name
        ORDER BY bucket_tokens DESC
        LIMIT ?
        """

        struct RowModel: FetchableRecord, Decodable {
            let bucketName: String
            let bucketTokens: Int
            let bucketThreads: Int

            enum CodingKeys: String, CodingKey {
                case bucketName = "bucket_name"
                case bucketTokens = "bucket_tokens"
                case bucketThreads = "bucket_threads"
            }
        }

        let rows = try RowModel.fetchAll(db, sql: sql, arguments: [cutoffMs, topN])
        return rows.map { row in
            UsageBucket(name: row.bucketName, tokens: row.bucketTokens, threadCount: row.bucketThreads)
        }
    }
}
