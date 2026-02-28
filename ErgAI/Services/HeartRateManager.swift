import Foundation
import Combine
import HealthKit

/// Unified heart rate manager that uses Polar H10/H9 when connected,
/// and falls back to Apple Watch heart rate for 24/7 tracking.
final class HeartRateManager: ObservableObject {

    // MARK: - Published State

    @Published var currentHeartRate: Int = 0
    @Published var heartRateSource: HeartRateSource = .none
    @Published var isActive = false

    enum HeartRateSource: String {
        case polar = "Polar"
        case appleWatch = "Apple Watch"
        case none = "No Source"

        var icon: String {
            switch self {
            case .polar: return "heart.fill"
            case .appleWatch: return "applewatch"
            case .none: return "heart.slash"
            }
        }
    }

    // MARK: - Services

    let bluetoothHR: BluetoothHRService
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    private var watchHRQuery: HKAnchoredObjectQuery?

    // Callback for each HR reading
    var onHeartRateReading: ((Int, HeartRateSource) -> Void)?

    // MARK: - Init

    init(bluetoothHR: BluetoothHRService = BluetoothHRService()) {
        self.bluetoothHR = bluetoothHR
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // When Polar connects/disconnects, switch sources automatically
        bluetoothHR.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self else { return }
                if connected {
                    // Polar connected — use it as primary, stop Apple Watch streaming
                    self.stopAppleWatchHR()
                    self.heartRateSource = .polar
                    self.isActive = true
                } else {
                    // Polar disconnected — fall back to Apple Watch
                    self.startAppleWatchHR()
                }
            }
            .store(in: &cancellables)

        // Relay Polar HR readings
        bluetoothHR.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                guard let self, self.bluetoothHR.isConnected, hr > 0 else { return }
                self.currentHeartRate = hr
                self.heartRateSource = .polar
                self.onHeartRateReading?(hr, .polar)
            }
            .store(in: &cancellables)
    }

    // MARK: - Apple Watch HR Streaming

    /// Start streaming heart rate from Apple Watch via HealthKit.
    func startAppleWatchHR() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        // Don't start if Polar is connected
        guard !bluetoothHR.isConnected else { return }

        stopAppleWatchHR()

        heartRateSource = .appleWatch
        isActive = true

        // Use anchored object query to get live updates
        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: HKQuery.predicateForSamples(
                withStart: Date().addingTimeInterval(-60),
                end: nil,
                options: .strictStartDate
            ),
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processWatchHRSamples(samples as? [HKQuantitySample])
        }

        // Handle live updates
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processWatchHRSamples(samples as? [HKQuantitySample])
        }

        watchHRQuery = query
        healthStore.execute(query)
    }

    /// Stop the Apple Watch HR stream.
    func stopAppleWatchHR() {
        if let query = watchHRQuery {
            healthStore.stop(query)
            watchHRQuery = nil
        }
        if heartRateSource == .appleWatch {
            heartRateSource = .none
            isActive = false
        }
    }

    /// Start 24/7 monitoring — uses Polar if connected, otherwise Apple Watch.
    func startMonitoring() {
        if bluetoothHR.isConnected {
            heartRateSource = .polar
            isActive = true
        } else {
            startAppleWatchHR()
        }
    }

    /// Stop all HR monitoring.
    func stopMonitoring() {
        stopAppleWatchHR()
        isActive = false
        heartRateSource = .none
    }

    // MARK: - Fetch Recent Apple Watch HR

    /// Get recent heart rate samples from Apple Watch for the last N minutes.
    func fetchRecentAppleWatchHR(minutes: Int = 60) async -> [(date: Date, hr: Int)] {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }

        let start = Date().addingTimeInterval(-Double(minutes * 60))
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, _ in
                let unit = HKUnit.count().unitDivided(by: .minute())
                let results = (samples as? [HKQuantitySample])?.map {
                    (date: $0.startDate, hr: Int($0.quantity.doubleValue(for: unit)))
                } ?? []
                continuation.resume(returning: results)
            }
            self.healthStore.execute(query)
        }
    }

    /// Get today's Apple Watch HR stats.
    func fetchTodayHRStats() async -> (avg: Int?, max: Int?, min: Int?) {
        let samples = await fetchRecentAppleWatchHR(minutes: 1440) // 24 hours
        guard !samples.isEmpty else { return (nil, nil, nil) }

        let hrs = samples.map(\.hr)
        let avg = hrs.reduce(0, +) / hrs.count
        let max = hrs.max() ?? 0
        let min = hrs.min() ?? 0
        return (avg, max, min)
    }

    // MARK: - Private

    private func processWatchHRSamples(_ samples: [HKQuantitySample]?) {
        guard let samples, !samples.isEmpty else { return }
        guard !bluetoothHR.isConnected else { return } // Polar takes priority

        let unit = HKUnit.count().unitDivided(by: .minute())
        if let latest = samples.last {
            let hr = Int(latest.quantity.doubleValue(for: unit))
            DispatchQueue.main.async { [weak self] in
                self?.currentHeartRate = hr
                self?.heartRateSource = .appleWatch
                self?.onHeartRateReading?(hr, .appleWatch)
            }
        }
    }
}
