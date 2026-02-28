import SwiftUI

/// Root view with tab-based navigation using a "More" menu for overflow tabs.
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingCamera = false
    @State private var showingMore = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)

            RecoveryDashboardView()
                .tabItem {
                    Label("Body", systemImage: "heart.text.square.fill")
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
                    Label("Coach", systemImage: "brain")
                }
                .tag(3)

            MoreTabView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(4)
        }
        .tint(.blue)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 2 {
                showingCamera = true
                selectedTab = 0
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView()
        }
    }
}

/// "More" tab providing access to all additional features.
struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Training") {
                    NavigationLink {
                        HeartRateMonitorView()
                    } label: {
                        Label("HR Monitor", systemImage: "heart.fill")
                            .foregroundStyle(.red)
                    }

                    NavigationLink {
                        GymTrackerView()
                    } label: {
                        Label("Gym Tracker", systemImage: "dumbbell.fill")
                            .foregroundStyle(.blue)
                    }

                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("Erg History", systemImage: "clock.fill")
                            .foregroundStyle(.purple)
                    }
                }

                Section("Body") {
                    NavigationLink {
                        CalorieTrackerView()
                    } label: {
                        Label("Nutrition", systemImage: "fork.knife")
                            .foregroundStyle(.green)
                    }

                    NavigationLink {
                        RecoveryDashboardView()
                    } label: {
                        Label("Recovery & Sleep", systemImage: "bed.double.fill")
                            .foregroundStyle(.indigo)
                    }
                }

                Section("Settings") {
                    NavigationLink {
                        ProfileSetupView()
                    } label: {
                        Label("Profile", systemImage: "person.circle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}
