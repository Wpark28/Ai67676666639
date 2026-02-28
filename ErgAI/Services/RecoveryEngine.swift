import Foundation
import Combine

/// Calculates recovery score, strain, and energy from Apple Watch Ultra biometrics
/// and user activity data. Modeled after WHOOP-style recovery but uses all available
/// Apple Watch Ultra sensors.
final class RecoveryEngine: ObservableObject {

    @Published var todayStatus: DailyStatus?
    @Published var isCalculating = false

    private let healthKit = HealthKitService()

    // MARK: - Personal Baselines (learned over time)

    struct Baselines {
        var hrvBaseline: Double = 55        // ms, updated with rolling average
        var rhrBaseline: Double = 60        // bpm
        var respRateBaseline: Double = 15   // breaths/min
        var spo2Baseline: Double = 97       // percentage
        var sleepBaseline: Double = 450     // minutes (7.5 hours)
        var tempBaseline: Double = 0        // deviation baseline
        var sampleCount: Int = 0

        mutating func update(hrv: Double?, rhr: Double?, resp: Double?, spo2: Double?, sleep: Int?, temp: Double?) {
            let alpha = sampleCount < 14 ? 0.3 : 0.1  // Learn faster initially
            sampleCount += 1

            if let h = hrv { hrvBaseline = hrvBaseline * (1 - alpha) + h * alpha }
            if let r = rhr { rhrBaseline = rhrBaseline * (1 - alpha) + r * alpha }
            if let rr = resp { respRateBaseline = respRateBaseline * (1 - alpha) + rr * alpha }
            if let s = spo2 { spo2Baseline = spo2Baseline * (1 - alpha) + s * alpha }
            if let sl = sleep { sleepBaseline = sleepBaseline * (1 - alpha) + Double(sl) * alpha }
            if let t = temp { tempBaseline = tempBaseline * (1 - alpha) + t * alpha }
        }
    }

    var baselines = Baselines()

    // MARK: - Recovery Score Calculation

    /// Calculate recovery score from all Apple Watch Ultra data points.
    /// Weighted formula using HRV, RHR, respiratory rate, blood oxygen, sleep, and temperature.
    func calculateRecoveryScore(
        hrv: Double?,
        rhr: Double?,
        respiratoryRate: Double?,
        bloodOxygen: Double?,
        wristTemp: Double?,
        sleepMinutes: Int,
        deepSleepMinutes: Int,
        remSleepMinutes: Int,
        previousDayStrain: Double
    ) -> Double {

        var score: Double = 0
        var totalWeight: Double = 0

        // 1. HRV Score (30% weight) — Higher HRV = better recovery
        // Apple Watch Ultra measures this during sleep
        if let hrv = hrv {
            let hrvWeight = 0.30
            let hrvRatio = hrv / max(baselines.hrvBaseline, 1)
            // Score: ratio > 1 means above baseline (good), < 1 means below (bad)
            let hrvScore = min(max(hrvRatio * 50 + 25, 0), 100)
            score += hrvScore * hrvWeight
            totalWeight += hrvWeight
        }

        // 2. Resting Heart Rate Score (20% weight) — Lower RHR = better recovery
        if let rhr = rhr {
            let rhrWeight = 0.20
            let rhrRatio = baselines.rhrBaseline / max(rhr, 1)
            // Inverted: higher ratio means lower RHR (better)
            let rhrScore = min(max(rhrRatio * 50 + 25, 0), 100)
            score += rhrScore * rhrWeight
            totalWeight += rhrWeight
        }

        // 3. Respiratory Rate Score (10% weight) — Stable/low = good
        if let resp = respiratoryRate {
            let respWeight = 0.10
            let respDeviation = abs(resp - baselines.respRateBaseline) / baselines.respRateBaseline
            // Small deviation from baseline is good
            let respScore = max(100 - respDeviation * 200, 0)
            score += respScore * respWeight
            totalWeight += respWeight
        }

        // 4. Blood Oxygen Score (10% weight) — Higher SpO2 = better
        if let spo2 = bloodOxygen {
            let spo2Weight = 0.10
            let spo2Score: Double
            if spo2 >= 98 { spo2Score = 100 }
            else if spo2 >= 96 { spo2Score = 80 }
            else if spo2 >= 94 { spo2Score = 60 }
            else if spo2 >= 92 { spo2Score = 40 }
            else { spo2Score = 20 }
            score += spo2Score * spo2Weight
            totalWeight += spo2Weight
        }

        // 5. Sleep Score (25% weight) — Duration + quality
        let sleepWeight = 0.25
        let sleepScore = calculateSleepScore(
            totalMinutes: sleepMinutes,
            deepMinutes: deepSleepMinutes,
            remMinutes: remSleepMinutes
        )
        score += sleepScore * sleepWeight
        totalWeight += sleepWeight

        // 6. Wrist Temperature (5% weight) — Deviation from baseline
        // Apple Watch Ultra tracks sleeping wrist temperature
        if let temp = wristTemp {
            let tempWeight = 0.05
            let tempDeviation = abs(temp - baselines.tempBaseline)
            // Large deviation could indicate illness or stress
            let tempScore: Double
            if tempDeviation < 0.2 { tempScore = 100 }
            else if tempDeviation < 0.5 { tempScore = 75 }
            else if tempDeviation < 1.0 { tempScore = 50 }
            else { tempScore = 25 }
            score += tempScore * tempWeight
            totalWeight += tempWeight
        }

        // Normalize if we don't have all data points
        if totalWeight > 0 {
            score = score / totalWeight
        } else {
            score = 50 // Default when no data available
        }

        // Apply strain penalty from previous day
        // High previous-day strain slightly reduces today's recovery
        let strainPenalty = max(0, (previousDayStrain - 12) * 1.5)
        score = max(0, min(100, score - strainPenalty))

        return score
    }

    // MARK: - Sleep Score

    func calculateSleepScore(totalMinutes: Int, deepMinutes: Int, remMinutes: Int) -> Double {
        var score: Double = 0

        // Duration component (60% of sleep score)
        // Optimal: 7-9 hours (420-540 min)
        let durationScore: Double
        if totalMinutes >= 420 && totalMinutes <= 540 {
            durationScore = 100
        } else if totalMinutes >= 360 {
            durationScore = 80
        } else if totalMinutes >= 300 {
            durationScore = 60
        } else if totalMinutes >= 240 {
            durationScore = 40
        } else {
            durationScore = max(Double(totalMinutes) / 420 * 40, 0)
        }
        score += durationScore * 0.6

        // Deep sleep component (25% of sleep score)
        // Target: 15-20% of total sleep = 60-100 min for 7-8 hours
        let deepTarget = Double(totalMinutes) * 0.175
        let deepRatio = totalMinutes > 0 ? Double(deepMinutes) / deepTarget : 0
        let deepScore = min(deepRatio * 100, 100)
        score += deepScore * 0.25

        // REM component (15% of sleep score)
        // Target: 20-25% of total sleep
        let remTarget = Double(totalMinutes) * 0.225
        let remRatio = totalMinutes > 0 ? Double(remMinutes) / remTarget : 0
        let remScore = min(remRatio * 100, 100)
        score += remScore * 0.15

        return min(score, 100)
    }

    // MARK: - Strain Calculation

    /// Calculate strain from a workout/activity.
    /// Strain is on a 0-21 scale (logarithmic, like WHOOP).
    func calculateActivityStrain(
        durationMinutes: Int,
        averageHR: Int?,
        maxHR: Int?,
        maxHeartRate: Int,
        activityType: String
    ) -> Double {

        // Base strain from duration
        let durationHours = Double(durationMinutes) / 60.0
        var strain = 0.0

        if let avgHR = averageHR {
            // HR-based strain: % of max HR determines intensity
            let hrPercent = Double(avgHR) / Double(maxHeartRate)

            // Strain accumulates faster at higher HR zones
            // Zone 1 (<60%): minimal strain
            // Zone 2 (60-70%): low strain
            // Zone 3 (70-80%): moderate
            // Zone 4 (80-90%): high
            // Zone 5 (>90%): very high
            let intensityFactor: Double
            if hrPercent < 0.5 { intensityFactor = 0.5 }
            else if hrPercent < 0.6 { intensityFactor = 1.5 }
            else if hrPercent < 0.7 { intensityFactor = 3.0 }
            else if hrPercent < 0.8 { intensityFactor = 5.5 }
            else if hrPercent < 0.9 { intensityFactor = 9.0 }
            else { intensityFactor = 14.0 }

            strain = durationHours * intensityFactor

            // Spike bonus for max HR peaks
            if let maxHRVal = maxHR {
                let maxPercent = Double(maxHRVal) / Double(maxHeartRate)
                if maxPercent > 0.9 { strain += 1.5 }
                if maxPercent > 0.95 { strain += 1.0 }
            }
        } else {
            // No HR data — estimate from activity type and duration
            let typeFactor: Double
            switch activityType {
            case "rowing_hard", "interval", "2k", "test":
                typeFactor = 8.0
            case "rowing_moderate", "threshold":
                typeFactor = 5.0
            case "steady_state", "rowing_easy":
                typeFactor = 3.0
            case "gym_heavy":
                typeFactor = 5.5
            case "gym_moderate":
                typeFactor = 4.0
            case "walking":
                typeFactor = 1.5
            case "recovery":
                typeFactor = 1.0
            default:
                typeFactor = 3.0
            }
            strain = durationHours * typeFactor
        }

        // Cap at 21
        return min(strain, 21)
    }

    /// Calculate strain from gym lifting specifically.
    func calculateGymStrain(
        totalVolume: Double,
        sets: Int,
        durationMinutes: Int,
        averageHR: Int?,
        maxHeartRate: Int
    ) -> Double {

        let durationHours = Double(durationMinutes) / 60.0

        // Volume-based component
        let volumeStrain = log10(max(totalVolume, 1)) * 0.8

        // Duration component
        let durationStrain = durationHours * 2.5

        // Intensity from sets (more sets = harder session)
        let setStrain = Double(sets) * 0.15

        var strain = volumeStrain + durationStrain + setStrain

        // HR adjustment if available
        if let avgHR = averageHR {
            let hrPercent = Double(avgHR) / Double(maxHeartRate)
            strain *= (0.5 + hrPercent)
        }

        return min(strain, 21)
    }

    // MARK: - Energy Calculation

    /// Calculate starting energy level for the day based on recovery and sleep.
    func calculateBaselineEnergy(recoveryScore: Double, sleepScore: Double) -> Double {
        // Energy starts at a level proportional to recovery
        // Heavily weighted toward recovery score with sleep bonus
        let baseEnergy = recoveryScore * 0.7 + sleepScore * 0.3
        return min(baseEnergy, 100)
    }

    /// Calculate energy drain from an activity.
    /// Returns how much energy (0-100 scale) the activity costs.
    func calculateEnergyDrain(
        strain: Double,
        durationMinutes: Int,
        currentEnergy: Double,
        activityType: String
    ) -> Double {

        // Base drain proportional to strain
        var drain = strain * 3.0

        // Duration multiplier — longer activities drain more even at low intensity
        let durationFactor = 1.0 + (Double(durationMinutes) / 120.0) * 0.3
        drain *= durationFactor

        // Activity type modifier
        switch activityType {
        case "2k", "test", "interval":
            drain *= 1.3       // Race pieces are extra draining
        case "gym_heavy":
            drain *= 1.1
        case "steady_state":
            drain *= 0.8       // SS is relatively easy on energy
        case "recovery", "walking":
            drain *= 0.5       // Light activity barely drains
        default:
            break
        }

        // Mental fatigue from being low energy compounds drain
        if currentEnergy < 30 {
            drain *= 1.2       // Harder to do things when already depleted
        }

        return min(drain, currentEnergy) // Can't drain below 0
    }

    // MARK: - Build Daily Status

    /// Build today's complete status from all data sources.
    func buildDailyStatus(previousDayStrain: Double = 0) async -> DailyStatus {
        await MainActor.run { isCalculating = true }
        defer { Task { @MainActor in isCalculating = false } }

        // Request HealthKit access and fetch all data
        await healthKit.requestAuthorization()
        await healthKit.fetchAllData()

        var status = DailyStatus(date: Date())

        // Populate Apple Watch biometrics
        status.restingHeartRate = healthKit.latestRHR
        status.heartRateVariability = healthKit.latestHRV
        status.respiratoryRate = healthKit.latestRespiratoryRate
        status.bloodOxygen = healthKit.latestBloodOxygen
        status.wristTemperature = healthKit.latestWristTemp

        // Sleep data
        if let sleep = healthKit.latestSleepData {
            status.totalSleepMinutes = sleep.totalMinutes
            status.remSleepMinutes = sleep.remMinutes
            status.deepSleepMinutes = sleep.deepMinutes
            status.lightSleepMinutes = sleep.coreMinutes
            status.awakeMinutes = sleep.awakeMinutes
            status.sleepStartTime = sleep.inBedStart
            status.sleepEndTime = sleep.inBedEnd
        }

        // Activity data
        status.stepsCount = healthKit.todaySteps
        status.activeCaloriesBurned = healthKit.todayActiveCalories
        status.activeMinutes = healthKit.todayActiveMinutes
        status.maxHeartRate = healthKit.todayMaxHR
        status.averageHeartRate = healthKit.todayAvgHR

        // Update baselines with new data
        baselines.update(
            hrv: healthKit.latestHRV,
            rhr: healthKit.latestRHR,
            resp: healthKit.latestRespiratoryRate,
            spo2: healthKit.latestBloodOxygen,
            sleep: healthKit.latestSleepData?.totalMinutes,
            temp: healthKit.latestWristTemp
        )

        // Calculate sleep score
        status.sleepScore = calculateSleepScore(
            totalMinutes: status.totalSleepMinutes,
            deepMinutes: status.deepSleepMinutes,
            remMinutes: status.remSleepMinutes
        )

        // Calculate recovery score from ALL Apple Watch Ultra data
        status.recoveryScore = calculateRecoveryScore(
            hrv: healthKit.latestHRV,
            rhr: healthKit.latestRHR,
            respiratoryRate: healthKit.latestRespiratoryRate,
            bloodOxygen: healthKit.latestBloodOxygen,
            wristTemp: healthKit.latestWristTemp,
            sleepMinutes: status.totalSleepMinutes,
            deepSleepMinutes: status.deepSleepMinutes,
            remSleepMinutes: status.remSleepMinutes,
            previousDayStrain: previousDayStrain
        )

        // Set energy baseline from recovery
        status.energyBaseline = calculateBaselineEnergy(
            recoveryScore: status.recoveryScore,
            sleepScore: status.sleepScore
        )
        status.energyLevel = status.energyBaseline

        // Calculate BMR-based total calories
        status.totalCaloriesBurned = status.activeCaloriesBurned + 1800 // Approximate BMR

        await MainActor.run { todayStatus = status }
        return status
    }
}
