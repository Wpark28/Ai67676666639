import Foundation
import CoreBluetooth
import Combine

/// Service that connects to Polar H10/H9 heart rate monitors via Bluetooth LE.
/// Supports real-time HR streaming, R-R intervals, and battery level.
final class BluetoothHRService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isScanning = false
    @Published var isConnected = false
    @Published var currentHeartRate: Int = 0
    @Published var currentRRIntervals: [Double] = []
    @Published var batteryLevel: Int?
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectedDeviceName: String?
    @Published var connectionError: String?
    @Published var signalStrength: Int = 0

    // MARK: - BLE UUIDs

    /// Standard Bluetooth Heart Rate Service UUID
    private let heartRateServiceUUID = CBUUID(string: "180D")
    /// Heart Rate Measurement Characteristic
    private let heartRateMeasurementUUID = CBUUID(string: "2A37")
    /// Body Sensor Location Characteristic
    private let bodySensorLocationUUID = CBUUID(string: "2A38")
    /// Battery Service UUID
    private let batteryServiceUUID = CBUUID(string: "180F")
    /// Battery Level Characteristic
    private let batteryLevelUUID = CBUUID(string: "2A19")
    /// Polar-specific PMD (Polar Measurement Data) service for advanced features
    private let polarPMDServiceUUID = CBUUID(string: "FB005C80-02E7-F387-1CAD-8ACD2D8DF0C8")
    /// Polar PMD Control Point
    private let polarPMDControlUUID = CBUUID(string: "FB005C81-02E7-F387-1CAD-8ACD2D8DF0C8")
    /// Polar PMD Data
    private let polarPMDDataUUID = CBUUID(string: "FB005C82-02E7-F387-1CAD-8ACD2D8DF0C8")

    // MARK: - Private Properties

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var heartRateCharacteristic: CBCharacteristic?
    private var cancellables = Set<AnyCancellable>()

    // Session tracking
    private var sessionStartTime: Date?
    private var hrReadings: [Int] = []
    private var hrTimestamps: [Date] = []

    /// Callback for each HR reading during a session
    var onHeartRateReading: ((Int, [Double]) -> Void)?

    // MARK: - Types

    struct DiscoveredDevice: Identifiable, Hashable {
        let id: UUID
        let peripheral: CBPeripheral
        let name: String
        let rssi: Int
        let isPolar: Bool

        static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    // MARK: - Initialization

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Methods

    /// Start scanning for heart rate monitors.
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionError = "Bluetooth is not available. Please enable Bluetooth."
            return
        }

        discoveredDevices.removeAll()
        isScanning = true
        connectionError = nil

        centralManager.scanForPeripherals(
            withServices: [heartRateServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Auto-stop scanning after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if self?.isScanning == true && self?.isConnected == false {
                self?.stopScanning()
            }
        }
    }

    /// Stop scanning for devices.
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    /// Connect to a specific device.
    func connect(to device: DiscoveredDevice) {
        stopScanning()
        connectionError = nil
        centralManager.connect(device.peripheral, options: nil)
    }

    /// Disconnect from the current device.
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        resetState()
    }

    /// Start a heart rate recording session.
    func startSession() {
        sessionStartTime = Date()
        hrReadings.removeAll()
        hrTimestamps.removeAll()
    }

    /// End the current session and return a summary.
    func endSession() -> HeartRateSession? {
        guard !hrReadings.isEmpty else { return nil }

        let session = HeartRateSession()
        session.startTime = sessionStartTime ?? Date()
        session.endTime = Date()
        session.dataPoints = hrReadings
        session.dataTimestamps = hrTimestamps

        if !hrReadings.isEmpty {
            session.averageHR = hrReadings.reduce(0, +) / hrReadings.count
            session.maxHR = hrReadings.max() ?? 0
            session.minHR = hrReadings.min() ?? 0
        }

        hrReadings.removeAll()
        hrTimestamps.removeAll()
        sessionStartTime = nil

        return session
    }

    // MARK: - Private Methods

    private func resetState() {
        isConnected = false
        currentHeartRate = 0
        currentRRIntervals = []
        batteryLevel = nil
        connectedDeviceName = nil
        connectedPeripheral = nil
        heartRateCharacteristic = nil
    }

    /// Parse heart rate measurement data per Bluetooth spec.
    private func parseHeartRate(from data: Data) {
        let bytes = [UInt8](data)
        guard !bytes.isEmpty else { return }

        let flags = bytes[0]
        let is16Bit = (flags & 0x01) != 0
        let hasRRIntervals = (flags & 0x10) != 0

        var heartRate: Int
        var offset: Int

        if is16Bit {
            guard bytes.count >= 3 else { return }
            heartRate = Int(bytes[1]) | (Int(bytes[2]) << 8)
            offset = 3
        } else {
            guard bytes.count >= 2 else { return }
            heartRate = Int(bytes[1])
            offset = 2
        }

        // Skip energy expended if present
        if (flags & 0x08) != 0 {
            offset += 2
        }

        // Parse R-R intervals
        var rrIntervals: [Double] = []
        if hasRRIntervals {
            while offset + 1 < bytes.count {
                let rrRaw = Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
                let rrMs = Double(rrRaw) * 1000.0 / 1024.0
                rrIntervals.append(rrMs)
                offset += 2
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.currentHeartRate = heartRate
            self?.currentRRIntervals = rrIntervals

            // Record to session
            self?.hrReadings.append(heartRate)
            self?.hrTimestamps.append(Date())

            // Notify callback
            self?.onHeartRateReading?(heartRate, rrIntervals)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothHRService: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectionError = nil
        case .poweredOff:
            connectionError = "Bluetooth is turned off."
            resetState()
        case .unauthorized:
            connectionError = "Bluetooth permission not granted."
        case .unsupported:
            connectionError = "This device does not support Bluetooth LE."
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        let isPolar = name.lowercased().contains("polar")

        let device = DiscoveredDevice(
            id: peripheral.identifier,
            peripheral: peripheral,
            name: name,
            rssi: RSSI.intValue,
            isPolar: isPolar
        )

        DispatchQueue.main.async { [weak self] in
            if let index = self?.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                self?.discoveredDevices[index] = device
            } else {
                self?.discoveredDevices.append(device)
            }

            // Sort: Polar devices first, then by signal strength
            self?.discoveredDevices.sort { a, b in
                if a.isPolar != b.isPolar { return a.isPolar }
                return a.rssi > b.rssi
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = true
            self?.connectedDeviceName = peripheral.name ?? "Heart Rate Monitor"
            self?.connectedPeripheral = peripheral
            self?.connectionError = nil
        }

        peripheral.delegate = self
        peripheral.discoverServices([heartRateServiceUUID, batteryServiceUUID, polarPMDServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionError = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
            self?.isConnected = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.resetState()
            if error != nil {
                self?.connectionError = "Disconnected unexpectedly. Attempting reconnect..."
                // Auto-reconnect
                central.connect(peripheral, options: nil)
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothHRService: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == heartRateServiceUUID {
                peripheral.discoverCharacteristics(
                    [heartRateMeasurementUUID, bodySensorLocationUUID],
                    for: service
                )
            } else if service.uuid == batteryServiceUUID {
                peripheral.discoverCharacteristics([batteryLevelUUID], for: service)
            } else if service.uuid == polarPMDServiceUUID {
                peripheral.discoverCharacteristics(
                    [polarPMDControlUUID, polarPMDDataUUID],
                    for: service
                )
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case heartRateMeasurementUUID:
                heartRateCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)

            case bodySensorLocationUUID:
                peripheral.readValue(for: characteristic)

            case batteryLevelUUID:
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)

            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case heartRateMeasurementUUID:
            parseHeartRate(from: data)

        case batteryLevelUUID:
            let bytes = [UInt8](data)
            if let level = bytes.first {
                DispatchQueue.main.async { [weak self] in
                    self?.batteryLevel = Int(level)
                }
            }

        default:
            break
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.signalStrength = RSSI.intValue
        }
    }
}
