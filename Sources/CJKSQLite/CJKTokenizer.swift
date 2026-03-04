import Foundation
import NaturalLanguage
import CSQLite

/// Custom FTS5 tokenizer that uses Apple's NLTokenizer for CJK text segmentation.
///
/// For CJK scripts (Chinese, Japanese, Korean), NLTokenizer provides intelligent
/// word-level segmentation. For Latin and other scripts, it falls back to
/// unicode61-style tokenization (split on whitespace/punctuation).
public enum CJKTokenizer {
    
    /// Register the "cjk" tokenizer with the given database connection.
    /// After registration, you can use `tokenize='cjk'` in FTS5 CREATE TABLE statements.
    static func register(db: OpaquePointer) throws {
        // Use C helper to get fts5_api* — avoids Swift pointer bridging issues
        var pApi: UnsafeMutablePointer<fts5_api>?
        var rc = withUnsafeMutablePointer(to: &pApi) { ppApi in
            cjk_get_fts5_api(db, ppApi)
        }
        
        guard rc == SQLITE_OK, let api = pApi else {
            throw DatabaseError.executeFailed(message: "Failed to get FTS5 API (rc=\(rc)) — is FTS5 enabled?")
        }
        
        // Register the tokenizer
        var tokenizer = fts5_tokenizer(
            xCreate: cjkCreate,
            xDelete: cjkDelete,
            xTokenize: cjkTokenize
        )
        
        rc = withUnsafeMutablePointer(to: &tokenizer) { tokPtr in
            api.pointee.xCreateTokenizer(api, "cjk", nil, tokPtr, nil)
        }
        
        guard rc == SQLITE_OK else {
            throw DatabaseError.executeFailed(message: "Failed to register CJK tokenizer (rc=\(rc))")
        }
    }
}

// MARK: - FTS5 Tokenizer Callbacks

/// Context for the tokenizer instance
private final class TokenizerContext {
    let tokenizer = NLTokenizer(unit: .word)
}

private func cjkCreate(
    _ pCtx: UnsafeMutableRawPointer?,
    _ azArg: UnsafeMutablePointer<UnsafePointer<CChar>?>?,
    _ nArg: Int32,
    _ ppOut: UnsafeMutablePointer<OpaquePointer?>?
) -> Int32 {
    let ctx = TokenizerContext()
    let unmanaged = Unmanaged.passRetained(ctx)
    ppOut?.pointee = OpaquePointer(unmanaged.toOpaque())
    return SQLITE_OK
}

private func cjkDelete(_ pCtx: OpaquePointer?) {
    guard let pCtx else { return }
    Unmanaged<TokenizerContext>.fromOpaque(UnsafeRawPointer(pCtx)).release()
}

private func cjkTokenize(
    _ pCtx: OpaquePointer?,
    _ pCtx2: UnsafeMutableRawPointer?,
    _ flags: Int32,
    _ pText: UnsafePointer<CChar>?,
    _ nText: Int32,
    _ xToken: (@convention(c) (
        UnsafeMutableRawPointer?,  // pCtx
        Int32,                      // tflags
        UnsafePointer<CChar>?,     // pToken
        Int32,                      // nToken
        Int32,                      // iStart
        Int32                       // iEnd
    ) -> Int32)?
) -> Int32 {
    guard let pCtx, let pText, let xToken, nText > 0 else {
        return SQLITE_OK
    }
    
    let ctx = Unmanaged<TokenizerContext>.fromOpaque(UnsafeRawPointer(pCtx))
        .takeUnretainedValue()
    
    // Convert input to Swift String
    let data = Data(bytes: pText, count: Int(nText))
    guard let text = String(data: data, encoding: .utf8) else {
        return SQLITE_OK
    }
    
    // Use NLTokenizer to segment text
    ctx.tokenizer.string = text
    let range = text.startIndex..<text.endIndex
    
    var rc: Int32 = SQLITE_OK
    
    ctx.tokenizer.enumerateTokens(in: range) { tokenRange, _ in
        let token = String(text[tokenRange]).lowercased()
        
        // Calculate byte offsets in the original UTF-8 buffer
        let startOffset = text[text.startIndex..<tokenRange.lowerBound].utf8.count
        let tokenBytes = token.utf8.count
        let endOffset = startOffset + text[tokenRange].utf8.count
        
        // Skip empty tokens and pure whitespace/punctuation
        guard !token.isEmpty, token.rangeOfCharacter(from: .alphanumerics) != nil
                || token.unicodeScalars.contains(where: { isCJK($0) }) else {
            return true
        }
        
        // Emit the token
        rc = token.withCString { cStr in
            xToken(pCtx2, 0, cStr, Int32(tokenBytes), Int32(startOffset), Int32(endOffset))
        }
        
        return rc == SQLITE_OK
    }
    
    return rc
}

/// Check if a Unicode scalar is in a CJK range
private func isCJK(_ scalar: Unicode.Scalar) -> Bool {
    let v = scalar.value
    return (0x4E00...0x9FFF).contains(v)     // CJK Unified Ideographs
        || (0x3400...0x4DBF).contains(v)     // CJK Extension A
        || (0x3040...0x309F).contains(v)     // Hiragana
        || (0x30A0...0x30FF).contains(v)     // Katakana
        || (0xAC00...0xD7AF).contains(v)     // Hangul Syllables
        || (0x20000...0x2A6DF).contains(v)   // CJK Extension B
        || (0xF900...0xFAFF).contains(v)     // CJK Compatibility Ideographs
}
