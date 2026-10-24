import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context

    var body: some View {
        @Bindable var appModel = appModel
        TabView(selection: $appModel.selectedTab) {
            NavigationStack(path: $appModel.quotesPath) {
                QuotesHomeView()
                    .navigationDestination(for: Route.self) { route in
                        destination(for: route)
                    }
            }
            .tabItem { Label("Quotes", systemImage: "doc.text") }
            .tag(AppTab.quotes)

            NavigationStack { ClientsView() }
                .tabItem { Label("Clients", systemImage: "person") }
                .tag(AppTab.clients)

            NavigationStack { PricesView() }
                .tabItem { Label("Prices", systemImage: "tag") }
                .tag(AppTab.prices)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Theme.accentText)
        .sheet(isPresented: $appModel.isPaywallPresented) {
            PaywallView()
        }
        #if DEBUG
        .task { DebugLaunch.apply(to: appModel, context: context) }
        #endif
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .scan:
            ScanRoomView()
        case .manualEntry:
            ManualMeasurementsView()
        case .materials(let quote):
            RoomMaterialsView(quote: quote)
        case .quote(let quote):
            QuoteView(quote: quote)
        case .allQuotes(let focusSearch):
            AllQuotesView(focusSearch: focusSearch)
        }
    }
}
