import SwiftUI

/// Root view with tab navigation.
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingCamera = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)

            HeartRateMonitorView()
                .tabItem {
                    Label("HR Monitor", systemImage: "heart.fill")
                }
                .tag(1)

            // Center capture button
            Color.clear
                .tabItem {
                    Label("Capture", systemImage: "camera.fill")
                }
                .tag(2)

            AICoachView()
                .tabItem {
                    Label("AI Coach", systemImage: "brain")
                }
                .tag(3)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(4)
        }
        .tint(.blue)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 2 {
                showingCamera = true
                // Reset to previous tab so the capture tab doesn't show blank
                selectedTab = 0
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView()
        }
    }
}
