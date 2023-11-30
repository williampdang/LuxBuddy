// https://stackoverflow.com/questions/10583449/xcode-how-to-show-gps-strength-value
// https://stackoverflow.com/questions/10246662/how-can-i-evaluate-the-gps-signal-strength-iphone
// https://stackoverflow.com/questions/42932947/using-the-gps-to-detect-whether-an-android-device-is-indoors

import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var userAssumedOutside: Bool = false
    @Published var isActuallyOutside: Bool = false

    
    private let accuracyThreshold: Double = 14.3
    
    @Published var gpsAccuracy: Double?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            gpsAccuracy = location.horizontalAccuracy
            
            let gpsStrengthIsGood = location.horizontalAccuracy <= accuracyThreshold

            if userAssumedOutside && gpsStrengthIsGood {
                isActuallyOutside = true
            } else {
                isActuallyOutside = false
            }
        }
    }

    // Handle user toggling the outside status
    func toggleUserAssumedOutside() {
        userAssumedOutside.toggle()
        // If user toggles to false, we set isActuallyOutside to false immediately
        if !userAssumedOutside {
            isActuallyOutside = false
        }
    }
}
