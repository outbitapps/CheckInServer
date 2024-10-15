//
//  PushManager.swift
//  SharedQueueServer
//
//  Created by Payton Curry on 10/12/24.
//

import Foundation
import FCM
class PushManager {
    static func sendNotificationToUser(_ notification: FCMNotification, _ user: OBUserModel) async throws {
        if let token = user.apnsToken {
            let message = FCMMessage(token: token, notification: notification)
            _ = app.fcm.send(message)
            print("sent notification to \(user.username)")
        } else {
            throw FCMError.noToken
        }
    }
}


enum FCMError: Error {
    // Throw when an invalid password is entered
    case noToken

    // Throw when an expected resource is not found
    // Throw in all other cases
    case unexpected(code: Int)
}
