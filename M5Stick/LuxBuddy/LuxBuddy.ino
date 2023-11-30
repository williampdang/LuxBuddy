/// https://github.com/mo-thunderz/Esp32BlePart1/blob/main/Arduino/BLE_server/BLE_server.ino

/*
// Information from Google Bard compiled from 
https://github.com/m5stack/M5-DLight/blob/master/src/M5_DLight.cpp#L60
https://blog.csdn.net/m0_47329175/article/details/124299109
| Mode | Accuracy | Power Consumption |
| - | - | -|
| CONTINUOUSLY_H_RESOLUTION_MODE | High | Highest |
| CONTINUOUSLY_H_RESOLUTION_MODE2 | Medium | High |
| CONTINUOUSLY_L_RESOLUTION_MODE | Low | Medium |

  // Need to be initialized in the loop
| ONE_TIME_H_RESOLUTION_MODE | Medium | Medium |
| ONE_TIME_H_RESOLUTION_MODE2 | Low | Low |
| ONE_TIME_L_RESOLUTION_MODE | Very low | Very low |
*/

// Include libraries for BLE, M5Stick, and Ambient Light Sensor
#include <M5StickCPlus.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <M5_DLight.h>

// Defining Service and Characteristics UUIDs
#define SERVICE_UUID                "331f07e0-452a-4f2c-9ee9-5e177516e5ea"
#define CHARACTERISTIC_UUID         "bbdb69d3-f9b5-4a22-b032-ee6140c6c438"

// Code used to create writable characteristic
// #define CHARACTERISTIC_UUID_RECEIVED "f39b1499-4813-4bbf-959a-1190a4bf7bff"

// Create instance of sensor and make variable to hold its lux
M5_DLight sensor;
uint16_t lux;

// Create variable to track if device is connected
bool isBLEConnected = false; 

// Get information on device connections 
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      M5.Lcd.println("AHHH I'm AWAKE!");
      isBLEConnected = true;
    };

    void onDisconnect(BLEServer* pServer) {
      M5.Lcd.println("Device disconnected");
      isBLEConnected = false;
      // Restart advertising when disconnects
      BLEDevice::startAdvertising();
      M5.Lcd.println("Ready to connect...");
    }
};

// // Code to receive data from central device
// class MyCharacteristicCallbacks: public BLECharacteristicCallbacks {
//     void onWrite(BLECharacteristic *pCharacteristic) {
//         std::string value = pCharacteristic->getValue();
//           if (value.length() > 0) {
//             int receivedExperiencePoints = std::atoi(value.c_str());
//             // M5.Lcd.setCursor(0, 50);
//             // M5.Lcd.println("Received Data: ");
//             // M5.Lcd.println(receivedExperiencePoints);
//         }
//     }
// };

BLECharacteristic *pCharacteristic;

void setup() {
  M5.begin();
  M5.Lcd.println("LuxBuddy: Good morning... ZzZz");
  M5.Lcd.println();

  sensor.begin(&Wire, 0, 26); // HAT DLight
  // Use this mode for best results, however there's a battery saving mode
  sensor.setMode(CONTINUOUSLY_H_RESOLUTION_MODE);

  BLEDevice::init("LuxBuddy");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
                       CHARACTERISTIC_UUID,
                       BLECharacteristic::PROPERTY_READ |
                       BLECharacteristic::PROPERTY_WRITE |
                       BLECharacteristic::PROPERTY_NOTIFY
                     );
                     

  // // WRITEABLE CHARACTERISTIC
  // BLECharacteristic *pCharacteristicReceived = pService->createCharacteristic(
  //                                           CHARACTERISTIC_UUID_RECEIVED,
  //                                           BLECharacteristic::PROPERTY_WRITE
  //                                         );

  // pCharacteristicReceived->setCallbacks(new MyCharacteristicCallbacks()); 
  // // WRITABLE CHARACTERISTIC

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  M5.Lcd.println("Oh no! LuxBuddy is Asleep!");
  M5.Lcd.println("Connect on your phone to wake him up!");
}

void loop() {
    M5.update();

    if (isBLEConnected) {
        lux = sensor.getLUX();

        // Convert lux value to string to send over BLE
        char luxStr[16];
        sprintf(luxStr, "%u", lux);
        pCharacteristic->setValue(luxStr);
        pCharacteristic->notify();
        
        // Display Lux Value
        M5.Lcd.setCursor(5, 80);
        M5.Lcd.printf("Lux: %u", lux);
        M5.Lcd.println();
    }

    delay(1000); // Delay for a second
}
