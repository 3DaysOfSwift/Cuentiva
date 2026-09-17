import SwiftUI

struct ChatPaywallView: View {
    @Bindable var model: ChatViewModel
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Storyteller Chat").font(.system(.title, design: .serif))
            Text("Practise Spanish through conversations with our characters. Explore new topics, reveal English translations, listen to replies and get gentle language help.")
            Text("One-time purchase. No subscription or coins per message. Uses Apple Intelligence on this device.")
                .foregroundStyle(theme.theme.muted)
            if let price = model.price, model.feature.unavailable == nil {
                Button { Task { await model.purchase() } } label: {
                    HStack {
                        Spacer()
                        Text("Unlock chat · \(price)").bold()
                        if model.purchasing { ProgressView() }
                        Spacer()
                    }.padding()
                }.buttonStyle(.borderedProminent).disabled(!model.canBuy)
            } else if model.feature.unavailable == nil {
                Text("The purchase is unavailable right now. Please try again.")
                Button("Retry") { Task { await model.prepare() } }
                    .disabled(model.feature.preparing || model.purchasing)
            }
        }
    }
}
