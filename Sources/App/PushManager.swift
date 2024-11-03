//
//  PushManager.swift
//  SharedQueueServer
//
//  Created by Payton Curry on 10/12/24.
//

import Foundation
import FCM
class PushManager {
    static func sendNotificationToUser(type: CINotificationType, _ user: OBUserModel) async throws {
//        if let token = user.apnsToken {
//            var message = FCMMessage(token: token, notification: notification)
//            if let notificationChannel {
//                message.android = FCMAndroidConfig(notification: FCMAndroidNotification(channel_id: notificationChannel))
//                
//            }
//            _ = app.fcm.send(message)
//            print("sent notification to \(user.username)")
//        } else {
//            throw FCMError.noToken
//        }
        if let token = user.apnsToken {
            var message: FCMMessageDefault
            
            switch type {
            case .start(session: let session, family: let family):
                message = FCMMessage(token: token, notification: FCMNotification(title: type.title, body: type.body))
                (message as! FCMMessage).android = FCMAndroidConfig(notification: FCMAndroidNotification(channel_id: type.channel))
                message.apns = FCMApnsConfig(aps: type.activityData)
            case .update(session: let session, reason: let reason):
                message = FCMMessage(token: token, notification: FCMNotification(title: type.title, body: type.body))
                (message as! FCMMessage).android = FCMAndroidConfig(notification: FCMAndroidNotification(channel_id: type.channel))
                message.apns = FCMApnsConfig(aps: type.activityData)
            case .end(session: let session, reason: let reason):
                message = FCMMessage(token: token, notification: FCMNotification(title: type.title, body: type.body))
                (message as! FCMMessage).android = FCMAndroidConfig(notification: FCMAndroidNotification(channel_id: type.channel))
                message.apns = FCMApnsConfig(aps: type.activityData)
            case .addedToFamily(newUser: let newUser, family: let family):
                message = FCMMessage(token: token, notification: FCMNotification(title: type.title, body: type.body))
                (message as! FCMMessage).android = FCMAndroidConfig(notification: FCMAndroidNotification(channel_id: type.channel))
                message.apns = FCMApnsConfig(aps: type.activityData)
            }
            _ = app.fcm.send(message)
        }
    }
}

enum CISessionEndReason {
    case reachedDestination
    case userEnded
}

enum CISessionUpdateReason {
    case critical
    case nonCritical
}





enum CINotificationType {
    case addedToFamily(newUser: OBUserModel, family: CIFamilyModel)
    case start(session: CISessionModel, family: CIFamilyModel)
    case update(session: CISessionModel, reason: CISessionUpdateReason)
    case end(session: CISessionModel, reason: CISessionEndReason)
    
    var title: String {
        switch self {
        case .addedToFamily(let newUser, let family):
            return "New member"
        case .start(let session, _):
            return "\(session.host.username)'s Check In"
        case .update(let session, let makingProgress):
            return "\(session.host.username)'s Check In"
        case .end(let session, let reason):
            return "\(session.host.username)'s session"
        }
    }
    var body: String {
        switch self {
        case .start(let session, _):
            return "\(session.host.username) has started a Check In."
        case .update(let session, let reason):
            switch reason {
            case .critical:
                return "\(session.host.username) has not made any progress toward their destination."
            case .nonCritical:
                return ""
            }
        case .end(let session, let reason):
            switch reason {
            case .reachedDestination:
                return "\(session.host.username) has reached their destination. The Check In has ended."
            case .userEnded:
                return "\(session.host.username) has ended their Check In."
            }
        case .addedToFamily(newUser: let user, family: let family):
            return "\(user.username) just joined \(family.name)!"
        }
    }
    var channel: String {
        switch self {
        case .start(let session, _):
            return "cistarted"
        case .update(let session, let makingProgress):
            return "ciupdate"
        case .end(let session, let reason):
            switch reason {
            case .reachedDestination:
                return "ciended_dest"
            case .userEnded:
                return "ciended"
            }
        case .addedToFamily(newUser: let newUser, family: let family):
            "familyupdates"
        }
    }
    var activityData: FCMApnsApsObject {
        switch self {
        case .start(let session, let family):
//            return [
//                "event": "start",
//                "content-state": [
//                    "distance": session.distance,
//                    "makingProgress": true,
//                    "batteryLevel": session.batteryLevel,
//                    "lastUpdated": session.lastUpdate
//                ],
//                "attributes": [
//                    "host": session.host.username,
//                    "destinationDistance": session.distance,
//                    "familyID": family.id.uuidString
//                ]
//            ]
            return FCMApnsApsObject(sound: "default", event: "start", contentState: [
                "distance": session.distance,
                "makingProgress": true,
                "batteryLevel": session.batteryLevel,
                "lastUpdated": session.lastUpdate
            ], attributes: [
                "host": session.host.username,
                "destinationDistance": session.distance,
                "familyID": try! family.requireID().uuidString
            ])
        case .update(let session, let reason):
//            return [
//                "event":"update",
//                "content-state": [
//                    "distance": session.distance,
//                    "makingProgress": reason == .critical ? false : true,
//                    "batteryLevel": session.batteryLevel,
//                    "lastUpdated": session.lastUpdate
//                ]
//            ]
            return FCMApnsApsObject(sound: "default", event: "update", contentState: [
                "distance": session.distance,
                "makingProgress": true,
                "batteryLevel": session.batteryLevel,
                "lastUpdated": session.lastUpdate
            ])
        case .end(let session, let reason):
            return FCMApnsApsObject(sound: "default", event: "end")
        case .addedToFamily(newUser: let newUser, family: let family):
            return FCMApnsApsObject(sound: "default")
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
