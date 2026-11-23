import Testing
@testable import LearnGame

@Suite("资源缓存预算")
struct ResourceCacheTests {
    @Test func evictsLeastRecentlyUsedAndAccountsForReplacement() {
        var cache = ResourceCache<String>(costLimit: 8)
        cache.insert("first", for: "a", cost: 4)
        cache.insert("second", for: "b", cost: 4)
        let recentHit = cache.value(for: "a")
        #expect(recentHit == "first")
        cache.insert("third", for: "c", cost: 4)
        let evicted = cache.value(for: "b")
        #expect(evicted == nil)
        let retained = cache.value(for: "a")
        #expect(retained == "first")
        cache.insert("replacement", for: "a", cost: 2)
        #expect(cache.totalCost == 6)
        cache.insert("oversized", for: "a", cost: 9)
        let oversizedReplacement = cache.value(for: "a")
        #expect(oversizedReplacement == nil)
        let otherEntry = cache.value(for: "c")
        #expect(otherEntry == "third", "超大资源不能驱逐不相关缓存")
        #expect(cache.totalCost == 4)
    }

    @Test func entryLimitAlsoBoundsZeroCostValues() {
        var cache = ResourceCache<Int>(costLimit: 8, entryLimit: 2)
        for i in 0..<100 { cache.insert(i, for: "\(i)", cost: 0) }
        #expect(cache.count == 2)
        let oldest = cache.value(for: "97")
        #expect(oldest == nil)
        let penultimate = cache.value(for: "98")
        #expect(penultimate == 98)
        let newest = cache.value(for: "99")
        #expect(newest == 99)
    }

    @Test func clearingTheCacheDoesNotDestroyAnActiveOwnersResource() {
        var cache = ResourceCache<Token>(costLimit: 1)
        var released = false
        var owner: Token? = Token { released = true }
        cache.insert(owner!, for: "active", cost: 1)
        cache.removeAll()
        #expect(cache.count == 0 && cache.totalCost == 0)
        withExtendedLifetime(owner) { #expect(!released) }
        owner = nil
        #expect(released, "缓存清理后不应继续持有资源")
    }
}

private final class Token {
    let onRelease: () -> Void
    init(onRelease: @escaping () -> Void) { self.onRelease = onRelease }
    deinit { onRelease() }
}
