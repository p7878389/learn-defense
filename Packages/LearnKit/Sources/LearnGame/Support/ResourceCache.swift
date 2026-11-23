/// 以资源成本和条目数双重约束的 LRU；只释放缓存持有，不影响使用方持有的资源。
struct ResourceCache<Value> {
    private struct Entry {
        let value: Value
        let cost: Int
        var lastAccess: UInt64
    }

    let costLimit: Int
    private let entryLimit: Int
    private var entries: [String: Entry] = [:]
    private var clock: UInt64 = 0
    private(set) var totalCost = 0
    var count: Int { entries.count }
    var values: [Value] { entries.values.map(\.value) }

    init(costLimit: Int, entryLimit: Int = 256) {
        self.costLimit = max(0, costLimit)
        self.entryLimit = max(0, entryLimit)
    }

    mutating func value(for key: String) -> Value? {
        guard var entry = entries[key] else { return nil }
        clock += 1
        entry.lastAccess = clock
        entries[key] = entry
        return entry.value
    }

    mutating func insert(_ value: Value, for key: String, cost: Int) {
        if let old = entries.removeValue(forKey: key) { totalCost -= old.cost }
        let cost = max(0, cost)
        guard cost <= costLimit, entryLimit > 0 else { return }
        // 先释放空间再相加，避免成本相加溢出；超大资源不驱逐其他条目。
        while totalCost > costLimit - cost || entries.count >= entryLimit {
            guard let oldest = entries.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key,
                  let removed = entries.removeValue(forKey: oldest) else { break }
            totalCost -= removed.cost
        }
        clock += 1
        entries[key] = Entry(value: value, cost: cost, lastAccess: clock)
        totalCost += cost
    }

    mutating func removeAll() {
        entries.removeAll()
        totalCost = 0
        clock = 0
    }
}
