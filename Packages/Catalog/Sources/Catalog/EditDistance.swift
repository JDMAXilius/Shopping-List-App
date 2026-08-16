// Bounded Levenshtein, ported from resolve.mjs — we only ever care about
// 1–2 character typos. Returns max+1 the moment a row's minimum exceeds max.
public func editDistance(_ a: String, _ b: String, max: Int = 2) -> Int {
    let au = Array(a.utf16)
    let bu = Array(b.utf16)
    if abs(au.count - bu.count) > max { return max + 1 }

    var prev = Array(0...bu.count)
    if au.isEmpty { return prev[bu.count] }

    for i in 1...au.count {
        var cur = [Int](repeating: 0, count: bu.count + 1)
        cur[0] = i
        var best = i
        for j in stride(from: 1, through: bu.count, by: 1) {
            cur[j] = au[i - 1] == bu[j - 1]
                ? prev[j - 1]
                : 1 + min(prev[j - 1], prev[j], cur[j - 1])
            best = min(best, cur[j])
        }
        if best > max { return max + 1 }
        prev = cur
    }
    return prev[bu.count]
}
