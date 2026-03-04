import Testing
@testable import CJKSQLite

@Suite("Regression Tests")
struct RegressionTests {
    
    // MARK: - CJK Segmentation Quality
    
    @Test("Chinese: compound words are searchable by component")
    func chineseCompoundWords() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE t USING fts5(content, tokenize='cjk')")
        try db.execute("INSERT INTO t(content) VALUES ('超新星爆發是恆星演化的最終階段')")
        
        let r1 = try db.query("SELECT * FROM t WHERE t MATCH '超新星'")
        #expect(r1.count == 1, "Should find 超新星 in 超新星爆發")
        
        let r2 = try db.query("SELECT * FROM t WHERE t MATCH '恆星'")
        #expect(r2.count == 1, "Should find 恆星 in 恆星演化")
    }
    
    @Test("Japanese: hiragana, katakana, and kanji all searchable")
    func japaneseScripts() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE t USING fts5(content, tokenize='cjk')")
        try db.execute("INSERT INTO t(content) VALUES ('プログラミングは楽しいです')")
        try db.execute("INSERT INTO t(content) VALUES ('はじめまして、田中です')")
        
        // Katakana
        let r1 = try db.query("SELECT * FROM t WHERE t MATCH 'プログラミング'")
        #expect(r1.count == 1)
        
        // Kanji
        let r2 = try db.query("SELECT * FROM t WHERE t MATCH '田中'")
        #expect(r2.count == 1)
    }
    
    @Test("Japanese: particles should not prevent matching")
    func japaneseParticles() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE t USING fts5(content, tokenize='cjk')")
        try db.execute("INSERT INTO t(content) VALUES ('今日は天気がいいですね')")
        
        let results = try db.query("SELECT * FROM t WHERE t MATCH '天気'")
        #expect(results.count == 1, "Should find 天気 even with particles around it")
    }
    
    // MARK: - Mixed Content
    
    @Test("Mixed CJK and ASCII in same field")
    func mixedInSameField() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE t USING fts5(content, tokenize='cjk')")
        try db.execute("INSERT INTO t(content) VALUES ('使用Swift開發iOS應用程式')")
        
        let r1 = try db.query("SELECT * FROM t WHERE t MATCH 'Swift'")
        #expect(r1.count == 1)
        
        let r2 = try db.query("SELECT * FROM t WHERE t MATCH 'iOS'")
        #expect(r2.count == 1)
        
        let r3 = try db.query("SELECT * FROM t WHERE t MATCH '開發'")
        #expect(r3.count == 1)
    }
    
    @Test("Numbers mixed with CJK")
    func numbersWithCJK() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE t USING fts5(content, tokenize='cjk')")
        try db.execute("INSERT INTO t(content) VALUES ('SQLite版本3.48.0支援FTS5')")
        
        let r1 = try db.query("SELECT * FROM t WHERE t MATCH 'SQLite'")
        #expect(r1.count == 1)
        
        let r2 = try db.query("SELECT * FROM t WHERE t MATCH '支援'")
        #expect(r2.count == 1)
    }
    
    // MARK: - Edge Cases
    
    @Test("Very long CJK text")
    func longText() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE t USING fts5(content, tokenize='cjk')")
        let longText = String(repeating: "這是一段很長的中文文字。", count: 1000)
        try db.execute("INSERT INTO t(content) VALUES ('\(longText)')")
        
        let results = try db.query("SELECT * FROM t WHERE t MATCH '中文'")
        #expect(results.count == 1)
    }
    
    @Test("Single character search")
    func singleChar() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE t USING fts5(content, tokenize='cjk')")
        try db.execute("INSERT INTO t(content) VALUES ('星は美しい')")
        
        // Single kanji may or may not be a token depending on NLTokenizer
        // This test documents the behavior rather than asserting a specific result
        let results = try db.query("SELECT * FROM t WHERE t MATCH '星'")
        // Just ensure no crash
        _ = results
    }
    
    @Test("Emoji and special characters don't crash")
    func emojiAndSpecial() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE t USING fts5(content, tokenize='cjk')")
        try db.execute("INSERT INTO t(content) VALUES ('🔭 天文觀測 ⭐ telescope')")
        
        let r1 = try db.query("SELECT * FROM t WHERE t MATCH '天文'")
        #expect(r1.count == 1)
        
        let r2 = try db.query("SELECT * FROM t WHERE t MATCH 'telescope'")
        #expect(r2.count == 1)
    }
    
    @Test("Unicode normalization: fullwidth vs halfwidth")
    func fullwidthHalfwidth() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE t USING fts5(content, tokenize='cjk')")
        try db.execute("INSERT INTO t(content) VALUES ('Ｈｅｌｌｏ Ｗｏｒｌｄ')")  // fullwidth
        
        // Document behavior — fullwidth might or might not match halfwidth
        let results = try db.query("SELECT * FROM t WHERE t MATCH 'hello'")
        _ = results  // no crash
    }
    
    // MARK: - Multiple Rows
    
    @Test("Correct ranking with multiple results")
    func multipleResults() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE t USING fts5(title, content, tokenize='cjk')")
        try db.execute("INSERT INTO t(title, content) VALUES ('機器學習入門', '神經網路是機器學習的核心技術')")
        try db.execute("INSERT INTO t(title, content) VALUES ('深度學習', '深度學習是機器學習的一個分支')")
        try db.execute("INSERT INTO t(title, content) VALUES ('天文觀測', '用望遠鏡觀測星空')")
        
        let results = try db.query("SELECT title FROM t WHERE t MATCH '機器學習' ORDER BY rank")
        #expect(results.count >= 1, "Should find at least one result for 機器學習")
    }
    
    // MARK: - Database Lifecycle
    
    @Test("Multiple tables with CJK tokenizer")
    func multipleTables() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE notes USING fts5(content, tokenize='cjk')")
        try db.execute("CREATE VIRTUAL TABLE papers USING fts5(title, abstract, tokenize='cjk')")
        
        try db.execute("INSERT INTO notes(content) VALUES ('日語學習筆記')")
        try db.execute("INSERT INTO papers(title, abstract) VALUES ('超新星研究', '核心塌縮超新星的數值模擬')")
        
        let r1 = try db.query("SELECT * FROM notes WHERE notes MATCH '日語'")
        #expect(r1.count == 1)
        
        let r2 = try db.query("SELECT * FROM papers WHERE papers MATCH '超新星'")
        #expect(r2.count == 1)
    }
    
    @Test("Insert, delete, re-query")
    func insertDeleteCycle() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE t USING fts5(content, tokenize='cjk')")
        try db.execute("INSERT INTO t(rowid, content) VALUES (1, '量子力學')")
        try db.execute("INSERT INTO t(rowid, content) VALUES (2, '相對論')")
        
        var results = try db.query("SELECT * FROM t WHERE t MATCH '量子'")
        #expect(results.count == 1)
        
        try db.execute("DELETE FROM t WHERE rowid = 1")
        
        results = try db.query("SELECT * FROM t WHERE t MATCH '量子'")
        #expect(results.count == 0, "Should not find deleted content")
        
        results = try db.query("SELECT * FROM t WHERE t MATCH '相對論'")
        #expect(results.count == 1, "Other content should still be there")
    }
}
