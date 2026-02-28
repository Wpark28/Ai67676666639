import Foundation
import Vision
import UIKit
import Combine

/// Service that uses Vision framework to OCR erg (Concept2) monitor screens.
/// Extracts time, distance, split, stroke rate, calories, and other metrics.
final class ErgOCRService: ObservableObject {

    @Published var isProcessing = false
    @Published var lastError: String?
    @Published var ocrConfidence: Double = 0

    /// Result from OCR processing of an erg screen photo.
    struct OCRResult {
        var time: String?
        var distance: String?
        var split: String?
        var strokeRate: String?
        var calories: String?
        var watts: String?
        var averageHeartRate: String?
        var dragFactor: String?
        var rawText: String
        var confidence: Double
        var allLines: [String]

        /// Try to parse into an ErgScore object.
        func toErgScore() -> ErgScore? {
            guard let splitVal = parseSplit(),
                  let distVal = parseDistance(),
                  let timeVal = parseTime() else {
                return nil
            }

            let score = ErgScore(
                distanceMeters: distVal,
                timeSeconds: timeVal,
                splitSeconds: splitVal,
                strokeRate: parseStrokeRate() ?? 0,
                averageWatts: parseWatts() ?? ErgScore.wattsFromSplit(splitVal),
                calories: parseCalories() ?? 0,
                workoutType: guessWorkoutType(distance: distVal, time: timeVal),
                capturedFromPhoto: true
            )

            score.ocrConfidence = confidence
            score.rawOCRText = rawText

            if let hr = parseHeartRate() {
                score.averageHeartRate = hr
            }
            if let df = parseDragFactor() {
                score.averageDragFactor = df
            }

            return score
        }

        // MARK: - Parsing Helpers

        private func parseSplit() -> Double? {
            guard let splitStr = split else { return nil }
            return parseTimeString(splitStr)
        }

        private func parseTime() -> Double? {
            guard let timeStr = time else { return nil }
            return parseTimeString(timeStr)
        }

        private func parseDistance() -> Int? {
            guard let distStr = distance else { return nil }
            let cleaned = distStr.replacingOccurrences(of: ",", with: "")
                                 .replacingOccurrences(of: "m", with: "")
                                 .replacingOccurrences(of: " ", with: "")
            return Int(cleaned)
        }

        private func parseStrokeRate() -> Int? {
            guard let srStr = strokeRate else { return nil }
            let cleaned = srStr.replacingOccurrences(of: "s/m", with: "")
                               .replacingOccurrences(of: "spm", with: "")
                               .trimmingCharacters(in: .whitespaces)
            return Int(cleaned)
        }

        private func parseCalories() -> Int? {
            guard let calStr = calories else { return nil }
            let cleaned = calStr.replacingOccurrences(of: "Cal", with: "")
                                .trimmingCharacters(in: .whitespaces)
            return Int(cleaned)
        }

        private func parseWatts() -> Double? {
            guard let wStr = watts else { return nil }
            let cleaned = wStr.replacingOccurrences(of: "W", with: "")
                              .replacingOccurrences(of: "w", with: "")
                              .trimmingCharacters(in: .whitespaces)
            return Double(cleaned)
        }

        private func parseHeartRate() -> Int? {
            guard let hrStr = averageHeartRate else { return nil }
            let cleaned = hrStr.replacingOccurrences(of: "bpm", with: "")
                               .trimmingCharacters(in: .whitespaces)
            return Int(cleaned)
        }

        private func parseDragFactor() -> Int? {
            guard let dfStr = dragFactor else { return nil }
            return Int(dfStr.trimmingCharacters(in: .whitespaces))
        }

        private func parseTimeString(_ str: String) -> Double? {
            let cleaned = str.trimmingCharacters(in: .whitespaces)

            // Handle H:MM:SS.s format
            let hmsPattern = #"(\d+):(\d{2}):(\d{2})\.?(\d)?"#
            if let match = cleaned.range(of: hmsPattern, options: .regularExpression) {
                let parts = String(cleaned[match]).split(separator: ":")
                if parts.count == 3 {
                    let hours = Double(parts[0]) ?? 0
                    let minutes = Double(parts[1]) ?? 0
                    let secParts = parts[2].split(separator: ".")
                    let seconds = Double(secParts[0]) ?? 0
                    let tenths = secParts.count > 1 ? (Double(secParts[1]) ?? 0) / 10.0 : 0
                    return hours * 3600 + minutes * 60 + seconds + tenths
                }
            }

            // Handle M:SS.s format
            let msPattern = #"(\d+):(\d{2})\.?(\d)?"#
            if let match = cleaned.range(of: msPattern, options: .regularExpression) {
                let timeStr = String(cleaned[match])
                let colonParts = timeStr.split(separator: ":")
                if colonParts.count == 2 {
                    let minutes = Double(colonParts[0]) ?? 0
                    let secParts = colonParts[1].split(separator: ".")
                    let seconds = Double(secParts[0]) ?? 0
                    let tenths = secParts.count > 1 ? (Double(secParts[1]) ?? 0) / 10.0 : 0
                    return minutes * 60 + seconds + tenths
                }
            }

            return nil
        }

        private func guessWorkoutType(distance: Int, time: Double) -> String {
            // Try to determine workout type from distance/time
            switch distance {
            case 1900...2100: return "2k"
            case 4900...5100: return "5k"
            case 5900...6100: return "6k"
            case 9900...10100: return "10k"
            case 450...550: return "500m"
            default:
                // Check for timed pieces
                if abs(time - 1800) < 60 { return "30min" }
                if abs(time - 3600) < 60 { return "60min" }
                return "other"
            }
        }
    }

    // MARK: - Public API

    /// Process an image and extract erg score data.
    func processImage(_ image: UIImage) async -> OCRResult? {
        await MainActor.run { isProcessing = true }

        defer {
            Task { @MainActor in isProcessing = false }
        }

        guard let cgImage = image.cgImage else {
            await MainActor.run { lastError = "Could not process image." }
            return nil
        }

        do {
            let recognizedText = try await performOCR(on: cgImage)
            let result = parseErgData(from: recognizedText)
            await MainActor.run {
                ocrConfidence = result.confidence
                lastError = nil
            }
            return result
        } catch {
            await MainActor.run {
                lastError = "OCR failed: \(error.localizedDescription)"
            }
            return nil
        }
    }

    // MARK: - Private OCR Methods

    private func performOCR(on image: CGImage) async throws -> [(String, Float)] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var results: [(String, Float)] = []
                for observation in observations {
                    if let candidate = observation.topCandidates(1).first {
                        results.append((candidate.string, candidate.confidence))
                    }
                }
                continuation.resume(returning: results)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            // Custom words common on erg screens
            request.customWords = [
                "s/m", "spm", "/500m", "Cal", "Watts",
                "Avg", "Rest", "Work", "Interval",
                "Drag Factor", "Stroke Rate"
            ]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Parse recognized text lines into structured erg data.
    private func parseErgData(from recognizedText: [(String, Float)]) -> OCRResult {
        let allLines = recognizedText.map { $0.0 }
        let rawText = allLines.joined(separator: "\n")
        let avgConfidence = recognizedText.isEmpty ? 0 :
            Double(recognizedText.map { $0.1 }.reduce(0, +)) / Double(recognizedText.count)

        var result = OCRResult(
            rawText: rawText,
            confidence: avgConfidence,
            allLines: allLines
        )

        for (text, _) in recognizedText {
            let lower = text.lowercased()

            // Look for time patterns (M:SS.s or H:MM:SS.s)
            if result.time == nil {
                if let timeMatch = extractPattern(from: text, pattern: #"\d{1,2}:\d{2}:\d{2}\.\d"#) {
                    result.time = timeMatch
                } else if lower.contains("time") || lower.contains("elapsed") {
                    if let timeMatch = extractPattern(from: text, pattern: #"\d{1,2}:\d{2}\.\d"#) {
                        result.time = timeMatch
                    }
                }
            }

            // Look for distance (number followed by 'm' or large number)
            if result.distance == nil {
                if let distMatch = extractPattern(from: text, pattern: #"[\d,]+\s*m\b"#) {
                    result.distance = distMatch
                } else if lower.contains("meter") || lower.contains("distance") {
                    if let distMatch = extractPattern(from: text, pattern: #"[\d,]+"#) {
                        result.distance = distMatch
                    }
                }
            }

            // Look for split (/500m format)
            if result.split == nil {
                if lower.contains("/500") || lower.contains("split") || lower.contains("pace") {
                    if let splitMatch = extractPattern(from: text, pattern: #"\d:\d{2}\.\d"#) {
                        result.split = splitMatch
                    }
                }
            }

            // Look for stroke rate
            if result.strokeRate == nil {
                if lower.contains("s/m") || lower.contains("spm") || lower.contains("stroke") || lower.contains("rate") {
                    if let srMatch = extractPattern(from: text, pattern: #"\d{2}"#) {
                        let val = Int(srMatch) ?? 0
                        if val >= 16 && val <= 50 {
                            result.strokeRate = srMatch
                        }
                    }
                }
            }

            // Look for calories
            if result.calories == nil {
                if lower.contains("cal") {
                    if let calMatch = extractPattern(from: text, pattern: #"\d+"#) {
                        result.calories = calMatch
                    }
                }
            }

            // Look for watts
            if result.watts == nil {
                if lower.contains("watt") || lower.contains(" w") {
                    if let wMatch = extractPattern(from: text, pattern: #"\d+"#) {
                        result.watts = wMatch
                    }
                }
            }

            // Look for heart rate
            if result.averageHeartRate == nil {
                if lower.contains("hr") || lower.contains("heart") || lower.contains("bpm") {
                    if let hrMatch = extractPattern(from: text, pattern: #"\d{2,3}"#) {
                        let val = Int(hrMatch) ?? 0
                        if val >= 40 && val <= 220 {
                            result.averageHeartRate = hrMatch
                        }
                    }
                }
            }

            // Look for drag factor
            if result.dragFactor == nil {
                if lower.contains("drag") {
                    if let dfMatch = extractPattern(from: text, pattern: #"\d{2,3}"#) {
                        let val = Int(dfMatch) ?? 0
                        if val >= 80 && val <= 200 {
                            result.dragFactor = dfMatch
                        }
                    }
                }
            }
        }

        // Second pass: look for split-like patterns if not found in context
        if result.split == nil {
            for (text, _) in recognizedText {
                if let splitMatch = extractPattern(from: text, pattern: #"\d:\d{2}\.\d"#) {
                    // Validate it's a reasonable split (1:20 - 3:00)
                    if let seconds = parseMinSecString(splitMatch), seconds >= 80 && seconds <= 180 {
                        result.split = splitMatch
                        break
                    }
                }
            }
        }

        // If we have a time but no distance, look for standalone large numbers
        if result.distance == nil {
            for (text, _) in recognizedText {
                if let distMatch = extractPattern(from: text, pattern: #"\b\d{3,5}\b"#) {
                    let val = Int(distMatch) ?? 0
                    if val >= 100 && val <= 99999 {
                        result.distance = distMatch
                        break
                    }
                }
            }
        }

        return result
    }

    /// Extract first match of a regex pattern from text.
    private func extractPattern(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, range: range) {
            if let matchRange = Range(match.range, in: text) {
                return String(text[matchRange])
            }
        }
        return nil
    }

    private func parseMinSecString(_ str: String) -> Double? {
        let parts = str.split(separator: ":")
        guard parts.count == 2 else { return nil }
        let min = Double(parts[0]) ?? 0
        let sec = Double(parts[1]) ?? 0
        return min * 60 + sec
    }
}
