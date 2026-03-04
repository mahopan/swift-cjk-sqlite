# swift-cjk-sqlite

A Swift Package providing SQLite FTS5 full-text search with proper CJK (Chinese, Japanese, Korean) tokenization, powered by Apple's `NLTokenizer`.

## Problem

SQLite's built-in FTS5 tokenizers (`unicode61`, `ascii`, `porter`) split text on whitespace and punctuation. This works for English but fails for CJK languages, which don't use spaces between words:

```
"今日は天気がいい" → unicode61 sees ONE token → searching "天気" finds nothing
                   → CJKTokenizer segments → "今日/は/天気/が/いい" → searching "天気" works ✅
```

## Solution

`swift-cjk-sqlite` registers a custom FTS5 tokenizer that uses Apple's `NLTokenizer` for intelligent word segmentation. It handles Chinese, Japanese, and Korean text natively, while falling back to unicode61-style tokenization for Latin scripts.

## Requirements

- Swift 6.0+
- macOS 14+ / iOS 17+ / iPadOS 17+
- Apple platforms only (uses `NaturalLanguage.framework`)

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/mahopan/swift-cjk-sqlite.git", from: "0.1.0")
]
```

## Quick Start

```swift
import CJKSQLite

// Open database and register CJK tokenizer
let db = try Database(path: "notes.db")

// Create FTS5 table with CJK tokenizer
try db.execute("""
    CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts 
    USING fts5(title, content, tags, tokenize='cjk')
""")

// Insert content (any language)
try db.execute("""
    INSERT INTO notes_fts(title, content, tags) 
    VALUES ('訓讀 vs 音讀', '漢字有兩種讀法：訓讀和音讀...', 'N5,漢字')
""")

// Search works across CJK and Latin text
let results = try db.query("SELECT * FROM notes_fts WHERE notes_fts MATCH '漢字'")
```

## How It Works

1. **Bundles SQLite** from source (amalgamation) with `SQLITE_ENABLE_FTS5` enabled
2. **Registers a custom FTS5 tokenizer** (`cjk`) at database open time
3. **Tokenizer logic**:
   - Detects script type per character run (CJK vs Latin vs other)
   - CJK runs → `NLTokenizer` with `.word` unit (intelligent segmentation)
   - Latin runs → unicode61-style tokenization (split on whitespace/punctuation)
   - Mixed-language text handled seamlessly

## Supported Languages

| Language | Tokenization | Quality |
|----------|-------------|---------|
| 中文 (Chinese) | NLTokenizer word segmentation | ✅ Excellent |
| 日本語 (Japanese) | NLTokenizer word segmentation | ✅ Excellent |
| 한국어 (Korean) | NLTokenizer word segmentation | ✅ Excellent |
| English | unicode61-style | ✅ Standard |
| Other Latin | unicode61-style | ✅ Standard |

## License

MIT — see [LICENSE](LICENSE).

---

*Built by [mahopan](https://github.com/mahopan) for [Maho Notes](https://github.com/kuochuanpan/maho-notes) 🔭*
