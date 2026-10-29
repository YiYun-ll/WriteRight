import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("EssayPilot")
                .font(.largeTitle.bold())
            Text("写作练习，从这里开始。")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
