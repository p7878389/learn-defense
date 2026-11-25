import LearnCore
import SpriteKit
import SwiftUI

struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var preparation: GamePreparation
    let onReplay: (GameConfig) -> Void
    let onExit: () -> Void
    let onOpenCollection: () -> Void

    init(config: GameConfig, model: AppModel, onReplay: @escaping (GameConfig) -> Void, onExit: @escaping () -> Void,
         onOpenCollection: @escaping () -> Void = {}) {
        _preparation = StateObject(wrappedValue: GamePreparation(config: config, model: model))
        self.onReplay = onReplay
        self.onExit = onExit
        self.onOpenCollection = onOpenCollection
    }

    var body: some View {
        Group {
            if let session = preparation.session {
                BattleScreen(session: session, onReplay: { onReplay(preparation.config.again()) }, onExit: exitGame,
                   onOpenCollection: onOpenCollection, onChooseBank: { preparation.chooseBank() },
                   onRequestStart: { preparation.requestStartConfirmation() },
                   bankSummary: QuestionBankChoice.summary(config: preparation.config, library: preparation.model.library))
                .id(session.config.id)
            } else {
                ZStack {
                    GrowthPageBackground()
                    CandyModalCard(bannerTitle: "准备开战", bannerIcon: "📚", maxWidth: 440) {
                        Text("先选好本局题库，再进入草坪准备布阵。")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                        VStack(spacing: 12) {
                            Button { preparation.chooseBank() } label: {
                                CandyButtonLabel(title: "选择题库", icon: "📚", font: .system(size: 20, weight: .heavy, design: .rounded),
                                                 height: 54, minWidth: 0, expands: true)
                            }
                            Button(action: exitGame) {
                                CandyButtonLabel(title: "返回主页", icon: "←", fill: GrowthColors.surface, edge: GrowthColors.cardEdge,
                                                 foreground: Theme.ink, font: .system(size: 18, weight: .heavy, design: .rounded),
                                                 height: 48, minWidth: 0, expands: true)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $preparation.choosingBank) {
            QuestionBankPickerView(config: preparation.config, library: preparation.model.library,
                onConfirm: { preparation.confirm($0) },
                onCancel: preparation.cancelChoosing, errorMessage: preparation.error)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $preparation.confirmingStart) {
            if let session = preparation.session {
                GameStartConfirmationView(session: session, library: preparation.model.library,
                                          onConfirm: preparation.confirmStart, onCancel: preparation.cancelStartConfirmation)
            }
        }
    }

    private func exitGame() {
        preparation.session?.end()
        // 游戏页主动关闭自身，避免只发出退出通知后仍停留在结算界面。
        dismiss()
        onExit()
    }
}
