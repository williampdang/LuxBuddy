// https://quickbirdstudios.com/blog/read-ble-characteristics-swift/
// https://gist.github.com/paulw11/d158484fd6540c7c687807b8b3e90b5b
// https://alimovlex.medium.com/mastering-the-fundamentals-of-ble-in-ios-with-swift-73a43ffe44dc

// TODO: RENAME VARIABLES
// TODO: REMOVE MINUTE COUNTERS

import CoreBluetooth

// Variables to store the characteristics and service UUIDs used for this project
let writeableCharacteristic = CBUUID(string: "f39b1499-4813-4bbf-959a-1190a4bf7bff")
let readableCharacteristic = CBUUID(string: "bbdb69d3-f9b5-4a22-b032-ee6140c6c438")
let service = CBUUID(string: "331f07e0-452a-4f2c-9ee9-5e177516e5ea")

// Class for BLE Manager, also handles the logic of experience point calculations!
class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var locationManager: LocationManager
    
    // Used to determine if BLE is scanning for LuxBuddy
    @Published var isScanning = false
    
    // Used to track Lux Values coming in from M5Stick
    @Published var luxValue: String = "N/A"
    
    // Used to track if LuxBuddy has been discovered
    @Published var isLuxBuddyDiscovered = false
    
    // Used to track if the user is getting lux during the time period
    @Published var isTimeMultiplierActive: Bool = false
    
    // Used to track if the user is getting lux if they're outside
    @Published var isGPSMultiplierActive: Bool = false
    
    // Not used,
    //@Published var minutesOutside: Int = 0
    //@Published var minutesInTimeRange: Int = 0
    //@Published var minutesInMorningOutside: Int = 0
    //@Published var lastSentValue: String = "N/A"
    
    // Tracks lux minutes while outside and makes it persistent
    @Published var totalLuxMinutesOutside: Int = 0
    private let totalLuxMinutesOutsideKey = "TotalLuxMinutesOutside"
    
    // Tracks lux minutes while in the morning and makes it persistent
    @Published var totalLuxMinutesInTimeRange: Int = 0
    private let totalLuxMinutesInTimeRangeKey = "TotalLuxMinutesInTimeRange"
    
    // Tracks lux minutes while in the morning an outside and makes it persistent
    @Published var totalLuxMinutesOutsideMorning: Int = 0
    private let totalLuxMinutesOutsideMorningKey = "TotalLuxMinutesOutsideMorning"
    
    // Tracks the total lux minutes and makes it persistent
    @Published var totalLuxMinutes: Int = 0
    private let totalLuxMinutesKey = "TotalLuxMinutes"
    
    // Tracks if lux buddy is connected
    @Published var luxBuddyIsConnected = false

    // This is LuxBuddy! (M5Stick)
    var luxBuddy: CBPeripheral?
    

    
    // Used for developer mode and testing
    @Published var experiencePoints: Int = 0
    let outdoorMultiplier = 1.5
    let morningMultiplier = 2.0
    let baseXPRate = 1 // Base XP per lux value
    
    // Load lux data
    private var luxTimer: Timer?
    private let luxDataKey = "LuxData"
    private let experiencePointsKey = "ExperiencePoints"
    
    // Init the location manager which is used to track if you're outside or instde
    init(locationManager: LocationManager) {
            self.locationManager = locationManager
        
            // Create
            super.init()
            self.centralManager = CBCentralManager(delegate: self, queue: nil)
        
            // Load the saved experience points
            self.experiencePoints = UserDefaults.standard.integer(forKey: experiencePointsKey)
            
            // Load the total lux minutes when initializing
            loadTotalLuxMinutes()
    }
    
    

    // start scanning for luxbuddy
    func startScanning() {
        isLuxBuddyDiscovered = false
        luxBuddy = nil
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    // stop scanning for luxbuddy
    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }

    // Once luxbuddy is discovered and connected stop scaning
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            isLuxBuddyDiscovered = false
            stopScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == "LuxBuddy" {
            isLuxBuddyDiscovered = true
            luxBuddy = peripheral
        }
    }

    func connectToDevice() {
        if let luxBuddyDevice = luxBuddy {
            centralManager.connect(luxBuddyDevice, options: nil)
        }
    }

    // Function used to update lux values
    func updateLuxData() {
        guard let currentLuxMinutes = Int(luxValue) else { return }
        // Values to update general lux minutes
        totalLuxMinutes += currentLuxMinutes
        UserDefaults.standard.set(totalLuxMinutes, forKey: totalLuxMinutesKey)

        // Update lux minutes for being outside
        if locationManager.isActuallyOutside {
            totalLuxMinutesOutside += currentLuxMinutes
            UserDefaults.standard.set(totalLuxMinutesOutside, forKey: totalLuxMinutesOutsideKey)
        }

        // Update lux minutes for being in the specified time range
        if isInMorningHours() {
            totalLuxMinutesInTimeRange += currentLuxMinutes
            UserDefaults.standard.set(totalLuxMinutesInTimeRange, forKey: totalLuxMinutesInTimeRangeKey)
        }
        
        // Update lux minutes for being in the morning and GPS
        if locationManager.isActuallyOutside && isInMorningHours() {
            totalLuxMinutesOutsideMorning += currentLuxMinutes
            UserDefaults.standard.set(totalLuxMinutesOutsideMorning, forKey: totalLuxMinutesOutsideMorningKey)
        }
    }
    
    // Load lux minutes from defaults
    func loadTotalLuxMinutes() {
        totalLuxMinutes = UserDefaults.standard.integer(forKey: totalLuxMinutesKey)
        totalLuxMinutesOutside = UserDefaults.standard.integer(forKey: totalLuxMinutesOutsideKey)
        totalLuxMinutesInTimeRange = UserDefaults.standard.integer(forKey: totalLuxMinutesInTimeRangeKey)
        totalLuxMinutesOutsideMorning = UserDefaults.standard.integer(forKey: totalLuxMinutesOutsideMorningKey)
    }

    // Save lux minutes to defaults
    func saveLuxData() {
            UserDefaults.standard.set(totalLuxMinutes, forKey: totalLuxMinutesKey)
        }
    
    // Developer stuff experience points for tomagatchi upgrade
    func saveExperiencePoints() {
        UserDefaults.standard.set(experiencePoints, forKey: experiencePointsKey)
    }
    
    

    // Used for tracking that app connected to the peripheral device
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stopScanning()
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID(string: "331f07e0-452a-4f2c-9ee9-5e177516e5ea")])
        luxBuddyIsConnected = true
    }

    // Track if the app found the readable charactersitcs
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([CBUUID(string: "bbdb69d3-f9b5-4a22-b032-ee6140c6c438")], for: service)
            
            
//            peripheral.discoverCharacteristics([writeableCharacteristic], for: service)
        }
    }

    // Look for BLE characteristic and connect
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == CBUUID(string: "bbdb69d3-f9b5-4a22-b032-ee6140c6c438") {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }


    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if peripheral == luxBuddy {
            isLuxBuddyDiscovered = false
            luxBuddy = nil
            luxBuddyIsConnected = false


            // Update the UI or handle error if needed
            if let error = error {
                print("Disconnected from LuxBuddy with error: \(error.localizedDescription)")
            } else {
                print("Disconnected from LuxBuddy")
            }
        }
    }
    

        func resetLuxData() {
            UserDefaults.standard.removeObject(forKey: luxDataKey)
            UserDefaults.standard.removeObject(forKey: totalLuxMinutesOutsideKey)
            UserDefaults.standard.removeObject(forKey: totalLuxMinutesInTimeRangeKey)
            UserDefaults.standard.removeObject(forKey: totalLuxMinutesOutsideMorningKey)
            
            // Reset relevant properties
            luxValue = "N/A"
            totalLuxMinutes = 0
            totalLuxMinutesOutside = 0
            totalLuxMinutesInTimeRange = 0
            totalLuxMinutesOutsideMorning = 0
            experiencePoints = 0
            saveExperiencePoints()
        }
    
    func updateExperiencePoints(with locationManager: LocationManager) {
          guard let currentLuxValue = Int(luxValue) else { return }

          // Reset multipliers
          isTimeMultiplierActive = false
          isGPSMultiplierActive = false

          var multiplier = 1.0
        
        // Time multiplier
          if locationManager.isActuallyOutside {
              multiplier *= outdoorMultiplier
              isGPSMultiplierActive = true
          }
        
        // Morning multiplier
          if isInMorningHours() {
              multiplier *= morningMultiplier
              isTimeMultiplierActive = true
          }

          experiencePoints += Int(Double(currentLuxValue) * multiplier * Double(baseXPRate))
        saveExperiencePoints()
      }

    // TODO: Change this after making demo video
     func isInMorningHours() -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        return hour >= 0 && hour < 10 // 6AM to 10AM
    }
    
//    func writeToCharacteristic(value: String) {
//        guard let luxBuddyDevice = luxBuddy else {
//            print("Device not connected")
//            return
//        }
//
//        let characteristicUUID = writeableCharacteristic
//        
//        // Assuming the device is already connected and services are discovered
//        for service in luxBuddyDevice.services ?? [] {
//            if let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID }) {
//                let data = Data(value.utf8)
//                luxBuddyDevice.writeValue(data, for: characteristic, type: .withResponse)
//                return
//            }
//        }
//
//        print("Characteristic not found")
//    }
    
    //
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == CBUUID(string: "bbdb69d3-f9b5-4a22-b032-ee6140c6c438"), let value = characteristic.value {
            luxValue = String(decoding: value, as: UTF8.self)
            
            // Update lux data immediately upon receiving new data
            updateLuxData()
            
            updateExperiencePoints(with: locationManager)

            // Send updated experience points to M5StickC Plus
            //let experienceLevelString = String(experiencePoints)
//            writeToCharacteristic(value: experienceLevelString)
        }
    }
}
