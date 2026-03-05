import Foundation
import CSQLite

/// A lightweight SQLite wrapper with CJK FTS5 tokenizer support.
public final class Database: @unchecked Sendable {
    private let db: OpaquePointer
    
    private static let vecInitOnce: Void = {
        sqlite_vec_auto_init()
    }()

    /// Open a SQLite database and register the CJK tokenizer.
    /// - Parameter path: Path to the database file. Use ":memory:" for in-memory database.
    public init(path: String = ":memory:") throws {
        _ = Self.vecInitOnce
        var handle: OpaquePointer?
        let rc = sqlite3_open(path, &handle)
        guard rc == SQLITE_OK, let handle else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            if let handle { sqlite3_close(handle) }
            throw DatabaseError.openFailed(message: msg)
        }
        self.db = handle
        try CJKTokenizer.register(db: db)
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    /// Execute a SQL statement (no results).
    public func execute(_ sql: String) throws {
        var errmsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errmsg)
        if rc != SQLITE_OK {
            let msg = errmsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errmsg)
            throw DatabaseError.executeFailed(message: msg)
        }
    }
    
    /// Execute a SQL query and return results as array of dictionaries.
    public func query(_ sql: String) throws -> [[String: String]] {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed(message: msg)
        }
        defer { sqlite3_finalize(stmt) }
        
        var results: [[String: String]] = []
        let colCount = sqlite3_column_count(stmt)
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: String] = [:]
            for i in 0..<colCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                if let text = sqlite3_column_text(stmt, i) {
                    row[name] = String(cString: text)
                }
            }
            results.append(row)
        }
        return results
    }
    
    /// Access the raw SQLite handle for advanced usage.
    public var handle: OpaquePointer { db }
}

public enum DatabaseError: Error, LocalizedError {
    case openFailed(message: String)
    case executeFailed(message: String)
    case queryFailed(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .openFailed(let msg): return "Failed to open database: \(msg)"
        case .executeFailed(let msg): return "SQL execution failed: \(msg)"
        case .queryFailed(let msg): return "SQL query failed: \(msg)"
        }
    }
}
