import Foundation

/// Native port of the Hugging Face `tokenizer.json` pipeline used by multilingual-e5-small:
/// Precompiled (SentencePiece nmt_nfkc charsmap) → collapse spaces → Metaspace → Unigram Viterbi
/// → `<s> … </s>`. Token IDs must match the Python reference exactly before vectors are trusted.
final class XLMRobertaTokenizer {
    enum TokenizerError: Error { case invalidFile(String) }

    struct Encoding: Equatable {
        let inputIDs: [Int32]
        let attentionMask: [Int32]
    }

    let bosID: Int32 = 0
    let padID: Int32 = 1
    let eosID: Int32 = 2
    private let unkID: Int32
    private let unkScore: Float
    private let vocab: [String: (id: Int32, score: Float)]
    private let maxPieceLength: Int
    private let charsmap: PrecompiledCharsmap

    init(tokenizerJSON url: URL) throws {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        guard let root = object as? [String: Any],
              let model = root["model"] as? [String: Any], model["type"] as? String == "Unigram",
              let entries = model["vocab"] as? [[Any]], let unk = model["unk_id"] as? Int,
              let normalizer = root["normalizer"] as? [String: Any],
              let steps = normalizer["normalizers"] as? [[String: Any]],
              let encoded = steps.first(where: { $0["type"] as? String == "Precompiled" })?["precompiled_charsmap"] as? String,
              let blob = Data(base64Encoded: encoded) else { throw TokenizerError.invalidFile("unexpected tokenizer.json layout") }
        var vocab = [String: (id: Int32, score: Float)](minimumCapacity: entries.count)
        var minScore = Float.greatestFiniteMagnitude
        var longest = 1
        for (index, entry) in entries.enumerated() {
            guard let piece = entry.first as? String, let score = (entry.last as? NSNumber)?.floatValue else { continue }
            // First occurrence wins, matching the Rust vocab map construction.
            if vocab[piece] == nil { vocab[piece] = (Int32(index), score) }
            minScore = min(minScore, score)
            longest = max(longest, piece.unicodeScalars.count)
        }
        self.vocab = vocab
        unkID = Int32(unk)
        unkScore = minScore - 10 // tokenizers' K_UNK_PENALTY
        maxPieceLength = longest
        charsmap = try PrecompiledCharsmap(blob)
    }

    /// Content tokens without specials, for chunking long inputs.
    func tokenize(_ text: String) -> [Int32] {
        var normalized = charsmap.normalize(text)
        normalized = normalized.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        // Metaspace(add_prefix_space, split): every word becomes its own "▁word" piece.
        var spaced = normalized.replacingOccurrences(of: " ", with: "\u{2581}")
        if !spaced.hasPrefix("\u{2581}") { spaced = "\u{2581}" + spaced }
        var output = [Int32]()
        var current = String.UnicodeScalarView()
        for scalar in spaced.unicodeScalars {
            if scalar == "\u{2581}", !current.isEmpty {
                output += viterbi(Array(current))
                current = String.UnicodeScalarView()
            }
            current.append(scalar)
        }
        if !current.isEmpty { output += viterbi(Array(current)) }
        return output
    }

    /// Fixed-length model input: `<s>` + up to `maxLength - 2` tokens + `</s>`, then padding.
    func encode(_ text: String, maxLength: Int) -> Encoding {
        window(tokenize(text), maxLength: maxLength)
    }

    func window(_ tokens: [Int32], maxLength: Int) -> Encoding {
        let body = Array(tokens.prefix(max(0, maxLength - 2)))
        let ids = [bosID] + body + [eosID]
        let padding = max(0, maxLength - ids.count)
        return Encoding(inputIDs: ids + Array(repeating: padID, count: padding),
                        attentionMask: Array(repeating: 1, count: ids.count) + Array(repeating: 0, count: padding))
    }

    private func viterbi(_ scalars: [Unicode.Scalar]) -> [Int32] {
        let count = scalars.count
        guard count > 0 else { return [] }
        // best[i] = (score, start, id) of the best path ending at position i.
        var best = [(score: Float, start: Int, id: Int32)?](repeating: nil, count: count + 1)
        best[0] = (0, 0, -1)
        for start in 0..<count {
            guard let base = best[start]?.score else { continue }
            var hasSingle = false
            var piece = String.UnicodeScalarView()
            for end in (start + 1)...min(count, start + maxPieceLength) {
                piece.append(scalars[end - 1])
                guard let entry = vocab[String(piece)] else { continue }
                if end == start + 1 { hasSingle = true }
                let score = base + entry.score
                if best[end] == nil || score > best[end]!.score { best[end] = (score, start, entry.id) }
            }
            if !hasSingle {
                let score = base + unkScore
                if best[start + 1] == nil || score > best[start + 1]!.score { best[start + 1] = (score, start, unkID) }
            }
        }
        var ids = [Int32]()
        var position = count
        while position > 0, let node = best[position] {
            ids.append(node.id)
            position = node.start
        }
        ids.reverse()
        // fuse_unk: consecutive unknown pieces collapse into one <unk>.
        return ids.enumerated().compactMap { index, id in
            id == unkID && index > 0 && ids[index - 1] == unkID ? nil : id
        }
    }
}

/// SentencePiece precompiled charsmap: a Darts double-array trie over UTF-8 plus a
/// NUL-separated replacement blob (layout as read by the `spm_precompiled` crate).
struct PrecompiledCharsmap {
    private let trie: [UInt32]
    private let normalized: [UInt8]

    init(_ data: Data) throws {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { throw XLMRobertaTokenizer.TokenizerError.invalidFile("charsmap too short") }
        let trieSize = Int(UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24)
        guard trieSize % 4 == 0, 4 + trieSize <= bytes.count else {
            throw XLMRobertaTokenizer.TokenizerError.invalidFile("charsmap trie size")
        }
        trie = stride(from: 4, to: 4 + trieSize, by: 4).map {
            UInt32(bytes[$0]) | UInt32(bytes[$0 + 1]) << 8 | UInt32(bytes[$0 + 2]) << 16 | UInt32(bytes[$0 + 3]) << 24
        }
        normalized = Array(bytes[(4 + trieSize)...])
    }

    func normalize(_ text: String) -> String {
        var output = ""
        for grapheme in text {
            let utf8 = Array(String(grapheme).utf8)
            if utf8.count < 6, let replacement = transform(utf8) {
                output += replacement
                continue
            }
            for scalar in String(grapheme).unicodeScalars {
                output += transform(Array(String(scalar).utf8)) ?? String(scalar)
            }
        }
        return output
    }

    /// Longest-match semantics follow the crate: the first common-prefix result is used.
    private func transform(_ key: [UInt8]) -> String? {
        guard let index = commonPrefixSearch(key).first, index < normalized.count else { return nil }
        var end = index
        while end < normalized.count, normalized[end] != 0 { end += 1 }
        return String(decoding: normalized[index..<end], as: UTF8.self)
    }

    private func commonPrefixSearch(_ key: [UInt8]) -> [Int] {
        guard !trie.isEmpty else { return [] }
        var results = [Int]()
        var position = 0
        var unit = trie[position]
        position ^= Self.offset(unit)
        for byte in key {
            if byte == 0 { break }
            position ^= Int(byte)
            guard position < trie.count else { return results }
            unit = trie[position]
            if Self.label(unit) != Int(byte) { return results }
            position ^= Self.offset(unit)
            guard position < trie.count else { return results }
            if Self.hasLeaf(unit) { results.append(Self.value(trie[position])) }
        }
        return results
    }

    private static func hasLeaf(_ unit: UInt32) -> Bool { (unit >> 8) & 1 == 1 }
    private static func value(_ unit: UInt32) -> Int { Int(unit & ((1 << 31) - 1)) }
    private static func label(_ unit: UInt32) -> Int { Int(unit & ((1 << 31) | 0xFF)) }
    private static func offset(_ unit: UInt32) -> Int { Int((unit >> 10) << ((unit & (1 << 9)) >> 6)) }
}
