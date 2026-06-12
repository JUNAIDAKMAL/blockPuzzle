import SwiftUI

struct GridCell: Identifiable, Hashable {
    let row: Int
    let col: Int

    var id: String { "\(row)-\(col)" }
}

struct BlockPiece: Identifiable, Equatable {
    let id = UUID()
    let cells: [GridCell]
    let color: Color

    var width: Int {
        (cells.map(\.col).max() ?? 0) + 1
    }

    var height: Int {
        (cells.map(\.row).max() ?? 0) + 1
    }
}

@MainActor
final class GameModel: ObservableObject {
    static let boardSize = 10

    @Published private(set) var board: [[Color?]]
    @Published private(set) var tray: [BlockPiece]
    @Published private(set) var score: Int
    @Published private(set) var bestScore: Int
    @Published private(set) var isGameOver: Bool
    @Published var selectedPieceID: UUID?

    private let bestScoreKey = "BlockPuzzleBestScore"

    init() {
        self.board = Array(
            repeating: Array(repeating: nil, count: Self.boardSize),
            count: Self.boardSize
        )
        self.tray = []
        self.score = 0
        self.bestScore = UserDefaults.standard.integer(forKey: bestScoreKey)
        self.isGameOver = false
        refillTray()
    }

    func newGame() {
        board = Array(
            repeating: Array(repeating: nil, count: Self.boardSize),
            count: Self.boardSize
        )
        tray = []
        score = 0
        isGameOver = false
        selectedPieceID = nil
        refillTray()
    }

    func piece(with id: UUID) -> BlockPiece? {
        tray.first { $0.id == id }
    }

    func colorAt(row: Int, col: Int) -> Color? {
        guard row >= 0, row < Self.boardSize, col >= 0, col < Self.boardSize else {
            return nil
        }
        return board[row][col]
    }

    func canPlace(_ piece: BlockPiece, at origin: GridCell) -> Bool {
        piece.cells.allSatisfy { cell in
            let row = origin.row + cell.row
            let col = origin.col + cell.col

            return row >= 0
                && row < Self.boardSize
                && col >= 0
                && col < Self.boardSize
                && board[row][col] == nil
        }
    }

    @discardableResult
    func placeSelectedPiece(at origin: GridCell) -> Bool {
        guard let selectedPieceID, let piece = piece(with: selectedPieceID) else {
            return false
        }
        return place(piece, at: origin)
    }

    @discardableResult
    func place(_ piece: BlockPiece, at origin: GridCell) -> Bool {
        guard canPlace(piece, at: origin) else {
            return false
        }

        for cell in piece.cells {
            board[origin.row + cell.row][origin.col + cell.col] = piece.color
        }

        score += piece.cells.count
        let clearedLines = clearCompletedLines()
        if clearedLines > 0 {
            score += clearedLines * clearedLines * 20
        }

        tray.removeAll { $0.id == piece.id }
        selectedPieceID = nil

        if tray.isEmpty {
            refillTray()
        }

        updateBestScore()
        isGameOver = !tray.contains { hasPlacement(for: $0) }
        return true
    }

    func hasPlacement(for piece: BlockPiece) -> Bool {
        for row in 0..<Self.boardSize {
            for col in 0..<Self.boardSize {
                if canPlace(piece, at: GridCell(row: row, col: col)) {
                    return true
                }
            }
        }
        return false
    }

    private func clearCompletedLines() -> Int {
        let fullRows = Set(
            board.indices.filter { row in
                board[row].allSatisfy { $0 != nil }
            }
        )

        let fullCols = Set(
            (0..<Self.boardSize).filter { col in
                board.indices.allSatisfy { row in board[row][col] != nil }
            }
        )

        guard !fullRows.isEmpty || !fullCols.isEmpty else {
            return 0
        }

        for row in fullRows {
            for col in 0..<Self.boardSize {
                board[row][col] = nil
            }
        }

        for col in fullCols {
            for row in 0..<Self.boardSize {
                board[row][col] = nil
            }
        }

        return fullRows.count + fullCols.count
    }

    private func refillTray() {
        tray = (0..<3).map { _ in Self.randomPiece() }
        isGameOver = !tray.contains { hasPlacement(for: $0) }
    }

    private func updateBestScore() {
        guard score > bestScore else { return }
        bestScore = score
        UserDefaults.standard.set(bestScore, forKey: bestScoreKey)
    }

    private static func randomPiece() -> BlockPiece {
        let shapes: [[GridCell]] = [
            [GridCell(row: 0, col: 0)],
            [GridCell(row: 0, col: 0), GridCell(row: 0, col: 1)],
            [GridCell(row: 0, col: 0), GridCell(row: 1, col: 0)],
            [GridCell(row: 0, col: 0), GridCell(row: 0, col: 1), GridCell(row: 0, col: 2)],
            [GridCell(row: 0, col: 0), GridCell(row: 1, col: 0), GridCell(row: 2, col: 0)],
            [GridCell(row: 0, col: 0), GridCell(row: 0, col: 1), GridCell(row: 1, col: 0)],
            [GridCell(row: 0, col: 0), GridCell(row: 0, col: 1), GridCell(row: 1, col: 1)],
            [GridCell(row: 0, col: 1), GridCell(row: 1, col: 0), GridCell(row: 1, col: 1)],
            [GridCell(row: 0, col: 0), GridCell(row: 1, col: 0), GridCell(row: 1, col: 1)],
            [GridCell(row: 0, col: 0), GridCell(row: 0, col: 1), GridCell(row: 1, col: 0), GridCell(row: 1, col: 1)],
            [GridCell(row: 0, col: 0), GridCell(row: 0, col: 1), GridCell(row: 0, col: 2), GridCell(row: 0, col: 3)],
            [GridCell(row: 0, col: 0), GridCell(row: 1, col: 0), GridCell(row: 2, col: 0), GridCell(row: 3, col: 0)],
            [GridCell(row: 0, col: 0), GridCell(row: 0, col: 1), GridCell(row: 0, col: 2), GridCell(row: 1, col: 1)],
            [GridCell(row: 0, col: 1), GridCell(row: 1, col: 0), GridCell(row: 1, col: 1), GridCell(row: 1, col: 2)],
            [GridCell(row: 0, col: 0), GridCell(row: 1, col: 0), GridCell(row: 1, col: 1), GridCell(row: 2, col: 1)],
            [GridCell(row: 0, col: 1), GridCell(row: 1, col: 0), GridCell(row: 1, col: 1), GridCell(row: 2, col: 0)],
            [GridCell(row: 0, col: 0), GridCell(row: 0, col: 1), GridCell(row: 0, col: 2), GridCell(row: 1, col: 0), GridCell(row: 2, col: 0)],
            [GridCell(row: 0, col: 0), GridCell(row: 0, col: 1), GridCell(row: 0, col: 2), GridCell(row: 1, col: 2), GridCell(row: 2, col: 2)]
        ]

        let palette: [Color] = [
            .cyan,
            .mint,
            .orange,
            .pink,
            .indigo,
            .teal,
            .red,
            .yellow
        ]

        return BlockPiece(cells: shapes.randomElement() ?? shapes[0], color: palette.randomElement() ?? .cyan)
    }
}
