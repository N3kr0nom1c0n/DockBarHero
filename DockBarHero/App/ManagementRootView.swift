import SwiftUI

struct ManagementRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(ManagementRoute.allCases, selection: routeBinding) { route in
                Label(route.title, systemImage: route.systemImage)
                    .tag(route)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 190)
        } detail: {
            switch model.managementRoute {
            case .overview:
                OverviewView(model: model)
            case .inventory:
                InventoryView(model: model)
            case .settings:
                SettingsView(model: model)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    private var routeBinding: Binding<ManagementRoute?> {
        Binding(
            get: { model.managementRoute },
            set: { route in
                guard let route else { return }
                model.selectManagementRoute(route)
            }
        )
    }
}
