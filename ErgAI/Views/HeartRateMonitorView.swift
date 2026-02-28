import SwiftUI

/// View for connecting to Polar H10/H9 and monitoring heart rate in real time.
struct HeartRateMonitorView: View {
    @StateObject private var hrService = BluetoothHRService()
    @Query private var profiles: [AthleteProfile]

    @State private var isRecording = false
    @State private var hrHistory: [Int] = []
    @State private var sessionDuration: TimeInterval = 0
    @State private var timer: Timer?

    private var profile: AthleteProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if hrService.isConnected {
                        connectedView
                    } else if hrService.isScanning {
                        scanningView
                    } else {
                        disconnectedView
                    }
                }
                .padding()
            }
            .navigationTitle("Heart Rate")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Disconnected State

    private var disconnectedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.circle")
                .font(.system(size: 80))
                .foregroundStyle(.red)
                .symbolEffect(.pulse)

            Text("Connect HR Monitor")
                .font(.title2.bold())

            Text("Connect your Polar H10, H9, or other Bluetooth heart rate monitor for real-time tracking during workouts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error = hrService.connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            Button {
                hrService.startScanning()
            } label: {
                Label("Scan for Devices", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }

            // Supported devices
            VStack(alignment: .leading, spacing: 8) {
                Text("Supported Devices")
                    .font(.caption.bold())
                HStack(spacing: 12) {
                    supportedDevice("Polar H10")
                    supportedDevice("Polar H9")
                    supportedDevice("Polar OH1")
                }
                Text("Any Bluetooth LE heart rate monitor will work")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 20)
    }

    private func supportedDevice(_ name: String) -> some View {
        Text(name)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.blue.opacity(0.1), in: Capsule())
            .foregroundStyle(.blue)
    }

    // MARK: - Scanning State

    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Scanning for devices...")
                .font(.headline)

            Text("Make sure your HR strap is moistened and worn")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !hrService.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Found Devices")
                        .font(.subheadline.bold())
                        .padding(.top, 8)

                    ForEach(hrService.discoveredDevices) { device in
                        Button {
                            hrService.connect(to: device)
                        } label: {
                            HStack {
                                Image(systemName: device.isPolar ? "heart.fill" : "heart")
                                    .foregroundStyle(device.isPolar ? .red : .secondary)
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                        .font(.subheadline.bold())
                                    Text("Signal: \(signalDescription(device.rssi))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if device.isPolar {
                                    Text("Polar")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.red.opacity(0.1), in: Capsule())
                                        .foregroundStyle(.red)
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("Stop Scanning") {
                hrService.stopScanning()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Connected State

    private var connectedView: some View {
        VStack(spacing: 20) {
            // Device info bar
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text(hrService.connectedDeviceName ?? "HR Monitor")
                    .font(.subheadline.bold())
                Spacer()
                if let battery = hrService.batteryLevel {
                    Label("\(battery)%", systemImage: batteryIcon(battery))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Disconnect") {
                    hrService.disconnect()
                    stopRecording()
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Big HR Display
            ZStack {
                Circle()
                    .stroke(zoneColor.opacity(0.2), lineWidth: 12)
                    .frame(width: 200, height: 200)
                Circle()
                    .trim(from: 0, to: hrFraction)
                    .stroke(zoneColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: hrService.currentHeartRate)

                VStack(spacing: 4) {
                    Text("\(hrService.currentHeartRate)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(zoneColor)
                        .contentTransition(.numericText())
                        .animation(.default, value: hrService.currentHeartRate)
                    Text("BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currentZoneName)
                        .font(.caption.bold())
                        .foregroundStyle(zoneColor)
                }
            }
            .padding()

            // HR Zones bar
            if let p = profile {
                hrZonesBar(profile: p)
            }

            // Session controls
            if isRecording {
                recordingControls
            } else {
                Button {
                    startRecording()
                } label: {
                    Label("Start Recording", systemImage: "record.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            }

            // Live HR chart
            if !hrHistory.isEmpty {
                hrChart
            }
        }
    }

    // MARK: - Recording Controls

    private var recordingControls: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "record.circle")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
                Text("Recording")
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
                Spacer()
                Text(formatDuration(sessionDuration))
                    .font(.headline.monospacedDigit())
            }

            // Session stats
            if !hrHistory.isEmpty {
                HStack(spacing: 16) {
                    sessionStat("Avg", value: "\(hrHistory.reduce(0, +) / hrHistory.count)")
                    sessionStat("Max", value: "\(hrHistory.max() ?? 0)")
                    sessionStat("Min", value: "\(hrHistory.min() ?? 0)")
                }
            }

            Button {
                stopRecording()
            } label: {
                Label("Stop Recording", systemImage: "stop.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.gray, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private func sessionStat(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - HR Chart

    private var hrChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate History")
                .font(.caption.bold())

            GeometryReader { geo in
                let maxHR = Double(hrHistory.max() ?? 200)
                let minHR = Double(max((hrHistory.min() ?? 60) - 10, 40))
                let range = maxHR - minHR

                Path { path in
                    let step = geo.size.width / max(Double(hrHistory.count - 1), 1)

                    for (index, hr) in hrHistory.enumerated() {
                        let x = step * Double(index)
                        let y = geo.size.height - ((Double(hr) - minHR) / range * geo.size.height)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.red, lineWidth: 2)
            }
            .frame(height: 120)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - HR Zones

    private func hrZonesBar(profile: AthleteProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HR Zones")
                .font(.caption.bold())

            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { zone in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(currentZone == zone ? zoneColorForZone(zone) : zoneColorForZone(zone).opacity(0.2))
                            .frame(height: currentZone == zone ? 30 : 20)
                            .animation(.easeInOut(duration: 0.3), value: currentZone)
                        Text("Z\(zone)")
                            .font(.system(size: 9))
                            .foregroundStyle(currentZone == zone ? zoneColorForZone(zone) : .secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recording Logic

    private func startRecording() {
        isRecording = true
        sessionDuration = 0
        hrHistory.removeAll()
        hrService.startSession()

        hrService.onHeartRateReading = { hr, _ in
            hrHistory.append(hr)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            sessionDuration += 1
        }
    }

    private func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        _ = hrService.endSession()
        hrService.onHeartRateReading = nil
    }

    // MARK: - Helpers

    private var currentZone: Int {
        guard let p = profile else { return 0 }
        return p.heartRateZones.zone(for: hrService.currentHeartRate)
    }

    private var currentZoneName: String {
        guard let p = profile else { return "" }
        return p.heartRateZones.zoneName(currentZone)
    }

    private var zoneColor: Color {
        zoneColorForZone(currentZone)
    }

    private var hrFraction: Double {
        guard let p = profile else { return 0 }
        return min(Double(hrService.currentHeartRate) / Double(p.effectiveMaxHR), 1.0)
    }

    private func zoneColorForZone(_ zone: Int) -> Color {
        switch zone {
        case 1: return .blue
        case 2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }

    private func signalDescription(_ rssi: Int) -> String {
        if rssi > -50 { return "Excellent" }
        if rssi > -70 { return "Good" }
        if rssi > -85 { return "Fair" }
        return "Weak"
    }

    private func batteryIcon(_ level: Int) -> String {
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let min = Int(duration) / 60
        let sec = Int(duration) % 60
        return String(format: "%02d:%02d", min, sec)
    }
}
