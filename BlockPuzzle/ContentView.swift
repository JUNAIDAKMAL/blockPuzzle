import SwiftUI
import UIKit
import UniformTypeIdentifiers

private let placementGuideLift: CGFloat = 74

private struct PlacementPreview {
    let piece: BlockPiece
    let origin: GridCell
    let isValid: Bool
}

struct ContentView: View {
    @StateObject private var game = GameModel()
    @State private var placementPreview: PlacementPreview?
    @State private var draggedPiece: BlockPiece?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.09, blue: 0.13), Color(red: 0.13, green: 0.16, blue: 0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                header

                BoardView(
                    game: game,
                    placementPreview: $placementPreview,
                    draggedPiece: $draggedPiece
                )
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 18)

                tray

                Spacer(minLength: 0)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            if game.isGameOver {
                gameOverOverlay
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Block Puzzle")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Fill rows or columns to clear space.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    game.newGame()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("New game")
        }
        .padding(.horizontal, 22)
    }

    private var tray: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ScorePill(title: "Score", value: game.score, tint: .cyan)
                ScorePill(title: "Best", value: game.bestScore, tint: .yellow)
            }

            HStack(alignment: .center, spacing: 10) {
                ForEach(game.tray) { piece in
                    PieceView(
                        piece: piece,
                        isSelected: game.selectedPieceID == piece.id,
                        isPlayable: game.hasPlacement(for: piece),
                        onSelect: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                game.selectedPieceID = piece.id
                            }
                        },
                        onDragStarted: {
                            playDragHaptic()
                            draggedPiece = piece
                            withAnimation(.easeOut(duration: 0.12)) {
                                placementPreview = nil
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, minHeight: 116)
            .padding(.horizontal, 18)
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("No Moves")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Score \(game.score)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        game.newGame()
                    }
                } label: {
                    Label("Play Again", systemImage: "play.fill")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .padding(.horizontal, 26)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color(red: 0.07, green: 0.09, blue: 0.13))
                        .background(Color.white, in: Capsule())
                }
            }
            .padding(26)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 30)
        }
    }

    private func playDragHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}

private struct BoardView: View {
    @ObservedObject var game: GameModel
    @Binding var placementPreview: PlacementPreview?
    @Binding var draggedPiece: BlockPiece?

    var body: some View {
        GeometryReader { proxy in
            let cellSize = proxy.size.width / CGFloat(GameModel.boardSize)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.07))

                ForEach(0..<GameModel.boardSize, id: \.self) { row in
                    ForEach(0..<GameModel.boardSize, id: \.self) { col in
                        let cell = GridCell(row: row, col: col)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(game.colorAt(row: row, col: col) ?? Color.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Color.white.opacity(game.colorAt(row: row, col: col) == nil ? 0.06 : 0.24), lineWidth: 1)
                            )
                            .frame(width: cellSize - 4, height: cellSize - 4)
                            .position(
                                x: CGFloat(col) * cellSize + cellSize / 2,
                                y: CGFloat(row) * cellSize + cellSize / 2
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                                    _ = game.placeSelectedPiece(at: cell)
                                }
                            }
                    }
                }

                if let placementPreview {
                    ForEach(placementPreview.piece.cells) { cell in
                        let row = placementPreview.origin.row + cell.row
                        let col = placementPreview.origin.col + cell.col

                        if row >= 0, row < GameModel.boardSize, col >= 0, col < GameModel.boardSize {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(placementShadowFill(for: placementPreview))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .stroke(
                                            placementPreview.isValid ? placementPreview.piece.color.opacity(0.9) : Color.red.opacity(0.88),
                                            lineWidth: placementPreview.isValid ? 2.5 : 1.5
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(Color.white.opacity(placementPreview.isValid ? 0.58 : 0.18), lineWidth: 1)
                                        .padding(4)
                                )
                                .shadow(color: placementPreview.isValid ? placementPreview.piece.color.opacity(0.5) : Color.red.opacity(0.25), radius: 10, y: 4)
                                .frame(width: cellSize - 4, height: cellSize - 4)
                                .position(
                                    x: CGFloat(col) * cellSize + cellSize / 2,
                                    y: CGFloat(row) * cellSize + cellSize / 2
                                )
                                .transition(.scale(scale: 0.82).combined(with: .opacity))
                        }
                    }
                }
            }
            .onDrop(
                of: [UTType.plainText.identifier],
                delegate: BoardDropDelegate(
                    game: game,
                    draggedPiece: $draggedPiece,
                    placementPreview: $placementPreview,
                    cellSize: cellSize
                )
            )
        }
    }

    private func placementShadowFill(for preview: PlacementPreview) -> Color {
        preview.isValid ? preview.piece.color.opacity(0.46) : Color.red.opacity(0.24)
    }
}

private struct BoardDropDelegate: DropDelegate {
    let game: GameModel
    @Binding var draggedPiece: BlockPiece?
    @Binding var placementPreview: PlacementPreview?
    let cellSize: CGFloat

    func dropEntered(info: DropInfo) {
        updatePreview(at: info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updatePreview(at: info.location)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.12)) {
            placementPreview = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        updatePreview(at: info.location)

        guard let preview = placementPreview, preview.isValid else {
            clearDragState()
            return false
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            _ = game.place(preview.piece, at: preview.origin)
        }

        clearDragState()
        return true
    }

    private func updatePreview(at location: CGPoint) {
        guard let piece = draggedPiece else {
            placementPreview = nil
            return
        }

        let origin = placementOrigin(for: piece, at: guideLocation(for: location, piece: piece))
        let preview = PlacementPreview(
            piece: piece,
            origin: origin,
            isValid: game.canPlace(piece, at: origin)
        )

        withAnimation(.interactiveSpring(response: 0.14, dampingFraction: 0.9)) {
            placementPreview = preview
        }
    }

    private func placementOrigin(for piece: BlockPiece, at location: CGPoint) -> GridCell {
        let topLeftX = location.x - (CGFloat(piece.width) * cellSize / 2)
        let topLeftY = location.y - (CGFloat(piece.height) * cellSize / 2)
        let row = Int(round(topLeftY / cellSize))
        let col = Int(round(topLeftX / cellSize))
        return GridCell(row: row, col: col)
    }

    private func guideLocation(for fingerLocation: CGPoint, piece: BlockPiece) -> CGPoint {
        let liftedLocation = CGPoint(x: fingerLocation.x, y: fingerLocation.y - placementGuideLift)
        let minX = CGFloat(piece.width) * cellSize / 2
        let maxX = CGFloat(GameModel.boardSize) * cellSize - minX
        let minY = CGFloat(piece.height) * cellSize / 2
        let maxY = CGFloat(GameModel.boardSize) * cellSize - minY

        return CGPoint(
            x: min(max(liftedLocation.x, minX), maxX),
            y: min(max(liftedLocation.y, minY), maxY)
        )
    }

    private func clearDragState() {
        withAnimation(.easeOut(duration: 0.12)) {
            placementPreview = nil
            draggedPiece = nil
        }
    }
}

private struct PieceView: View {
    let piece: BlockPiece
    let isSelected: Bool
    let isPlayable: Bool
    let onSelect: () -> Void
    let onDragStarted: () -> Void

    private let blockSize: CGFloat = 22
    private let slotSize: CGFloat = 96

    var body: some View {
        ZStack {
            pieceBlocks
                .frame(width: piecePixelWidth, height: piecePixelHeight, alignment: .topLeading)
        }
        .frame(width: slotSize, height: slotSize, alignment: .center)
        .background(pieceBackground)
        .overlay(pieceBorder)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(isPlayable ? 1 : 0.45)
        .scaleEffect(isSelected ? 1.04 : 1)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: isSelected)
        .onTapGesture(perform: onSelect)
        .onDrag {
            onSelect()
            onDragStarted()
            return NSItemProvider(object: piece.id.uuidString as NSString)
        } preview: {
            Color.clear
                .frame(width: 1, height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Puzzle piece")
    }

    private var piecePixelWidth: CGFloat {
        CGFloat(piece.width) * blockSize
    }

    private var piecePixelHeight: CGFloat {
        CGFloat(piece.height) * blockSize
    }

    private var pieceBlocks: some View {
        ZStack(alignment: .topLeading) {
            ForEach(piece.cells) { cell in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(piece.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: piece.color.opacity(0.32), radius: 7, y: 4)
                    .frame(width: blockSize - 3, height: blockSize - 3)
                    .offset(x: CGFloat(cell.col) * blockSize, y: CGFloat(cell.row) * blockSize)
            }
        }
    }

    private var pieceBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
    }

    private var pieceBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(isSelected ? Color.white.opacity(0.42) : Color.white.opacity(0.09), lineWidth: 1)
    }

}

private struct ScorePill: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 9, height: 9)

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))

            Text("\(value)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: Capsule())
    }
}
