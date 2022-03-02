//
//  SensorBLEConnection.swift
//  LibreDirect
//

import Combine
import CoreBluetooth
import Foundation

// MARK: - SensorBLEConnectionBase

@available(iOS 13.0, *)
class SensorBLEConnectionBase: NSObject, SensorBLEConnection, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: Lifecycle

    init(subject: PassthroughSubject<AppAction, AppError>, serviceUUID: CBUUID) {
        print("init")

        super.init()

        self.subject = subject
        self.serviceUUID = serviceUUID
        self.manager = CBCentralManager(delegate: self, queue: managerQueue, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    deinit {
        print("deinit")

        managerQueue.sync {
            disconnect()
        }
    }

    // MARK: Internal

    var serviceUUID: CBUUID!
    var manager: CBCentralManager!

    let managerQueue = DispatchQueue(label: "libre-direct.sensor-ble-connection.queue")
    weak var subject: PassthroughSubject<AppAction, AppError>?

    var stayConnected = false
    var sensor: Sensor?
    var sensorInterval = 1

    var peripheralName: String {
        preconditionFailure("This property must be overridden")
    }

    var peripheral: CBPeripheral? {
        didSet {
            oldValue?.delegate = nil
            peripheral?.delegate = self

//            if let sensorPeripheralUUID = peripheral?.identifier.uuidString {
////                UserDefaults.standard.sensorPeripheralUUID = sensorPeripheralUUID
//            }
        }
    }

    func pairSensor() {
        print("PairSensor")

        sendUpdate(connectionState: .pairing)

        managerQueue.async {
            self.find()
        }
    }

    func connectSensor(sensor: Sensor, sensorInterval: Int) {
        print("ConnectSensor: \(sensor)")

        self.sensor = sensor
        self.sensorInterval = sensorInterval

        setStayConnected(stayConnected: true)

        managerQueue.async {
            self.find()
        }
    }

    func disconnectSensor() {
        print("DisconnectSensor")

        setStayConnected(stayConnected: false)

        managerQueue.sync {
            self.disconnect()
        }
    }

    func find() {
        print("Find called")
        
        guard manager != nil else {
            print("Guard: manager is nil")
            return
        }

        guard manager.state == .poweredOn else {
            print("Guard: manager.state \(manager.state.rawValue) is not .poweredOn")
            return
        }

//        if let peripheralUUIDString = UserDefaults.standard.sensorPeripheralUUID,
//           let peripheralUUID = UUID(uuidString: peripheralUUIDString),
//           let retrievedPeripheral = manager.retrievePeripherals(withIdentifiers: [peripheralUUID]).first,
//           checkRetrievedPeripheral(peripheral: retrievedPeripheral)
//        {
//            print("Connect from retrievePeripherals")
//            connect(retrievedPeripheral)
//        } else {
//            print("Scan for peripherals")
//            scan()
//        }
    }

    func scan() {
        print("scan")
        
        guard manager != nil else {
            print("Guard: manager is nil")
            return
        }

        sendUpdate(connectionState: .scanning)
        manager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    func disconnect() {
        print("Disconnect")
        
        guard manager != nil else {
            print("Guard: manager is nil")
            return
        }

        if manager.isScanning {
            manager.stopScan()
        }

        if let peripheral = peripheral {
            manager.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
        }

        sendUpdate(connectionState: .disconnected)
        sensor = nil
    }

    func connect(_ peripheral: CBPeripheral) {
        print("Connect: \(peripheral)")
        
        guard manager != nil else {
            print("Guard: manager is nil")
            return
        }

        self.peripheral = peripheral

        manager.connect(peripheral, options: nil)
        sendUpdate(connectionState: .connecting)
    }

    func resetBuffer() {
        preconditionFailure("This method must be overridden")
    }

    func setStayConnected(stayConnected: Bool) {
        print("StayConnected: \(stayConnected.description)")
        self.stayConnected = stayConnected
    }

    func checkRetrievedPeripheral(peripheral: CBPeripheral) -> Bool {
        preconditionFailure("This property must be overridden")
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard manager != nil else {
            print("Guard: manager is nil")
            return
        }
        
        if let manager = manager {
            switch manager.state {
            case .poweredOff:
                sendUpdate(connectionState: .powerOff)

            case .poweredOn:
                sendUpdate(connectionState: .disconnected)

                guard stayConnected else {
                    break
                }

                find()
            default:
                sendUpdate(connectionState: .unknown)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("Peripheral: \(peripheral)")
        
        guard manager != nil else {
            print("Guard: manager is nil")
            return
        }

        guard peripheral.name?.lowercased().starts(with: peripheralName) ?? false else {
            return
        }

        manager.stopScan()
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Peripheral: \(peripheral), didFailToConnect")

        sendUpdate(connectionState: .disconnected)
        sendUpdate(error: error)

        guard stayConnected else {
            return
        }

        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Peripheral: \(peripheral), didDisconnectPeripheral")

        sendUpdate(connectionState: .disconnected)
        sendUpdate(error: error)

        guard stayConnected else {
            return
        }

        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Peripheral: \(peripheral)")

        resetBuffer()

        sendUpdate(connectionState: .connected)
        peripheral.discoverServices([serviceUUID])
    }
}
