import SwiftUI
import PhotosUI
import AVFoundation

/// View for capturing or selecting erg score photos and extracting data via OCR.
struct CameraView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [AthleteProfile]

    @StateObject private var ocrService = ErgOCRService()
    @StateObject private var aiCoach = AICoachService()

    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var capturedImage: UIImage?
    @State private var ocrResult: ErgOCRService.OCRResult?
    @State private var showingManualEntry = false
    @State private var showingResults = false
    @State private var savedScore: ErgScore?

    // Manual adjustment fields
    @State private var editedTime = ""
    @State private var editedDistance = ""
    @State private var editedSplit = ""
    @State private var editedStrokeRate = ""
    @State private var editedWorkoutType = "2k"
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let workoutTypes = ["2k", "5k", "6k", "10k", "500m", "30min", "60min", "interval", "steady_state", "other"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if capturedImage == nil {
                        captureSection
                    } else if ocrService.isProcessing {
                        processingSection
                    } else if let result = ocrResult {
                        resultSection(result)
                    } else {
                        imagePreviewSection
                    }
                }
                .padding()
            }
            .navigationTitle("Capture Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                if capturedImage != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Reset") { resetState() }
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPickerView(image: $capturedImage)
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        capturedImage = image
                        await processImage(image)
                    }
                }
            }
            .onChange(of: capturedImage) { _, newImage in
                if let image = newImage, ocrResult == nil {
                    Task { await processImage(image) }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
        }
    }

    // MARK: - Capture Section

    private var captureSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .padding(.top, 40)

            Text("Capture Your Erg Score")
                .font(.title2.bold())

            Text("Take a photo of your Concept2 monitor or upload one from your library. AI will read the numbers automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }

                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.blue)
                }

                Button {
                    showingManualEntry = true
                } label: {
                    Label("Enter Manually", systemImage: "keyboard")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.top, 16)

            // Tips
            VStack(alignment: .leading, spacing: 8) {
                Text("Tips for best results:")
                    .font(.caption.bold())
                Label("Hold camera steady and fill frame with the monitor", systemImage: "hand.raised.fill")
                    .font(.caption)
                Label("Make sure the screen is clearly lit, no glare", systemImage: "sun.max.fill")
                    .font(.caption)
                Label("Works with Concept2 PM3, PM4, and PM5 monitors", systemImage: "checkmark.circle.fill")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Processing

    private var processingSection: some View {
        VStack(spacing: 20) {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            ProgressView()
                .scaleEffect(1.5)

            Text("Reading your erg score...")
                .font(.headline)

            Text("Using Vision AI to extract numbers from the monitor")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }

    // MARK: - Results

    private func resultSection(_ result: ErgOCRService.OCRResult) -> some View {
        VStack(spacing: 20) {
            // Image preview
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        confidenceBadge(result.confidence)
                            .padding(8)
                    }
            }

            // Extracted data
            VStack(alignment: .leading, spacing: 16) {
                Text("Extracted Data")
                    .font(.headline)

                editableField("Time", value: $editedTime, icon: "clock", placeholder: "6:30.0")
                editableField("Distance", value: $editedDistance, icon: "arrow.left.and.right", placeholder: "2000")
                editableField("Split /500m", value: $editedSplit, icon: "speedometer", placeholder: "1:37.5")
                editableField("Stroke Rate", value: $editedStrokeRate, icon: "metronome", placeholder: "32")

                Picker("Workout Type", selection: $editedWorkoutType) {
                    ForEach(workoutTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Save button
            Button {
                saveScore(from: result)
            } label: {
                Text("Save Score")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }

            if let score = savedScore {
                savedConfirmation(score)
            }
        }
    }

    private var imagePreviewSection: some View {
        VStack(spacing: 20) {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            ProgressView("Processing...")
        }
    }

    // MARK: - Components

    private func editableField(_ label: String, value: Binding<String>, icon: String, placeholder: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            TextField(placeholder, text: value)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 100)
        }
    }

    private func confidenceBadge(_ confidence: Double) -> some View {
        let percent = Int(confidence * 100)
        let color: Color = confidence > 0.8 ? .green : (confidence > 0.5 ? .yellow : .red)

        return Text("\(percent)% confidence")
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.9), in: Capsule())
            .foregroundStyle(.white)
    }

    private func savedConfirmation(_ score: ErgScore) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("Score Saved!")
                .font(.headline)
            Text("\(score.workoutType.uppercased()) - \(score.formattedSplit) /500m")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private func processImage(_ image: UIImage) async {
        let result = await ocrService.processImage(image)
        await MainActor.run {
            ocrResult = result
            if let r = result {
                editedTime = r.time ?? ""
                editedDistance = r.distance ?? ""
                editedSplit = r.split ?? ""
                editedStrokeRate = r.strokeRate ?? ""
            }
        }
    }

    private func saveScore(from result: ErgOCRService.OCRResult) {
        if var score = result.toErgScore() {
            // Apply any manual edits
            if let image = capturedImage {
                score.photoData = image.jpegData(compressionQuality: 0.7)
            }
            score.workoutType = editedWorkoutType

            modelContext.insert(score)

            // Update profile
            if let profile = profiles.first {
                profile.updatePRs(from: score)
                aiCoach.updateFitnessScores(profile: profile, score: score)
            }

            savedScore = score
        }
    }

    private func resetState() {
        capturedImage = nil
        ocrResult = nil
        savedScore = nil
        editedTime = ""
        editedDistance = ""
        editedSplit = ""
        editedStrokeRate = ""
        selectedPhotoItem = nil
    }
}

// MARK: - Camera Picker (UIKit Bridge)

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Manual Entry View

struct ManualEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [AthleteProfile]

    @State private var distance = ""
    @State private var minutes = ""
    @State private var seconds = ""
    @State private var tenths = ""
    @State private var splitMin = ""
    @State private var splitSec = ""
    @State private var splitTenths = ""
    @State private var strokeRate = ""
    @State private var workoutType = "2k"
    @State private var notes = ""

    private let workoutTypes = ["2k", "5k", "6k", "10k", "500m", "30min", "60min", "interval", "steady_state", "other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Type") {
                    Picker("Type", selection: $workoutType) {
                        ForEach(workoutTypes, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }

                Section("Distance") {
                    TextField("Meters", text: $distance)
                        .keyboardType(.numberPad)
                }

                Section("Total Time") {
                    HStack {
                        TextField("Min", text: $minutes)
                            .keyboardType(.numberPad)
                            .frame(width: 50)
                        Text(":")
                        TextField("Sec", text: $seconds)
                            .keyboardType(.numberPad)
                            .frame(width: 50)
                        Text(".")
                        TextField("0", text: $tenths)
                            .keyboardType(.numberPad)
                            .frame(width: 30)
                    }
                }

                Section("Split /500m") {
                    HStack {
                        TextField("Min", text: $splitMin)
                            .keyboardType(.numberPad)
                            .frame(width: 50)
                        Text(":")
                        TextField("Sec", text: $splitSec)
                            .keyboardType(.numberPad)
                            .frame(width: 50)
                        Text(".")
                        TextField("0", text: $splitTenths)
                            .keyboardType(.numberPad)
                            .frame(width: 30)
                    }
                }

                Section("Stroke Rate") {
                    TextField("s/m", text: $strokeRate)
                        .keyboardType(.numberPad)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes)
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveManualEntry() }
                        .bold()
                }
            }
        }
    }

    private func saveManualEntry() {
        let dist = Int(distance) ?? 0
        let timeTotal = (Double(minutes) ?? 0) * 60 + (Double(seconds) ?? 0) + (Double(tenths) ?? 0) / 10.0
        let splitTotal = (Double(splitMin) ?? 0) * 60 + (Double(splitSec) ?? 0) + (Double(splitTenths) ?? 0) / 10.0
        let sr = Int(strokeRate) ?? 0

        let score = ErgScore(
            distanceMeters: dist,
            timeSeconds: timeTotal,
            splitSeconds: splitTotal,
            strokeRate: sr,
            averageWatts: ErgScore.wattsFromSplit(splitTotal),
            workoutType: workoutType,
            capturedFromPhoto: false
        )
        score.notes = notes.isEmpty ? nil : notes

        modelContext.insert(score)

        if let profile = profiles.first {
            profile.updatePRs(from: score)
        }

        dismiss()
    }
}
