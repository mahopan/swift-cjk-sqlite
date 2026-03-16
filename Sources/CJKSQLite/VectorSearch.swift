import Foundation
import CSQLite

extension Database {
    /// Create a vec0 virtual table for vector search.
    /// - Parameters:
    ///   - name: Table name.
    ///   - dimensions: Number of dimensions for the embedding vector.
    public func createVecTable(name: String, dimensions: Int) throws {
        try execute("CREATE VIRTUAL TABLE [\(name)] USING vec0(embedding float[\(dimensions)])")
    }

    /// Insert a vector into a vec0 table.
    /// - Parameters:
    ///   - table: Table name.
    ///   - rowid: The row ID for this vector.
    ///   - vector: The embedding as an array of Float values.
    public func insertVector(table: String, rowid: Int64, vector: [Float]) throws {
        let sql = "INSERT INTO [\(table)](rowid, embedding) VALUES (?, ?)"
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(handle, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else {
            let msg = String(cString: sqlite3_errmsg(handle))
            throw DatabaseError.executeFailed(message: msg)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, rowid)

        // Bind blob and step inside withUnsafeBufferPointer to ensure the pointer
        // remains valid during sqlite3_step (SQLITE_STATIC requires pointer validity
        // until the statement is finalized or re-bound).
        try vector.withUnsafeBufferPointer { buf in
            let raw = UnsafeRawBufferPointer(buf)
            sqlite3_bind_blob(stmt, 2, raw.baseAddress, Int32(raw.count), nil)

            let stepRc = sqlite3_step(stmt)
            if stepRc != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(handle))
                throw DatabaseError.executeFailed(message: msg)
            }
        }
    }

    /// Search for nearest neighbor vectors.
    /// - Parameters:
    ///   - table: Table name.
    ///   - query: The query vector.
    ///   - limit: Maximum number of results.
    /// - Returns: Array of (rowid, distance) tuples ordered by distance.
    public func searchVectors(table: String, query: [Float], limit: Int) throws -> [(rowid: Int64, distance: Double)] {
        let sql = "SELECT rowid, distance FROM [\(table)] WHERE embedding MATCH ? ORDER BY distance LIMIT ?"
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(handle, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else {
            let msg = String(cString: sqlite3_errmsg(handle))
            throw DatabaseError.queryFailed(message: msg)
        }
        defer { sqlite3_finalize(stmt) }

        // Bind blob and step inside withUnsafeBufferPointer to ensure the query
        // pointer remains valid during all sqlite3_step calls.
        let results: [(rowid: Int64, distance: Double)] = try query.withUnsafeBufferPointer { buf in
            let raw = UnsafeRawBufferPointer(buf)
            sqlite3_bind_blob(stmt, 1, raw.baseAddress, Int32(raw.count), nil)
            sqlite3_bind_int(stmt, 2, Int32(limit))

            var rows: [(rowid: Int64, distance: Double)] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let rowid = sqlite3_column_int64(stmt, 0)
                let distance = sqlite3_column_double(stmt, 1)
                rows.append((rowid: rowid, distance: distance))
            }
            return rows
        }
        return results
    }

    /// Delete a vector from a vec0 table.
    /// - Parameters:
    ///   - table: Table name.
    ///   - rowid: The row ID to delete.
    public func deleteVector(table: String, rowid: Int64) throws {
        let sql = "DELETE FROM [\(table)] WHERE rowid = ?"
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(handle, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else {
            let msg = String(cString: sqlite3_errmsg(handle))
            throw DatabaseError.executeFailed(message: msg)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, rowid)

        let stepRc = sqlite3_step(stmt)
        if stepRc != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(handle))
            throw DatabaseError.executeFailed(message: msg)
        }
    }
}
