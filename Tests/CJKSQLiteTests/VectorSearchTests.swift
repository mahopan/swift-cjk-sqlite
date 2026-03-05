import Testing
@testable import CJKSQLite

@Suite("Vector Search (sqlite-vec) Tests")
struct VectorSearchTests {

    @Test("Create vec0 virtual table")
    func createVecTable() throws {
        let db = try Database()
        try db.createVecTable(name: "embeddings", dimensions: 4)
        let tables = try db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='embeddings'")
        #expect(tables.count == 1)
    }

    @Test("Insert and search vectors returns nearest neighbors")
    func insertAndSearch() throws {
        let db = try Database()
        try db.createVecTable(name: "vecs", dimensions: 3)

        // Insert 4 vectors
        try db.insertVector(table: "vecs", rowid: 1, vector: [1.0, 0.0, 0.0])
        try db.insertVector(table: "vecs", rowid: 2, vector: [0.0, 1.0, 0.0])
        try db.insertVector(table: "vecs", rowid: 3, vector: [0.0, 0.0, 1.0])
        try db.insertVector(table: "vecs", rowid: 4, vector: [1.0, 1.0, 0.0])

        // Query closest to [1, 0, 0] — should return rowid 1 first
        let results = try db.searchVectors(table: "vecs", query: [1.0, 0.0, 0.0], limit: 2)
        #expect(results.count == 2)
        #expect(results[0].rowid == 1)
        #expect(results[0].distance == 0.0)
        // Second closest should be rowid 4 (distance = 1.0)
        #expect(results[1].rowid == 4)
        #expect(results[1].distance == 1.0)
    }

    @Test("Delete vector removes it from search results")
    func deleteVector() throws {
        let db = try Database()
        try db.createVecTable(name: "vecs", dimensions: 2)

        try db.insertVector(table: "vecs", rowid: 1, vector: [1.0, 0.0])
        try db.insertVector(table: "vecs", rowid: 2, vector: [0.0, 1.0])

        try db.deleteVector(table: "vecs", rowid: 1)

        let results = try db.searchVectors(table: "vecs", query: [1.0, 0.0], limit: 10)
        #expect(results.count == 1)
        #expect(results[0].rowid == 2)
    }

    @Test("FTS5 and vec0 coexist in same database")
    func fts5AndVecCoexist() throws {
        let db = try Database()

        // Create FTS5 table
        try db.execute("CREATE VIRTUAL TABLE notes USING fts5(content, tokenize='cjk')")
        try db.execute("INSERT INTO notes(rowid, content) VALUES (1, '東京は日本の首都です')")

        // Create vec0 table
        try db.createVecTable(name: "embeddings", dimensions: 3)
        try db.insertVector(table: "embeddings", rowid: 1, vector: [0.1, 0.2, 0.3])

        // Query FTS5
        let ftsResults = try db.query("SELECT content FROM notes WHERE notes MATCH '東京'")
        #expect(ftsResults.count == 1)

        // Query vec0
        let vecResults = try db.searchVectors(table: "embeddings", query: [0.1, 0.2, 0.3], limit: 1)
        #expect(vecResults.count == 1)
        #expect(vecResults[0].rowid == 1)
        #expect(vecResults[0].distance == 0.0)
    }
}
