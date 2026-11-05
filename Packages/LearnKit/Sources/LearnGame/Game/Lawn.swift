import CoreGraphics

/// 战场草坪的格子：对齐庭院背景里 9 列 × 5 行的草坪。
/// 场景坐标原点在左下，第 0 行在最下面；幼儿园只有 3 路，用中间三行。
/// 怪物走的路、种植格、缺图时画的路面都按这里算，换背景图只改这一处
struct Lawn {
    /// 草坪在场景里的范围（场景 1200×600）
    static let frame = CGRect(x: 144, y: 20, width: 750, height: 500)
    static let rows = 5
    static let columns = 9

    /// 本局有几路
    let lanes: Int

    var rowHeight: CGFloat { Self.frame.height / CGFloat(Self.rows) }
    var columnWidth: CGFloat { Self.frame.width / CGFloat(Self.columns) }
    /// 第 0 路所在的草坪行
    private var firstRow: Int { (Self.rows - lanes) / 2 }

    /// 这一路的下沿
    func laneBottom(_ lane: Int) -> CGFloat {
        Self.frame.minY + rowHeight * CGFloat(lane + firstRow)
    }

    /// 这一路的中线，怪物和植物都站在这里
    func laneY(_ lane: Int) -> CGFloat {
        laneBottom(lane) + rowHeight / 2
    }

    /// 这一列的中线
    func columnX(_ column: Int) -> CGFloat {
        Self.frame.minX + columnWidth * (CGFloat(column) + 0.5)
    }

    /// 落点所在的种植格；不在草坪上或落在本局没用到的行时返回 nil
    func cell(at point: CGPoint) -> DefenderCell? {
        let frame = Self.frame
        guard point.x >= frame.minX, point.x <= frame.maxX,
              point.y >= frame.minY, point.y <= frame.maxY else { return nil }
        let row = min(Self.rows - 1, Int((point.y - frame.minY) / rowHeight))
        let lane = row - firstRow
        guard (0..<lanes).contains(lane) else { return nil }
        let column = min(Self.columns - 1, Int((point.x - frame.minX) / columnWidth))
        return DefenderCell(lane: lane, column: column)
    }
}
