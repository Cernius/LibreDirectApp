//
//  SensorPairing.swift
//  LibreDirect
//
//  Special thanks to: guidos
//

import Combine
import Foundation

//#if canImport(CoreNFC)
import CoreNFC
// MARK: - Libre2Pairing
// padaryti public?

@available(iOS 13.0, *)
final public class Libre2Pairing: NSObject, NFCTagReaderSessionDelegate {
    // MARK: Lifecycle

    public override init() {}

    public func readSensor() {
       
            if NFCTagReaderSession.readingAvailable {
                session = NFCTagReaderSession(pollingOption: .iso15693, delegate: self, queue: nfcQueue)
                session?.alertMessage = "Hold the top edge of your iPhone close to the sensor."
                session?.begin()
            }
    }

    @available(iOS 13.0, *)
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    @available(iOS 13.0, *)
    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
            if let readerError = error as? NFCReaderError, readerError.code != .readerSessionInvalidationErrorUserCanceled {
                session.invalidate(errorMessage: "Connection failure: \(readerError.localizedDescription)")
                
                logErrorAndDisconnect("Reader session didInvalidateWithError: \(readerError.localizedDescription))")
            }
    }

    @available(iOS 13.0, *)
    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        Task {
            guard let firstTag = tags.first else {
                logErrorAndDisconnect("No tag found")
                return
            }

            guard case .iso15693(let tag) = firstTag else {
                logErrorAndDisconnect("No ISO15693 tag found")
                return
            }

            do {
                if #available(iOS 15.0, *) {
                    try await session.connect(to: firstTag)
                } else {
                    // Fallback on earlier versions
                }
            } catch {
                logErrorAndDisconnect("Failed to connect to tag")
                return
            }

            let sensorUID = Data(tag.identifier.reversed())
            var patchInfo = Data()

            do {
                patchInfo = try await tag.customCommand(requestFlags: .highDataRate, customCommandCode: 0xA1, customRequestParameters: Data())
            } catch {
                logErrorAndDisconnect("Invalid patchInfo")
                return
            }

            guard patchInfo.count >= 6 else {
                logErrorAndDisconnect("Invalid patchInfo")
                return
            }

            let type = SensorType(patchInfo)
            guard type == .libre2EU || type == .libre1 else {
                logErrorAndDisconnect("Invalid sensor type")
                return
            }

            let blocks = 43
            let requestBlocks = 3

            let requests = Int(ceil(Double(blocks) / Double(requestBlocks)))
            let remainder = blocks % requestBlocks
            var dataArray = [Data](repeating: Data(), count: blocks)

            for i in 0 ..< requests {
                
                if #available(iOS 14.0, *) {
                    let requestFlags: NFCISO15693RequestFlag = [.highDataRate, .address]
                
                
                let blockRange = NSRange(UInt8(i * requestBlocks) ... UInt8(i * requestBlocks + (i == requests - 1 ? (remainder == 0 ? requestBlocks : remainder) : requestBlocks) - (requestBlocks > 1 ? 1 : 0)))

                var failedRead: Bool
                var failedRetries = 5

                repeat {
                    failedRead = false
                    failedRetries -= 1

                    do {
                        let blockArray = try await tag.readMultipleBlocks(requestFlags: requestFlags, blockRange: blockRange)
                        for j in 0 ..< blockArray.count {
                            dataArray[i * requestBlocks + j] = blockArray[j]
                        }
                    } catch {
                        failedRead = true
                    }
                } while failedRead && failedRetries > 0
                
                if failedRead {
                    logErrorAndDisconnect("Failed to read multiple tags")
                    return
                }

                if i == requests - 1 {
                    print("create fram")

                    var fram = Data()
                    for (_, data) in dataArray.enumerated() {
                        if !data.isEmpty {
                            fram.append(data)
                        }
                    }

                    guard fram.count >= 344 else {
                        logErrorAndDisconnect("Invalid fram")
                        return
                    }

                    print("create sensor")
                    let sensor = Sensor(uuid: sensorUID, patchInfo: patchInfo, fram: SensorUtility.decryptFRAM(uuid: sensorUID, patchInfo: patchInfo, fram: fram) ?? fram)

                    print("sensor: \(sensor)")
                    print("sensor, age: \(sensor.age)")
                    print("sensor, lifetime: \(sensor.lifetime)")

                    guard sensor.state != .expired else {
                        logErrorAndDisconnect("Scanned sensor expired", showToUser: true)

                        return
                    }

                    print("parse sensor readings")
                    let sensorReadings = SensorUtility.parseFRAM(calibration: sensor.factoryCalibration, pairingTimestamp: sensor.pairingTimestamp, fram: sensor.fram!)

                    if type == .libre1 {
                        session.invalidate()


                        if sensor.state == .ready {
                          print("ready")
                        }
                    } else {
                        let streamingCmd = self.nfcCommand(.enableStreaming, unlockCode: self.unlockCode, patchInfo: patchInfo, sensorUID: sensorUID)
                        let streaminResponse = try await tag.customCommand(requestFlags: .highDataRate, customCommandCode: Int(streamingCmd.code), customRequestParameters: streamingCmd.parameters)
                        let streamingEnabled = streaminResponse.count == 6

                        session.invalidate()

                        guard streamingEnabled else {
                            logErrorAndDisconnect("Streaming not enabled")
                            return
                        }

                        print("was paired ")
                        
                        if sensor.state == .ready {
                            print("state = ready")
                        }
                    }
                }
                }}
        }
    }

    // MARK: Private

    private var session: NFCTagReaderSession?
    private let nfcQueue = DispatchQueue(label: "libre-direct.nfc-queue")
    private let unlockCode: UInt32 = 42

    private func logErrorAndDisconnect(_ message: String, showToUser: Bool = false) {
        print(message)

        session?.invalidate()

       
    }

    private func nfcCommand(_ code: Subcommand, unlockCode: UInt32, patchInfo: Data, sensorUID: Data) -> NFCCommand {
        var parameters = Data([code.rawValue])

        var b: [UInt8] = []
        var y: UInt16

        if code == .enableStreaming {
            // Enables Bluetooth on Libre 2. Returns peripheral MAC address to connect to.
            // unlockCode could be any 32 bit value. The unlockCode and sensor Uid / patchInfo
            // will have also to be provided to the login function when connecting to peripheral.
            b = [
                UInt8(unlockCode & 0xFF),
                UInt8((unlockCode >> 8) & 0xFF),
                UInt8((unlockCode >> 16) & 0xFF),
                UInt8((unlockCode >> 24) & 0xFF)
            ]
            y = UInt16(patchInfo[4 ... 5]) ^ UInt16(b[1], b[0])
        } else {
            y = 0x1B6A
        }

        if !b.isEmpty {
            parameters += b
        }

        if code.rawValue < 0x20 {
            let d = SensorUtility.usefulFunction(uuid: sensorUID, x: UInt16(code.rawValue), y: y)
            parameters += d
        }

        return NFCCommand(code: 0xA1, parameters: parameters)
    }
}

// MARK: - NFCCommand

private struct NFCCommand {
    let code: UInt8
    let parameters: Data
}

// MARK: - Subcommand

private enum Subcommand: UInt8, CustomStringConvertible {
    case activate = 0x1B
    case enableStreaming = 0x1E

    // MARK: Internal

    var description: String {
        switch self {
        case .activate:
            return "activate"
        case .enableStreaming:
            return "enable BLE streaming"
        }
    }
}
//
//#else
//final class Libre2Pairing: NSObject {
//    // MARK: Lifecycle
//
//    init() {}
//
//    // MARK: Internal
//
//    public func readSensor() {}
//}
//
//#endif
