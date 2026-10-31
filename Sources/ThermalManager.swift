import Foundation
import IOKit
import AppKit

// MARK: - Sensor Model

public struct SensorReading: Identifiable, Equatable {
    public var id: String { name }
    public let name: String
    public let displayName: String
    public let temp: Double
    public let category: String
}

// MARK: - Hardware Platform

/// Nguồn dữ liệu cảm biến: Apple Silicon (IOHID/PMU) hoặc Intel (SMC).
public enum HardwarePlatform: String, CaseIterable {
    case appleSilicon
    case intel

    /// Nhận diện phần cứng thật (đúng cả khi app chạy qua Rosetta).
    public static let detected: HardwarePlatform = {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let isArm = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
        return isArm ? .appleSilicon : .intel
    }()

    public var displayName: String {
        switch self {
        case .appleSilicon: return "Apple Silicon"
        case .intel: return "Intel"
        }
    }
}

/// Lựa chọn của người dùng: tự nhận diện hoặc ép một nền tảng.
public enum PlatformPreference: String, CaseIterable {
    case auto
    case appleSilicon
    case intel

    public var platform: HardwarePlatform {
        switch self {
        case .auto: return HardwarePlatform.detected
        case .appleSilicon: return .appleSilicon
        case .intel: return .intel
        }
    }
}

// MARK: - Native Apple Silicon IOHID Temperature Reader

private typealias ClientRef = OpaquePointer
private typealias ServiceRef = OpaquePointer
private typealias EventRef = OpaquePointer

private typealias FnCreateWithType = @convention(c) (CFAllocator?, UInt32, CFDictionary?) -> ClientRef?
private typealias FnCopyServices = @convention(c) (ClientRef) -> CFArray?
private typealias FnCopyProperty = @convention(c) (ServiceRef, CFString) -> CFTypeRef?
private typealias FnCopyEvent = @convention(c) (ServiceRef, Int64, Int32, Int64) -> EventRef?
private typealias FnGetFloat = @convention(c) (EventRef, UInt32) -> Double

private class AppleSiliconHIDReader {
    private var client: ClientRef?
    private var cachedServices: [ServiceRef] = []
    private var lastDiscoveryTime: TimeInterval = 0

    private var fnCreate: FnCreateWithType?
    private var fnCopyServices: FnCopyServices?
    private var fnCopyProperty: FnCopyProperty?
    private var fnCopyEvent: FnCopyEvent?
    private var fnGetFloat: FnGetFloat?

    init() {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else { return }
        if let s = dlsym(handle, "IOHIDEventSystemClientCreateWithType") { fnCreate = unsafeBitCast(s, to: FnCreateWithType.self) }
        if let s = dlsym(handle, "IOHIDEventSystemClientCopyServices") { fnCopyServices = unsafeBitCast(s, to: FnCopyServices.self) }
        if let s = dlsym(handle, "IOHIDServiceClientCopyProperty") { fnCopyProperty = unsafeBitCast(s, to: FnCopyProperty.self) }
        if let s = dlsym(handle, "IOHIDServiceClientCopyEvent") { fnCopyEvent = unsafeBitCast(s, to: FnCopyEvent.self) }
        if let s = dlsym(handle, "IOHIDEventGetFloatValue") { fnGetFloat = unsafeBitCast(s, to: FnGetFloat.self) }
    }

    func readTemperatures() -> (cpuAvg: Double, cpuPeak: Double, gpuAvg: Double, battery: Double, nand: Double, hotspot: Double, sensors: [SensorReading]) {
        guard let create = fnCreate, let copyServ = fnCopyServices, let copyProp = fnCopyProperty,
              let copyEvt = fnCopyEvent, let getFloat = fnGetFloat else {
            return (0, 0, 0, 0, 0, 0, [])
        }

        let now = ProcessInfo.processInfo.systemUptime
        if client == nil {
            client = create(kCFAllocatorDefault, 1, nil)
        }
        guard let c = client else { return (0, 0, 0, 0, 0, 0, []) }

        // Refresh services every 60s
        if cachedServices.isEmpty || (now - lastDiscoveryTime > 60) {
            cachedServices.removeAll(keepingCapacity: true)
            if let servCF = copyServ(c) {
                let count = CFArrayGetCount(servCF)
                for i in 0..<count {
                    let s = unsafeBitCast(CFArrayGetValueAtIndex(servCF, i), to: ServiceRef.self)
                    cachedServices.append(s)
                }
            }
            lastDiscoveryTime = now
        }

        var cpuTemps: [Double] = []
        var gpuTemps: [Double] = []
        var batteryTemps: [Double] = []
        var nandTemps: [Double] = []
        var hotspotTemps: [Double] = []
        var sensorList: [SensorReading] = []

        let kIOHIDEventTypeTemperature: Int64 = 15
        let kIOHIDEventFieldTemperatureValue: UInt32 = (15 << 16) | 0

        for s in cachedServices {
            guard let pRef = copyProp(s, "Product" as CFString),
                  let name = pRef as? String else { continue }

            guard let evt = copyEvt(s, kIOHIDEventTypeTemperature, 0, 0) else { continue }
            let temp = getFloat(evt, kIOHIDEventFieldTemperatureValue)
            guard temp > 15.0 && temp < 125.0 else { continue }

            if name.hasPrefix("PMU tdie") || name.hasPrefix("PMU2 tdie") {
                cpuTemps.append(temp)
                let coreIdx = name.replacingOccurrences(of: "PMU tdie", with: "").replacingOccurrences(of: "PMU2 tdie", with: " (P-Core ")
                let label = name.contains("PMU2") ? "CPU P-Core \(coreIdx.replacingOccurrences(of: " (P-Core ", with: ""))" : "CPU Core \(coreIdx)"
                sensorList.append(SensorReading(name: name, displayName: label, temp: temp, category: "CPU"))
            } else if name.hasPrefix("PMU tdev") || name.hasPrefix("PMU2 tdev") {
                gpuTemps.append(temp)
                let gpuIdx = name.replacingOccurrences(of: "PMU tdev", with: "").replacingOccurrences(of: "PMU2 tdev", with: " Cụm ")
                sensorList.append(SensorReading(name: name, displayName: "GPU Cụm \(gpuIdx)", temp: temp, category: "GPU"))
            } else if name.contains("battery") {
                batteryTemps.append(temp)
                sensorList.append(SensorReading(name: name, displayName: "Pin Cell (Gas Gauge)", temp: temp, category: "Pin"))
            } else if name.contains("NAND") {
                nandTemps.append(temp)
                sensorList.append(SensorReading(name: name, displayName: "SSD NVMe Flash", temp: temp, category: "Ổ cứng"))
            } else if name.contains("tcal") {
                hotspotTemps.append(temp)
                sensorList.append(SensorReading(name: name, displayName: "Hotspot Bo mạch", temp: temp, category: "Bo mạch"))
            }
        }

        let cpuAvg = cpuTemps.isEmpty ? 0.0 : (cpuTemps.reduce(0, +) / Double(cpuTemps.count))
        let cpuPeak = cpuTemps.max() ?? 0.0
        let gpuAvg = gpuTemps.isEmpty ? 0.0 : (gpuTemps.reduce(0, +) / Double(gpuTemps.count))
        let bat = batteryTemps.isEmpty ? 0.0 : (batteryTemps.reduce(0, +) / Double(batteryTemps.count))
        let nand = nandTemps.isEmpty ? 0.0 : (nandTemps.reduce(0, +) / Double(nandTemps.count))
        let hot = hotspotTemps.isEmpty ? 0.0 : (hotspotTemps.reduce(0, +) / Double(hotspotTemps.count))

        return (cpuAvg, cpuPeak, gpuAvg, bat, nand, hot, sensorList)
    }

    deinit {
        cachedServices.removeAll()
    }
}

// MARK: - Thermal Manager Engine (Temperature Monitoring Only)

/// Reads Apple Silicon HID/PMU temperature sensors and exposes them to the UI.
///
/// NOTE: Fan control was intentionally removed in v1.5.2. HyperMac no longer
/// writes SMC fan keys or installs a privileged helper for fan speed changes.
@MainActor
public class ThermalManager: ObservableObject {
    public static let shared = ThermalManager()

    @Published public var machineModelName: String = "Mac"

    // Real-Time Temperatures (°C)
    @Published public var cpuAvgTemp: Double = 0.0
    @Published public var cpuPeakTemp: Double = 0.0
    @Published public var gpuAvgTemp: Double = 0.0
    @Published public var batteryTemp: Double = 0.0
    @Published public var ssdTemp: Double = 0.0
    @Published public var hotspotTemp: Double = 0.0

    // Detailed Sensor Breakdown
    @Published public var detailedSensors: [SensorReading] = []

    // Intel SMC: quạt & công suất (Apple Silicon để trống)
    @Published var fans: [IntelSMCReader.Fan] = []
    @Published var powerReadings: [IntelSMCReader.Power] = []

    /// Tự nhận diện chip hoặc ép nền tảng — dùng khi cài trên máy khác hoặc nhận diện sai.
    @Published public var platformPreference: PlatformPreference = PlatformPreference(
        rawValue: UserDefaults.standard.string(forKey: "hardware_platform") ?? ""
    ) ?? .auto {
        didSet {
            UserDefaults.standard.set(platformPreference.rawValue, forKey: "hardware_platform")
            resetReadings()
            refreshMetrics()
        }
    }

    public var platform: HardwarePlatform { platformPreference.platform }
    @Published public var isDetailExpanded: Bool = false

    // UI View State (Stored here to prevent CommandLineTools SwiftUIMacros @State crash)
    @Published public var selectedSection: Int = 0 // 0: Pin & Nguồn SMC, 1: Nhiệt độ & Cảm biến
    @Published public var isRefreshing: Bool = false

    // Thermal Throttling & Status
    @Published public var thermalStateDescription: String = "Mát mẻ (Bình thường)"
    @Published public var isThrottling: Bool = false

    // Menu Bar live temperature pill
    @Published public var showMenuBarMetrics: Bool = UserDefaults.standard.bool(forKey: "show_menubar_thermal") {
        didSet {
            UserDefaults.standard.set(showMenuBarMetrics, forKey: "show_menubar_thermal")
            updateMenuBarDisplay()
        }
    }
    public var onMenuBarUpdate: ((String?) -> Void)?

    private lazy var hidReader = AppleSiliconHIDReader()
    private lazy var smcReader = IntelSMCReader()
    /// Lần đọc SMC đầu tiên phải duyệt ~1000 khóa (~0.3s) → chạy nền, không chặn UI.
    private let smcQueue = DispatchQueue(label: "hypermac.smc", qos: .utility)
    private var isSMCReadInFlight = false
    private var pollTimer: Timer?

    private init() {
        loadMachineHardwareInfo()
        refreshMetrics()
        startPolling()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    private func loadMachineHardwareInfo() {
        var size: size_t = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelString = String(cString: model)
        let modelLower = modelString.lowercased()

        if modelLower.contains("air") ||
            modelString.hasPrefix("Mac14,2") ||
            modelString.hasPrefix("Mac14,15") ||
            modelString.hasPrefix("Mac15,12") ||
            modelString.hasPrefix("Mac15,13") {
            self.machineModelName = "MacBook Air"
        } else if modelString.hasPrefix("MacBook8,") ||
                    modelString.hasPrefix("MacBook9,") ||
                    modelString.hasPrefix("MacBook10,") {
            self.machineModelName = "MacBook (12-inch)"
        } else if modelLower.contains("mini") || modelString == "Mac14,3" || modelString == "Mac14,12" ||
                    modelString.hasPrefix("Mac16,10") || modelString.hasPrefix("Mac16,11") || modelString.hasPrefix("Mac16,15") {
            self.machineModelName = "Mac mini"
        } else if modelLower.contains("studio") || modelString.hasPrefix("Mac13,") ||
                    modelString == "Mac14,13" || modelString == "Mac14,14" {
            self.machineModelName = "Mac Studio"
        } else if modelLower.contains("imac") || modelString == "Mac15,4" || modelString == "Mac15,5" ||
                    modelString == "Mac16,2" || modelString == "Mac16,3" {
            self.machineModelName = "iMac"
        } else if modelLower.contains("pro") ||
                    modelString.hasPrefix("MacBookPro") ||
                    modelString.hasPrefix("Mac14,5") || modelString.hasPrefix("Mac14,6") ||
                    modelString.hasPrefix("Mac14,7") || modelString.hasPrefix("Mac14,9") ||
                    modelString.hasPrefix("Mac14,10") || modelString.hasPrefix("Mac15,") ||
                    modelString.hasPrefix("Mac16,") {
            self.machineModelName = "MacBook Pro"
        } else {
            self.machineModelName = modelString.isEmpty ? "Mac" : modelString
        }
    }

    // MARK: - Polling & Refresh Metrics

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshMetrics()
            }
        }
    }

    public func refreshMetrics() {
        // 1. Read temperatures (Apple Silicon HID hoặc Intel SMC)
        if platform == .intel {
            refreshIntelSMC()
        } else {
            let (cpu, peak, gpu, bat, nand, hot, sensors) = hidReader.readTemperatures()
            if cpu > 0 { self.cpuAvgTemp = cpu }
            if peak > 0 { self.cpuPeakTemp = peak }
            if gpu > 0 { self.gpuAvgTemp = gpu }
            if bat > 0 { self.batteryTemp = bat }
            if nand > 0 { self.ssdTemp = nand }
            if hot > 0 { self.hotspotTemp = hot }
            if !sensors.isEmpty { self.detailedSensors = sensors }
        }

        // 2. Read System Thermal Pressure
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal:
            self.thermalStateDescription = "Mát mẻ (Bình thường)"
            self.isThrottling = false
        case .fair:
            self.thermalStateDescription = "Ấm nhẹ (Tải vừa)"
            self.isThrottling = false
        case .serious:
            self.thermalStateDescription = "Nóng (Đang giảm xung nhẹ)"
            self.isThrottling = true
        case .critical:
            self.thermalStateDescription = "Rất nóng (Thermal Throttling tối đa!)"
            self.isThrottling = true
        @unknown default:
            self.thermalStateDescription = "Bình thường"
            self.isThrottling = false
        }

        // 3. Update Menu Bar Live Telemetry
        updateMenuBarDisplay()
    }

    @objc private func thermalStateChanged() {
        refreshMetrics()
    }

    private func resetReadings() {
        cpuAvgTemp = 0
        cpuPeakTemp = 0
        gpuAvgTemp = 0
        batteryTemp = 0
        ssdTemp = 0
        hotspotTemp = 0
        detailedSensors = []
        fans = []
        powerReadings = []
    }

    private func refreshIntelSMC() {
        guard !isSMCReadInFlight else { return }
        isSMCReadInFlight = true
        let reader = smcReader

        smcQueue.async { [weak self] in
            let snapshot = reader.read()
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSMCReadInFlight = false
                guard self.platform == .intel else { return }
                self.applyIntelSnapshot(snapshot)
                self.updateMenuBarDisplay()
            }
        }
    }

    private func applyIntelSnapshot(_ snapshot: IntelSMCReader.Snapshot) {
        let temps = snapshot.temperatures
        func value(_ key: String) -> Double? { temps.first { $0.name == key }?.temp }
        func average(_ values: [Double]) -> Double { values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }

        // TC1C…TC9C = từng nhân; máy cũ chỉ có TC0P/TC0D/TCXC.
        let cores = temps.filter { $0.name.count == 4 && $0.name.hasPrefix("TC") && $0.name.hasSuffix("C")
            && $0.name != "TCGC" && $0.name != "TCXC" && $0.name != "TC0C" }.map(\.temp)
        let dies = ["TC0D", "TCXC", "TC0F", "TC0E", "TC0P"].compactMap(value)

        cpuAvgTemp = cores.isEmpty ? (dies.first ?? 0) : average(cores)
        cpuPeakTemp = (cores + dies).max() ?? 0
        gpuAvgTemp = value("TG0D") ?? value("TG0P") ?? value("TCGC") ?? 0
        batteryTemp = value("TB0T") ?? average(temps.filter { $0.category == "Pin" }.map(\.temp))
        ssdTemp = temps.filter { $0.category == "Ổ cứng" }.map(\.temp).max() ?? 0
        hotspotTemp = value("TPCD") ?? temps.filter { $0.category == "Bo mạch" }.map(\.temp).max() ?? 0

        let order = ["CPU", "GPU", "RAM", "Ổ cứng", "Pin", "Bo mạch", "Vỏ máy"]
        detailedSensors = temps.sorted {
            let a = order.firstIndex(of: $0.category) ?? order.count
            let b = order.firstIndex(of: $1.category) ?? order.count
            return a != b ? a < b : $0.name < $1.name
        }
        fans = snapshot.fans
        powerReadings = snapshot.power.sorted { $0.watts > $1.watts }
    }

    public func updateMenuBarDisplay() {
        guard showMenuBarMetrics else {
            onMenuBarUpdate?(nil)
            return
        }
        let temp = cpuAvgTemp > 0 ? Int(cpuAvgTemp) : (cpuPeakTemp > 0 ? Int(cpuPeakTemp) : 0)
        guard temp > 0 else {
            onMenuBarUpdate?(nil)
            return
        }
        onMenuBarUpdate?("\(temp)°C")
    }
}
