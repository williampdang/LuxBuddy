import SwiftUI

struct ContentView: View {
    // Create objects for the location manager
    @ObservedObject var locationManager: LocationManager
    
    // Create objects for ble manager
    @ObservedObject var bleManager: BLEManager
    
    // String to hold lux buddy message based on different variables
    // Only works if LuxBuddy is connected
    private var luxBuddyMessage: String {
        if bleManager.luxBuddyIsConnected{
            
            // TODO: Change to LUX HOURS!!!! Put into report :P
            if bleManager.totalLuxMinutes >= 5000 {
                return "Congratulations! 5000 Lux a day keeps the psychiatrist at bay"
            }
            
            // If the person is outside and it's the morning time
            if locationManager.isActuallyOutside && bleManager.isInMorningHours() {
                return "Okay Michael Jordan with the Triple Threat! 🏀 🐐 (You're hanging out with me, outdoors, and its the morning)"
            }
            
            // If the user isn't trying to go outside and its the morning
            if !locationManager.userAssumedOutside && bleManager.isInMorningHours() {
                return "Good morning! Its prime time to double up and go outside and collect light hours!"
            }
            
            return "I'm awake now good morning!"
            
        }
        return ""
        
    }
    
    // State variable for developer mode
    @State private var isDeveloperMode = false
    
    // Init location and ble managers
    init() {
        let locationManager = LocationManager()
        self.locationManager = locationManager
        self.bleManager = BLEManager(locationManager: locationManager)
    }
    
    var body: some View {
        NavigationView {
            List {
                
                // Section for Scanning and Connecting to LuxBuddy
                Section(header: Text("Connect")) {
                    Button(action: {
                        if bleManager.isScanning {
                            bleManager.stopScanning()
                        } else {
                            bleManager.startScanning()
                        }
                    })
                    {
                        Text(bleManager.isScanning ? "Leave LuxBuddy Alone" : "Look for LuxBuddy")
                    }
                    
                    // Once app finds LuxBuddy use the button to conenct to the device
                    if bleManager.isLuxBuddyDiscovered {
                        HStack {
                            Text("LuxBuddy")
                            Spacer()
                            Button("Wake up LuxBuddy") {
                                bleManager.connectToDevice()
                            }
                        }
                    }
                }
                
                // Section for message from luxbuddy
                Section(header: Text("Words of Encouragement from LuxBuddy!")) {
                    Text(luxBuddyMessage)
                        .foregroundColor(.green)
                }
                
                // Section to initiailize going outside with LuxBuddy
                Section(header: Text("Oh, the Great Outdoors!")) {
                    Button(action: {
                        locationManager.toggleUserAssumedOutside()
                    })
                    {
                        HStack {
                            Text(locationManager.userAssumedOutside ? "Let's Go Back Inside" : "Let's Go Touch Some Grass")
                        }
                    }
                    
                    if locationManager.userAssumedOutside {
                        Text(locationManager.isActuallyOutside ? "LuxBuddy: Yay! We're Outside! 🌄" : "LuxBuddy: I have my shoes, when will we be outside? 👟👟.. Yes I have two left feet ")
                    }
                }
                
                // Give total minutes outside
                Section(header: Text("Lux Data")) {
                    // TODO: FUDGED DATA HERE, Put in report
                    // TODO: ALSO PUT THAT STREAM OF DATA IS NOT COMING BY THE MINUTE FROM DEVICE
                    Text("Lux Hours Today: \(bleManager.totalLuxMinutes )")
                }
                
                // Notify users if they're outside
                Section(header: Text("Multipliers Status")) {
                    Text("Time Multiplier Active: \(bleManager.isTimeMultiplierActive ? "✅" : "👎")")
                    Text("GPS Multiplier Active: \(bleManager.isGPSMultiplierActive ? "✅" : "👎")")
                }
                
                
                // Shows lux minutes collected for different contexts
                Section(header: Text("Advanced Lux Minute Tracking")) {
                    HStack {
                        Text("Total Lux Minutes Outside:")
                        Spacer()
                        Text("\(bleManager.totalLuxMinutesOutside)")
                    }
                    
                    HStack {
                        Text("Total Lux Minutes in Morning Hours:")
                        Spacer()
                        Text("\(bleManager.totalLuxMinutesInTimeRange)")
                    }
                    
                    HStack {
                        Text("Total Lux Minutes in Morning Hours and Outside:")
                        Spacer()
                        Text("\(bleManager.totalLuxMinutesOutsideMorning)")
                    }
                }
                
                // This is the way to start a new day for LuxBuddy
                Section(header: Text("Simulate New Day")) {
                    Button(action: {
                        bleManager.resetLuxData()
                    }) {
                        Text("Press to start a new day").foregroundColor(.red)
                    }
                }
                
                // -------------
                
                // Developer Tools Section - Initially visible, hidden in User Mode
                Button(action: {
                    isDeveloperMode.toggle()
                }) {
                    Text(isDeveloperMode ? "Switch to User Mode" : "Switch to Developer Mode")
                }
                
                // Additional sections if developer mode is active
                if isDeveloperMode {
                    Section(header: Text("Developer Tools")) {
                        Button(action: {
                            bleManager.resetLuxData()
                        }) {
                            Text("Reset Data Data").foregroundColor(.red)
                        }
                    }
                    
                    Section(header: Text("GPS Signal")) {
                        if let gpsAccuracy = locationManager.gpsAccuracy {
                            Text("GPS Accuracy: \(gpsAccuracy) meters")
                        } else {
                            Text("GPS Accuracy: Unavailable")
                        }
                    }
                    
                    Section(header: Text("Current Lux Value")) {
                        Text("Lux Value: \(bleManager.luxValue)")
                    }
                    
                    Section(header: Text("Lux Data")) {
                        Text("Total Lux Minutes: \(bleManager.totalLuxMinutes)")
                        Text("Lux Hours Today: \(bleManager.totalLuxMinutes / 60)")
                    }
                    
                    Section(header: Text("Experience Points")) {
                        Text("Your XP: \(bleManager.experiencePoints)")
                    }
                    
                }
            }
            .navigationBarTitle("LuxBuddy")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
