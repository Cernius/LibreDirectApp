//
//  ActionAppLog.swift
//  LibreDirect
//

import Combine
import Foundation
import OSLog
import SwiftUI

@available(iOS 13.0, *)
func logMiddleware() -> Middleware<AppState, AppAction> {
    return logMiddleware(service: SendLogsService())
}

@available(iOS 13.0, *)
private func logMiddleware(service: SendLogsService) -> Middleware<AppState, AppAction> {
    return { _, action, _ in
        print("Triggered action: \(action)")

        switch action {
        case .startup:
            service.deleteLogs()

        case .deleteLogs:
            service.deleteLogs()


        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

// MARK: - SendLogsService

@available(iOS 13.0, *)
private class SendLogsService {
    func deleteLogs() {
//        AppLog.deleteLogs()
    }

    func sendLog(fileURL: URL) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

        let foregroundWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { $0 as? UIWindowScene }
            .compactMap { $0 }
            .first?.windows
            .filter { $0.isKeyWindow }.first

        foregroundWindow?.rootViewController?.present(activityViewController, animated: true, completion: nil)
    }
}
