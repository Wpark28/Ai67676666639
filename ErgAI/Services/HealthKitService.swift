import Foundation
import HealthKit
import Combine

/// Service that pulls biometric data from Apple Watch Ultra via HealthKit.
/// Reads: HRV, RHR, respiratory rate, blood oxygen, wrist temp, sleep, activity.
final class HealthKitService: ObservableObject {

    @Published var isAuthorized = false
    @Published var authorizationError: String?

    // Latest readings
    @Published var latestHRV: Double?           // ms (SDNN)
    @Published var latestRHR: Double?           // bpm
    @Published var latestRespiratoryRate: Double? // breaths/min
    @Published var latestBloodOxygen: Double?   // percentage (e.g., 98.5)
    @Published var latestWristTemp: Double?     // deviation in °C
    @Published var latestSleepData: SleepData?
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Int = 0
    @Published var todayActiveMinutes: Int = 0
    @Published var todayMaxHR: Int?
    @Published var todayAvgHR: Int?

    private let healthStore = HKHealthStore()

    struct SleepData {
        var totalMinutes: Int = 0
        var remMinutes: Int = 0
        var deepMinutes: Int = 0
        var coreMinutes: Int = 0
        var awakeMinutes: Int = 0
        var inBedStart: Date?
        var inBedEnd: Date?
    }

    // MARK: - HealthKit Types

    /// All the data types we read from Apple Watch Ultra.
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        // Heart
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let rhr = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { types.insert(rhr) }
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }

        // Respiratory
        if let rr = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) { types.insert(rr) }

        // Blood Oxygen
        if let spo2 = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) { types.insert(spo2) }

        // Temperature (Apple Watch Ultra)
        if let wristTemp = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) { types.insert(wristTemp) }

        // Sleep
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }

        // Activity
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let activeCal = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(activeCal) }
        if let exercise = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) { types.insert(exercise) }

        // VO2 Max
        if let vo2 = HKQuantityType.quantityType(forIdentifier: .vo2Max) { types.insert(vo2) }

        return types
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            await MainActor.run {
                authorizationError = "Health data is not available on this device."
            }
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            await MainActor.run {
                isAuthorized = true
                authorizationError = nil
            }
        } catch {
            await MainActor.run {
                authorizationError = "HealthKit authorization failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Fetch All Data

    /// Fetch all biometric data for recovery calculation.
    func fetchAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchHRV() }
            group.addTask { await self.fetchRHR() }
            group.addTask { await self.fetchRespiratoryRate() }
            group.addTask { await self.fetchBloodOxygen() }
            group.addTask { await self.fetchWristTemperature() }
            group.addTask { await self.fetchSleep() }
            group.addTask { await self.fetchSteps() }
            group.addTask { await self.fetchActiveCalories() }
            group.addTask { await self.fetchExerciseMinutes() }
            group.addTask { await self.fetchHeartRateStats() }
        }
    }

    // MARK: - Individual Fetchers

    func fetchHRV() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        if let sample = await fetchMostRecentSample(type: type) {
            let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            await MainActor.run { latestHRV = value }
        }
    }

    func fetchRHR() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }
        if let sample = await fetchMostRecentSample(type: type) {
            let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            await MainActor.run { latestRHR = value }
        }
    }

    func fetchRespiratoryRate() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return }
        if let sample = await fetchMostRecentSample(type: type) {
            let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            await MainActor.run { latestRespiratoryRate = value }
        }
    }

    func fetchBloodOxygen() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        if let sample = await fetchMostRecentSample(type: type) {
            let value = sample.quantity.doubleValue(for: HKUnit.percent()) * 100
            await MainActor.run { latestBloodOxygen = value }
        }
    }

    func fetchWristTemperature() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else { return }
        if let sample = await fetchMostRecentSample(type: type) {
            let value = sample.quantity.doubleValue(for: HKUnit.degreeCelsius())
            await MainActor.run { latestWristTemp = value }
        }
    }

    func fetchSteps() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let total = await fetchTodayTotal(type: type, unit: HKUnit.count())
        await MainActor.run { todaySteps = Int(total) }
    }

    func fetchActiveCalories() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let total = await fetchTodayTotal(type: type, unit: HKUnit.kilocalorie())
        await MainActor.run { todayActiveCalories = Int(total) }
    }

    func fetchExerciseMinutes() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return }
        let total = await fetchTodayTotal(type: type, unit: HKUnit.minute())
        await MainActor.run { todayActiveMinutes = Int(total) }
    }

    func fetchHeartRateStats() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let samples = await fetchSamples(type: type, predicate: predicate, limit: 500)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let values = samples.map { $0.quantity.doubleValue(for: unit) }

        if !values.isEmpty {
            await MainActor.run {
                todayMaxHR = Int(values.max() ?? 0)
                todayAvgHR = Int(values.reduce(0, +) / Double(values.count))
            }
        }
    }

    func fetchSleep() async {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        // Look for sleep in the last 24 hours
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { [weak self] _, samples, error in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume()
                    return
                }

                var sleepData = SleepData()
                sleepData.inBedStart = samples.first?.startDate
                sleepData.inBedEnd = samples.last?.endDate

                for sample in samples {
                    let minutes = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)

                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        sleepData.remMinutes += minutes
                        sleepData.totalMinutes += minutes
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        sleepData.deepMinutes += minutes
                        sleepData.totalMinutes += minutes
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        sleepData.coreMinutes += minutes
                        sleepData.totalMinutes += minutes
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        sleepData.awakeMinutes += minutes
                    default:
                        // asleepUnspecified or inBed
                        if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                            sleepData.totalMinutes += minutes
                        }
                    }
                }

                DispatchQueue.main.async {
                    self?.latestSleepData = sleepData
                }
                continuation.resume()
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Historical Data

    /// Fetch HRV trend over last N days.
    func fetchHRVHistory(days: Int) async -> [(Date, Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let samples = await fetchSamples(type: type, predicate: predicate, limit: days * 5)
        return samples.map { ($0.startDate, $0.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))) }
    }

    /// Fetch RHR trend over last N days.
    func fetchRHRHistory(days: Int) async -> [(Date, Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let samples = await fetchSamples(type: type, predicate: predicate, limit: days * 2)
        return samples.map { ($0.startDate, $0.quantity.doubleValue(for: unit)) }
    }

    // MARK: - Generic Helpers

    private func fetchMostRecentSample(type: HKQuantityType) async -> HKQuantitySample? {
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -3, to: Date()), end: Date(), options: .strictStartDate)
        let samples = await fetchSamples(type: type, predicate: predicate, limit: 1)
        return samples.first
    }

    private func fetchSamples(type: HKQuantityType, predicate: NSPredicate, limit: Int) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchTodayTotal(type: HKQuantityType, unit: HKUnit) async -> Double {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let total = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: total)
            }
            healthStore.execute(query)
        }
    }
}
