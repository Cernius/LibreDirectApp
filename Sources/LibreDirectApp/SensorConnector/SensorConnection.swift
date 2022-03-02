//
//  SensorConnection.swift
//  LibreDirect
//

import Combine
import CoreBluetooth
import Foundation

// MARK: - SensorConnection
@available(iOS 13.0, *)
protocol SensorConnection {
    var subject: PassthroughSubject<AppAction, AppError>? { get }
}

// MARK: - SensorBLEConnection

@available(iOS 13.0, *)
protocol SensorBLEConnection: SensorConnection {
    func pairSensor()
    func connectSensor(sensor: Sensor, sensorInterval: Int)
    func disconnectSensor()
}

// MARK: - IsSensor

protocol IsSensor {}

// MARK: - IsTransmitter

protocol IsTransmitter {}

@available(iOS 13.0, *)
extension SensorBLEConnection {
    func sendUpdate(connectionState: SensorConnectionState) {
        print("ConnectionState: \(connectionState.description)")

        subject?.send(.setConnectionState(connectionState: connectionState))
    }

    func sendUpdate(sensor: Sensor?, wasPaired: Bool = false) {
        print("Sensor: \(sensor?.description ?? "-")")

        if let sensor = sensor {
            subject?.send(.setSensor(sensor: sensor, wasPaired: wasPaired))
        } else {
            subject?.send(.resetSensor)
        }
    }

    func sendUpdate(transmitter: Transmitter) {
        print("Transmitter: \(transmitter.description)")

        subject?.send(.setTransmitter(transmitter: transmitter))
    }

    func sendUpdate(age: Int, state: SensorState) {
        print("SensorAge: \(age.description)")

        subject?.send(.setSensorState(sensorAge: age, sensorState: state))
    }

    func sendUpdate(sensorSerial: String, nextReading: SensorReading?) {
        print("NextReading: \(nextReading)")

        if let nextReading = nextReading {
            subject?.send(.addSensorReadings(sensorSerial: sensorSerial, trendReadings: [nextReading], historyReadings: []))
        } else {
            subject?.send(.addMissedReading)
        }
    }

    func sendUpdate(sensorSerial: String, trendReadings: [SensorReading] = [], historyReadings: [SensorReading] = []) {
        print("SensorTrendReadings: \(trendReadings)")
        print("SensorHistoryReadings: \(historyReadings)")

        if !trendReadings.isEmpty, !historyReadings.isEmpty {
            subject?.send(.addSensorReadings(sensorSerial: sensorSerial, trendReadings: trendReadings, historyReadings: historyReadings))
        } else {
            subject?.send(.addMissedReading)
        }
    }

    func sendUpdate(error: Error?) {
        guard let error = error else {
            return
        }

        if let errorCode = CBError.Code(rawValue: (error as NSError).code) {
            if errorCode.rawValue == 7 {
                sendUpdate(errorMessage: LocalizedString("Rescan the sensor"), errorIsCritical: true)
            } else {
                sendUpdate(errorMessage: LocalizedString("Connection timeout"), errorIsCritical: true)  
            }
        }
    }

    func sendUpdate(errorMessage: String, errorIsCritical: Bool = false) {
        print("ErrorMessage: \(errorMessage)")

        subject?.send(.setConnectionError(errorMessage: errorMessage, errorTimestamp: Date(), errorIsCritical: false))
    }

    func sendMissedUpdate() {
        print("Missed update")

        subject?.send(.addMissedReading)
    }
}

private func translateError(_ errorCode: Int) -> String {
    switch errorCode {
    case 0: // case unknown = 0
        return LocalizedString("Unknown")

    case 1: // case invalidParameters = 1
        return LocalizedString("Invalid parameters")

    case 2: // case invalidHandle = 2
        return LocalizedString("Invalid handle")

    case 3: // case notConnected = 3
        return LocalizedString("Not connected")

    case 4: // case outOfSpace = 4
        return LocalizedString("Out of space")

    case 5: // case operationCancelled = 5
        return LocalizedString("Operation cancelled")

    case 6: // case connectionTimeout = 6
        return LocalizedString("Connection timeout")

    case 7: // case peripheralDisconnected = 7
        return LocalizedString("Peripheral disconnected")

    case 8: // case uuidNotAllowed = 8
        return LocalizedString("UUID not allowed")

    case 9: // case alreadyAdvertising = 9
        return LocalizedString("Already advertising")

    case 10: // case connectionFailed = 10
        return LocalizedString("Connection failed")

    case 11: // case connectionLimitReached = 11
        return LocalizedString("Connection limit reached")

    case 13: // case operationNotSupported = 13
        return LocalizedString("Operation not supported")

    default:
        return ""
    }
}
private extension UserDefaults {
    enum Keys: String {
        case libre2UnlockCount = "libre-direct.libre2.unlock-count"
    }

    var libre2UnlockCount: Int {
        get {
            return UserDefaults.standard.integer(forKey: Keys.libre2UnlockCount.rawValue)
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Keys.libre2UnlockCount.rawValue)
        }
    }
}
