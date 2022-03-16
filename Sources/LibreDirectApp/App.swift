//
//  App.swift
//  LibreDirect
//

import CoreBluetooth
import SwiftUI

#if canImport(CoreNFC)
    import CoreNFC
#endif

// MARK: - LibreActivationApp

@available(iOS 14.0, *)
public class LibreActivationApp {
    // MARK: Lifecycle

    public init() {
        store = LibreActivationApp.createStore()

        notificationCenterDelegate = LibreDirectNotificationCenter(store: store)
        UNUserNotificationCenter.current().delegate = notificationCenterDelegate

        store.dispatch(.startup)
    }
    
    
    public func  startScan() -> String{
        store.dispatch(.pairSensor)
        
        if let currentGlucose = store.state.currentGlucose{
            let stringas = "sessionlog: \(sessionLog) \(currentGlucose)";
            print(stringas)
            return stringas;
        }
        
        
        return "";
            
        
    }

    deinit {
        UNUserNotificationCenter.current().delegate = nil
    }

    // MARK: Internal

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }



    // MARK: Private
    
    func getStore() -> AppStore{
        return self.store
    }

    let store: AppStore
    private let notificationCenterDelegate: UNUserNotificationCenterDelegate

    private static func createStore() -> AppStore {
        return createAppStore()
    }


    private static func createAppStore() -> AppStore {
        print("Create app store")

        var middlewares = [
            logMiddleware(),
//            expiringNotificationMiddelware(),
//            glucoseNotificationMiddelware(),
//            connectionNotificationMiddelware(),
//            appleCalendarExportMiddleware(),
//            appleHealthExportMiddleware(),
//            readAloudMiddelware(),
//            bellmanAlarmMiddelware(),
//            nightscoutMiddleware(),
//            appGroupSharingMiddleware(),
        ]

    
        #if canImport(CoreNFC)
            if NFCTagReaderSession.readingAvailable {
                middlewares.append(sensorConnectorMiddelware([
                    SensorConnectionInfo(id: "libre2", name: LocalizedString("Without transmitter")) { Libre2Connection(subject: $0) },
                    SensorConnectionInfo(id: "bubble", name: LocalizedString("Bubble transmitter")) { BubbleConnection(subject: $0) },
                ]))
            } else {
                middlewares.append(sensorConnectorMiddelware([
                    SensorConnectionInfo(id: "bubble", name: LocalizedString("Bubble transmitter")) { BubbleConnection(subject: $0) },
                ]))
            }
        #else
            middlewares.append(sensorConnectorMiddelware([
                SensorConnectionInfo(id: "bubble", name: LocalizedString("Bubble transmitter")) { BubbleConnection(subject: $0) },
            ]))
        #endif

        return AppStore(initialState: UserDefaultsState(), reducer: appReducer, middlewares: middlewares)
    }
}

// MARK: - LibreDirectNotificationCenter

@available(iOS 14.0, *)
final class LibreDirectNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    // MARK: Lifecycle

    init(store: AppStore) {
        self.store = store
    }

    // MARK: Internal

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let store = store, let action = response.notification.request.content.userInfo["action"] as? String, action == "snooze" {
            //NotificationService.shared.stopSound()
            store.dispatch(.setAlarmSnoozeUntil(untilDate: Date().addingTimeInterval(30 * 60).toRounded(on: 1, .minute)))
        }

        completionHandler()
    }

    // MARK: Private

    private weak var store: AppStore?
}

// MARK: - LibreDirectAppDelegate

final class LibreDirectAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("Application did finish launching with options")
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("Application will terminate")
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        print("Application did receive memory warning")
    }
}
