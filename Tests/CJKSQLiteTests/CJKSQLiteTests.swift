import Testing
@testable import CJKSQLite

@Suite("CJK SQLite FTS5 Tests")
struct CJKSQLiteTests {
    
    @Test("Open in-memory database and register tokenizer")
    func openDatabase() throws {
        let db = try Database()
        try db.execute("""
            CREATE VIRTUAL TABLE test USING fts5(content, tokenize='cjk')
        """)
    }
    
    @Test("Chinese text search")
    func chineseSearch() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE notes USING fts5(title, content, tokenize='cjk')")
        try db.execute("INSERT INTO notes(title, content) VALUES ('漢字學習', '漢字有兩種讀法：訓讀和音讀')")
        try db.execute("INSERT INTO notes(title, content) VALUES ('天氣預報', '今天天氣很好，適合出門')")
        
        let results = try db.query("SELECT title FROM notes WHERE notes MATCH '漢字'")
        #expect(results.count == 1)
        #expect(results[0]["title"] == "漢字學習")
    }
    
    @Test("Japanese text search")
    func japaneseSearch() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE notes USING fts5(title, content, tokenize='cjk')")
        try db.execute("INSERT INTO notes(title, content) VALUES ('日本語の勉強', '今日は天気がいいです')")
        try db.execute("INSERT INTO notes(title, content) VALUES ('買い物リスト', 'スーパーで牛乳を買う')")
        
        let results = try db.query("SELECT title FROM notes WHERE notes MATCH '天気'")
        #expect(results.count == 1)
        #expect(results[0]["title"] == "日本語の勉強")
    }
    
    @Test("Korean text search")
    func koreanSearch() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE notes USING fts5(title, content, tokenize='cjk')")
        try db.execute("INSERT INTO notes(title, content) VALUES ('한국어 공부', '오늘 날씨가 좋습니다')")
        
        // NLTokenizer may segment Korean differently; search for a word that appears as-is
        let results = try db.query("SELECT title FROM notes WHERE notes MATCH '한국어'")
        #expect(results.count == 1)
    }
    
    @Test("English text search (fallback)")
    func englishSearch() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE notes USING fts5(title, content, tokenize='cjk')")
        try db.execute("INSERT INTO notes(title, content) VALUES ('Supernova', 'Core-collapse supernovae are important')")
        try db.execute("INSERT INTO notes(title, content) VALUES ('Black Holes', 'Stellar mass black holes form from massive stars')")
        
        let results = try db.query("SELECT title FROM notes WHERE notes MATCH 'supernova'")
        #expect(results.count >= 1)
    }
    
    @Test("Mixed language search")
    func mixedLanguageSearch() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE notes USING fts5(title, content, tokenize='cjk')")
        try db.execute("INSERT INTO notes(title, content) VALUES ('訓讀 vs 音讀', 'kunyomi是日本固有的讀法，onyomi來自中國')")
        
        // Search Chinese characters
        let r1 = try db.query("SELECT title FROM notes WHERE notes MATCH '訓讀'")
        #expect(r1.count == 1)
        
        // Search Latin text
        let r2 = try db.query("SELECT title FROM notes WHERE notes MATCH 'kunyomi'")
        #expect(r2.count == 1)
    }
    
    @Test("Empty and whitespace handling")
    func emptyInput() throws {
        let db = try Database()
        try db.execute("CREATE VIRTUAL TABLE notes USING fts5(content, tokenize='cjk')")
        try db.execute("INSERT INTO notes(content) VALUES ('')")
        try db.execute("INSERT INTO notes(content) VALUES ('   ')")
        // Should not crash
        let results = try db.query("SELECT * FROM notes")
        #expect(results.count == 2)
    }
}
