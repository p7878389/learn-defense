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
                VStack(spacing: 20) {
                    Text("先选好本局题库，再准备布阵").font(.title2.bold())
                    Button("选择题库") { preparation.chooseBank() }.buttonStyle(.borderedProminent).tint(Theme.jade)
                    Button("返回主页", action: exitGame)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(GrowthPageBackground())
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
