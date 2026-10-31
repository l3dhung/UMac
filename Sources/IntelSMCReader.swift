import Foundation
import IOKit

// MARK: - Intel SMC Reader (chỉ đọc, không cần root)

/// Đọc cảm biến trên Mac Intel qua user client của AppleSMC: nhiệt độ (T***),
/// quạt (F*Ac/Mn/Mx) và công suất (P***). Chỉ dùng lệnh ĐỌC — không bao giờ ghi SMC.
///
/// Mac Intel không có cảm biến nhiệt qua IOHID như Apple Silicon, nên ThermalManager
/// dùng lớp này khi nền tảng là Intel.
final class IntelSMCReader {
    struct Fan: Identifiable, Equatable {
        var id: Int { index }
        let index: Int
        let rpm: Double
        let minRPM: Double
        let maxRPM: Double
    }

    struct Power: Identifiable, Equatable {
        var id: String { key }
        let key: String
        let name: String
        let watts: Double
    }

    struct Snapshot {
        var temperatures: [SensorReading] = []
        var fans: [Fan] = []
        var power: [Power] = []
    }

    // Bố cục khớp SMCKeyData_t của AppleSMC (80 byte); khai báo phẳng có padding
    // tường minh vì Swift không bảo đảm padding của struct lồng nhau giống C.
    private struct SMCParam {
        var key: UInt32 = 0
        var versMajor: UInt8 = 0, versMinor: UInt8 = 0, versBuild: UInt8 = 0, versReserved: UInt8 = 0
        var versRelease: UInt16 = 0
        var pad0: UInt16 = 0
        var pLimitVersion: UInt16 = 0
        var pLimitLength: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
        var pad1: UInt8 = 0, pad2: UInt8 = 0, pad3: UInt8 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var pad4: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    private struct KeyInfo {
        let size: UInt32
        let type: String
    }

    private static let kSMCHandleYPCEvent: UInt32 = 2
    private static let kSMCReadKey: UInt8 = 5
    private static let kSMCGetKeyFromIndex: UInt8 = 8
    private static let kSMCGetKeyInfo: UInt8 = 9

    /// Tên tiếng Việt cho các khóa nhiệt phổ biến trên MacBook/iMac/Mac mini Intel.
    private static let temperatureLabels: [String: String] = [
        "TC0P": "CPU (gần đế)", "TC0D": "CPU Die", "TC0E": "CPU (PECI)", "TC0F": "CPU (PECI 2)",
        "TC0H": "CPU Heatsink", "TCXC": "CPU PECI", "TCSA": "CPU System Agent", "TCGC": "GPU tích hợp Intel",
        "TG0P": "GPU (gần đế)", "TG0D": "GPU Die", "TG1D": "GPU Die 2", "TG0H": "GPU Heatsink",
        "TB0T": "Pin", "TB1T": "Pin cell 1", "TB2T": "Pin cell 2", "TB3T": "Pin cell 3",
        "TH0P": "SSD (gần)", "TH0a": "SSD NAND A", "TH0b": "SSD NAND B", "TH0x": "SSD",
        "TM0P": "RAM (gần)", "TM0S": "Khe RAM", "TPCD": "Chip PCH", "TPCP": "PCH (gần)",
        "Ts0P": "Kê tay trái", "Ts1P": "Kê tay phải", "Ts0S": "Vỏ máy", "TA0P": "Không khí vào",
        "TW0P": "Wi-Fi", "TI0P": "Thunderbolt", "TTLD": "Thunderbolt trái", "TTRD": "Thunderbolt phải",
        "Tm0P": "Bo mạch chính", "TN0D": "Northbridge", "Th1H": "Ống dẫn nhiệt", "TaLC": "Luồng gió trái",
        "TaRC": "Luồng gió phải", "TL0P": "Màn hình", "TS0C": "Bộ nguồn", "TA0V": "Không khí môi trường",
        "TH0F": "SSD (bộ điều khiển)", "TH0X": "SSD (tổng)", "Th2H": "Ống dẫn nhiệt 2",
        "Ts1S": "Vỏ máy 2", "Ts2S": "Vỏ máy 3",
    ]

    private static let powerLabels: [String: String] = [
        "PSTR": "Toàn hệ thống", "PCPT": "Gói CPU", "PCPC": "Nhân CPU", "PCPG": "GPU tích hợp",
        "PC0C": "Nhân CPU", "PCTR": "CPU tổng", "PG0R": "GPU rời", "PDTR": "Nguồn vào (DC)",
        "PBLC": "Pin", "PM0R": "RAM", "PPBR": "Pin (xả)",
    ]

    private var connection: io_connect_t = 0
    private var infoCache: [UInt32: KeyInfo] = [:]
    private var temperatureKeys: [String] = []
    private var powerKeys: [String] = []
    private var fanCount = 0
    private var hasDiscovered = false

    init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        if IOServiceOpen(service, mach_task_self_, 0, &connection) != kIOReturnSuccess {
            connection = 0
        }
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    var isAvailable: Bool { connection != 0 && MemoryLayout<SMCParam>.size == 80 }

    func read() -> Snapshot {
        guard isAvailable else { return Snapshot() }
        if !hasDiscovered { discoverKeys() }

        var snapshot = Snapshot()

        for key in temperatureKeys {
            guard let value = readNumber(key), value > 10, value < 125 else { continue }
            snapshot.temperatures.append(SensorReading(
                name: key,
                displayName: Self.temperatureLabel(for: key),
                temp: value,
                category: Self.category(for: key)
            ))
        }

        for i in 0..<fanCount {
            guard let rpm = readNumber("F\(i)Ac") else { continue }
            snapshot.fans.append(Fan(
                index: i,
                rpm: rpm,
                minRPM: readNumber("F\(i)Mn") ?? 0,
                maxRPM: readNumber("F\(i)Mx") ?? 0
            ))
        }

        for key in powerKeys {
            guard let watts = readNumber(key), watts > 0.05, watts < 500 else { continue }
            snapshot.power.append(Power(key: key, name: Self.powerLabels[key] ?? key, watts: watts))
        }
        return snapshot
    }

    // MARK: - Discovery

    /// Duyệt toàn bộ khóa SMC một lần để tìm mọi cảm biến nhiệt/công suất mà máy này có.
    private func discoverKeys() {
        hasDiscovered = true
        fanCount = Int(readNumber("FNum") ?? 0)

        guard let total = readNumber("#KEY"), total > 0, total < 10_000 else { return }
        var temps: [String] = []
        var powers: [String] = []

        for index in 0..<UInt32(total) {
            var input = SMCParam()
            input.data8 = Self.kSMCGetKeyFromIndex
            input.data32 = index
            guard let output = call(&input) else { continue }
            let key = Self.string(from: output.key)
            if key.hasPrefix("T") {
                temps.append(key)
            } else if Self.powerLabels[key] != nil {
                powers.append(key)
            }
        }

        // Chỉ giữ khóa có kiểu số và đang trả về giá trị hợp lệ.
        temperatureKeys = temps.filter { key in
            guard let v = readNumber(key) else { return false }
            return v > 10 && v < 125
        }
        powerKeys = powers.filter { readNumber($0) != nil }
        appLog("🌡 IntelSMCReader: \(Int(total)) khóa SMC, \(temperatureKeys.count) cảm biến nhiệt, \(fanCount) quạt, \(powerKeys.count) khóa công suất")
    }

    // MARK: - Low-level

    private func call(_ input: inout SMCParam) -> SMCParam? {
        var output = SMCParam()
        var outputSize = MemoryLayout<SMCParam>.size
        let result = IOConnectCallStructMethod(connection, Self.kSMCHandleYPCEvent,
                                               &input, MemoryLayout<SMCParam>.size,
                                               &output, &outputSize)
        guard result == kIOReturnSuccess, output.result == 0 else { return nil }
        return output
    }

    private func keyInfo(_ key: UInt32) -> KeyInfo? {
        if let cached = infoCache[key] { return cached }
        var input = SMCParam()
        input.key = key
        input.data8 = Self.kSMCGetKeyInfo
        guard let output = call(&input) else { return nil }
        let info = KeyInfo(size: output.dataSize, type: Self.string(from: output.dataType))
        infoCache[key] = info
        return info
    }

    private func readNumber(_ name: String) -> Double? {
        let key = Self.fourCC(name)
        guard let info = keyInfo(key), info.size > 0, info.size <= 32 else { return nil }
        var input = SMCParam()
        input.key = key
        input.dataSize = info.size
        input.data8 = Self.kSMCReadKey
        guard let output = call(&input) else { return nil }
        let bytes = withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(info.size))) }
        return Self.decode(bytes, type: info.type)
    }

    private static func decode(_ b: [UInt8], type: String) -> Double? {
        func u16() -> UInt16 { UInt16(b[0]) << 8 | UInt16(b[1]) }
        switch type {
        case "sp78" where b.count >= 2: return Double(Int16(bitPattern: u16())) / 256
        case "sp87" where b.count >= 2: return Double(Int16(bitPattern: u16())) / 128
        case "sp96" where b.count >= 2: return Double(Int16(bitPattern: u16())) / 64
        case "sp5a" where b.count >= 2: return Double(Int16(bitPattern: u16())) / 1024
        case "fpe2" where b.count >= 2: return Double(u16()) / 4
        case "fp88" where b.count >= 2: return Double(u16()) / 256
        case "ui8 " where b.count >= 1: return Double(b[0])
        case "ui16" where b.count >= 2: return Double(u16())
        case "ui32" where b.count >= 4:
            return Double(UInt32(b[0]) << 24 | UInt32(b[1]) << 16 | UInt32(b[2]) << 8 | UInt32(b[3]))
        case "flt " where b.count >= 4:
            // Trên Intel, kiểu flt lưu theo thứ tự byte của máy (little-endian).
            let bits = UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
            let value = Double(Float(bitPattern: bits))
            return value.isFinite ? value : nil
        default:
            return nil
        }
    }

    private static func fourCC(_ s: String) -> UInt32 {
        s.utf8.prefix(4).reduce(0) { $0 << 8 | UInt32($1) }
    }

    private static func string(from code: UInt32) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> UInt32($0)) & 0xFF) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func temperatureLabel(for key: String) -> String {
        if let label = temperatureLabels[key] { return label }
        // TC1C…TC9C: nhiệt từng nhân CPU.
        if key.count == 4, key.hasPrefix("TC"), key.hasSuffix("C"),
           let n = Int(String(key[key.index(key.startIndex, offsetBy: 2)])), n > 0 {
            return "CPU nhân \(n)"
        }
        return "Cảm biến \(key)"
    }

    private static func category(for key: String) -> String {
        if key == "TCGC" { return "GPU" }
        switch key.prefix(2) {
        case "TC": return "CPU"
        case "TG": return "GPU"
        case "TB": return "Pin"
        case "TH": return "Ổ cứng"
        case "TM": return "RAM"
        case "Ts": return "Vỏ máy"
        default: return "Bo mạch"
        }
    }
}
