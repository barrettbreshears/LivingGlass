import Foundation
import AppKit

struct Cell {
    var alive: Bool = false
    var age: Int = 0
    var colorIndex: Int = 0
    var deathFrame: Int = 0
    var jitterX: CGFloat = 0
    var jitterY: CGFloat = 0
}

class GameEngine {
    let width: Int
    let height: Int
    var cells: [[Cell]]
    let maxDeathFrames = 18

    static let palette: [NSColor] = [
        NSColor(red: 0.95, green: 0.26, blue: 0.21, alpha: 1),
        NSColor(red: 0.91, green: 0.12, blue: 0.39, alpha: 1),
        NSColor(red: 0.61, green: 0.15, blue: 0.69, alpha: 1),
        NSColor(red: 0.40, green: 0.23, blue: 0.72, alpha: 1),
        NSColor(red: 0.25, green: 0.32, blue: 0.71, alpha: 1),
        NSColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1),
        NSColor(red: 0.01, green: 0.66, blue: 0.96, alpha: 1),
        NSColor(red: 0.00, green: 0.74, blue: 0.83, alpha: 1),
        NSColor(red: 0.00, green: 0.59, blue: 0.53, alpha: 1),
        NSColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1),
        NSColor(red: 0.55, green: 0.76, blue: 0.29, alpha: 1),
        NSColor(red: 0.80, green: 0.86, blue: 0.22, alpha: 1),
        NSColor(red: 1.00, green: 0.92, blue: 0.23, alpha: 1),
        NSColor(red: 1.00, green: 0.76, blue: 0.03, alpha: 1),
        NSColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1),
        NSColor(red: 0.96, green: 0.33, blue: 0.13, alpha: 1),
    ]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        cells = Array(repeating: Array(repeating: Cell(), count: height), count: width)
        randomize()
    }

    func randomize() {
        for x in 0..<width {
            for y in 0..<height {
                let alive = Double.random(in: 0...1) < 0.25
                cells[x][y] = Cell(
                    alive: alive,
                    age: alive ? Int.random(in: 0...5) : 0,
                    colorIndex: Int.random(in: 0..<Self.palette.count),
                    deathFrame: 0
                )
            }
        }
    }

    private func neighborCount(_ x: Int, _ y: Int) -> Int {
        var count = 0
        for dx in -1...1 {
            for dy in -1...1 {
                if dx == 0 && dy == 0 { continue }
                let nx = (x + dx + width) % width
                let ny = (y + dy + height) % height
                if cells[nx][ny].alive { count += 1 }
            }
        }
        return count
    }

    private func dominantNeighborColor(_ x: Int, _ y: Int) -> Int {
        var counts = [Int: Int]()
        for dx in -1...1 {
            for dy in -1...1 {
                if dx == 0 && dy == 0 { continue }
                let nx = (x + dx + width) % width
                let ny = (y + dy + height) % height
                if cells[nx][ny].alive {
                    counts[cells[nx][ny].colorIndex, default: 0] += 1
                }
            }
        }
        // Slight mutation chance
        if Double.random(in: 0...1) < 0.08 {
            return Int.random(in: 0..<Self.palette.count)
        }
        return counts.max(by: { $0.value < $1.value })?.key
            ?? Int.random(in: 0..<Self.palette.count)
    }

    func step() {
        var next = cells
        var aliveCount = 0

        for x in 0..<width {
            for y in 0..<height {
                let n = neighborCount(x, y)
                let cell = cells[x][y]

                if cell.alive {
                    if n < 2 || n > 3 {
                        next[x][y].alive = false
                        next[x][y].deathFrame = 1
                        next[x][y].jitterX = CGFloat.random(in: -2...2)
                        next[x][y].jitterY = CGFloat.random(in: -2...2)
                        next[x][y].age = 0
                    } else {
                        next[x][y].age = min(cell.age + 1, 50)
                        aliveCount += 1
                    }
                } else {
                    if n == 3 {
                        next[x][y].alive = true
                        next[x][y].age = 0
                        next[x][y].colorIndex = dominantNeighborColor(x, y)
                        next[x][y].deathFrame = 0
                        aliveCount += 1
                    } else if cell.deathFrame > 0 {
                        if cell.deathFrame >= maxDeathFrames {
                            next[x][y].deathFrame = 0
                        } else {
                            next[x][y].deathFrame = cell.deathFrame + 1
                            // Vibration intensity decreases as cell fades
                            let intensity = 2.5 * (1.0 - CGFloat(cell.deathFrame) / CGFloat(maxDeathFrames))
                            next[x][y].jitterX = CGFloat.random(in: -intensity...intensity)
                            next[x][y].jitterY = CGFloat.random(in: -intensity...intensity)
                        }
                    }
                }
            }
        }

        cells = next

        // Inject life if population drops too low
        let total = width * height
        if aliveCount < total / 25 {
            for _ in 0..<5 { injectPattern() }
        } else if aliveCount < total / 12 {
            injectPattern()
        }
    }

    private func injectPattern() {
        let cx = Int.random(in: 10..<max(11, width - 10))
        let cy = Int.random(in: 10..<max(11, height - 10))
        let color = Int.random(in: 0..<Self.palette.count)

        // Random selection of active patterns
        let patterns: [[(Int, Int)]] = [
            // R-pentomino
            [(0,0),(1,0),(-1,1),(0,1),(0,2)],
            // Acorn
            [(0,0),(1,0),(1,2),(3,1),(4,0),(5,0),(6,0)],
            // Glider
            [(0,0),(1,1),(2,1),(2,0),(2,-1)],
            // Lightweight spaceship
            [(0,0),(1,-1),(2,-1),(3,-1),(3,0),(3,1),(2,2),(0,1)],
            // Diehard
            [(0,0),(1,0),(1,1),(5,1),(6,1),(7,1),(6,-1)],
        ]

        let pattern = patterns.randomElement()!
        for (dx, dy) in pattern {
            let x = cx + dx, y = cy + dy
            if x >= 0 && x < width && y >= 0 && y < height {
                cells[x][y] = Cell(alive: true, age: 0, colorIndex: color, deathFrame: 0)
            }
        }
    }
}
