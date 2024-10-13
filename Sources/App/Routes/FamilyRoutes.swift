//
//  FamilyRoutes.swift
//  SharedQueueServer
//
//  Created by Payton Curry on 10/12/24.
//
import Foundation
import Vapor
import JWT
import Fluent
import Turf

class FamilyRoutes: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let familyRoutes = routes.grouped("family").grouped(Token.authenticator())
        familyRoutes.post("create") { req async throws -> HTTPStatus in
            let user = try req.auth.require(OBUserModel.self)
            if let data = req.body.data {
                let group = try JSONDecoder().decode(CIFamily.self, from: data)
                var userIDs = [UUID]()
                group.users.forEach { user in
                    userIDs.append(user.id)
                }
                var userModel = try await OBUserModel.query(on: req.db).filter(\OBUserModel.$id == group.users[0].id).all()[0]
                userModel.familyIDs.append(group.id)
                try await userModel.update(on: req.db)
                let groupModel = CIFamilyModel(id: group.id, name: group.name, userIDs: userIDs)
                try await groupModel.save(on: req.db)
                return HTTPStatus(statusCode: 200)
            } else {
                throw Abort(.badRequest, reason: "No group object included")
            }
            
        }
        familyRoutes.post("invite", ":familyID") { req in
            let user = try req.auth.require(OBUserModel.self)
            if let rawFamilyID = req.parameters.get("familyID"), let familyID = UUID(uuidString: rawFamilyID) {
                var families = try await CIFamilyModel.query(on: req.db).filter(\CIFamilyModel.$id == familyID).all()
                if families.count > 0 {
                    var family = families[0]
                    if try user.hasAccessToFamily(family: family) {
                        return try await family.createJoinURL().absoluteString
                    } else {
                        throw Abort(.forbidden, reason: "User isn't in group")
                    }
                } else {
                    throw Abort(.notFound, reason: "Group not found")
                }
            } else {
                throw Abort(.badRequest, reason: "No or incorrect family ID")
            }
        }
        familyRoutes.post("join", ":token") { req async throws -> HTTPStatus in
            var user = try req.auth.require(OBUserModel.self)
            if let tokenValue = req.parameters.get("token") {
                var tokens = try await FamilyJoinToken.query(on: req.db).filter(\FamilyJoinToken.$value == tokenValue).all()
                if tokens.count > 0 {
                    var token = tokens[0]
                    token.family.usersIDs.append(try user.requireID())
                    try await token.family.update(on: req.db)
                    user.familyIDs.append(try token.family.requireID())
                    try await user.update(on: req.db)
                    try await token.delete(on: req.db)
                    return HTTPStatus(statusCode: 200)
                } else {
                    throw Abort(.notFound, reason: "Link invalid")
                }
            } else {
                throw Abort(.badRequest, reason: "No join token")
            }
        }
        familyRoutes.get("get", ":familyID") { req async throws in
            var user = try req.auth.require(OBUserModel.self)
            if let rawFamilyID = req.parameters.get("familyID"), let familyID = UUID(uuidString: rawFamilyID) {
                if let family = try await CIFamilyModel.query(on: req.db).filter(\CIFamilyModel.$id == familyID).first() {
                    if try user.hasAccessToFamily(family: family) {
                        return try await family.asCIFamily(database: req.db)
                    } else {
                        throw Abort(.forbidden)
                    }
                } else {
                    throw Abort(.notFound)
                }
            } else {
                throw Abort(.badRequest, reason: "No or incorrect family ID")
            }
        }
        familyRoutes.post("startsession", ":familyID") { req async throws -> HTTPStatus in
            var user = try req.auth.require(OBUserModel.self)
            if let familyID = uuid(req.parameters.get("familyID")) {
                if let family = try await CIFamilyModel.query(on: req.db).filter(\CIFamilyModel.$id == familyID).first(), try user.hasAccessToFamily(family: family) {
                    
                    if try await family.$currentSession.get(on: req.db) == nil {
                        if let body = req.body.data {
                            let session = try JSONDecoder().decode(CISession.self, from: body)
                            
                            let origin = LocationCoordinate2D(latitude: Double(session.latitude), longitude: Double(session.longitude))
                            let destination = LocationCoordinate2D(latitude: Double(session.destinationLat), longitude: Double(session.destinationLong))
                            let distance = origin.distance(to: destination)
                            let sessionModel = CISessionModel(id: session.id, host: try user.requireID(), latitude: session.latitude, longitude: session.longitude, batteryLevel: session.batteryLevel, destinationLat: session.destinationLat, destinationLong: session.destinationLong, family: try family.requireID(), radius: session.radius, distance: distance)
//                            try await sessionModel.create(on: req.db)
                            
                            try await family.$currentSession.create(sessionModel, on: req.db)
                            try await family.update(on: req.db)
                            print("Making session")
                            return HTTPStatus(statusCode: 200)
                        } else {
                            throw Abort(.badRequest, reason: "No or invalid CISession in body")
                        }
                    } else {
                        throw Abort(.conflict, reason: "Group already has a session")
                    }
                } else {
                    throw Abort(.notFound, reason: "Family doesn't exist")
                }
            } else {
                throw Abort(.badRequest, reason: "No or incorrect family ID")
            }
        }
        familyRoutes.post("updatesession", ":familyID") { req async throws -> HTTPStatus in
            print(Date())
            var user = try req.auth.require(OBUserModel.self)
            if let familyID = uuid(req.parameters.get("familyID")), let family = try await CIFamilyModel.query(on: req.db).filter(\CIFamilyModel.$id == familyID).first(), try user.hasAccessToFamily(family: family), try user.hasAccessToFamily(family: family) {
                
                if let sessionModel = try await family.$currentSession.get(on: req.db), try await sessionModel.$host.get(on: req.db).id == user.id {
                    if let body = req.body.data, let session = try? JSONDecoder().decode(CISession.self, from: body) {
                        let origin = LocationCoordinate2D(latitude: Double(session.latitude), longitude: Double(session.longitude))
                        let destination = LocationCoordinate2D(latitude: Double(session.destinationLat), longitude: Double(session.destinationLong))
                        let distance = origin.distance(to: destination)
                        sessionModel.batteryLevel = session.batteryLevel
                        sessionModel.destinationLat = session.destinationLat
                        sessionModel.destinationLong = session.destinationLong
                        sessionModel.latitude = session.latitude
                        sessionModel.longitude = session.longitude
                        sessionModel.distance = distance
                        if (sessionModel.distance - session.distance <= -20) {
                            sessionModel.noProgressInstances = sessionModel.noProgressInstances + 1
                            print("\(session.host.username) losing progress")
                        } else {
                            sessionModel.noProgressInstances = 0
                            print("\(session.host.username) making progress")
                        }
                        if (sessionModel.noProgressInstances > 3) {
                            //notify
                            print("\(session.host.username) no progress \(sessionModel.noProgressInstances) times. notifying")
                        }
                        try await sessionModel.update(on: req.db)
                        return HTTPStatus.accepted
                    } else {
                        throw Abort(.badRequest, reason: "Missing or invalid CISession in body")
                    }
                } else {
                    throw Abort(.forbidden, reason: "User does not have permission to update this session")
                }
            } else {
                throw Abort(.badRequest, reason: "Missing or incorrect family ID OR user doesn't have access to family")
            }
        }
        familyRoutes.post("endsession", ":familyID") { req async throws -> HTTPStatus in
            var user = try req.auth.require(OBUserModel.self)
            if let familyID = uuid(req.parameters.get("familyID")), let family = try await CIFamilyModel.query(on: req.db).filter(\CIFamilyModel.$id == familyID).first(), try user.hasAccessToFamily(family: family), try user.hasAccessToFamily(family: family) {
                try await family.$currentSession.load(on: req.db)
                if let sessionModel = family.currentSession, try await sessionModel.$host.get(on: req.db).id == user.id {
                    try await sessionModel.delete(on: req.db)
                    try await family.update(on: req.db)
                    return HTTPStatus(statusCode: 200)
                } else {
                    throw Abort(.forbidden, reason: "User does not have permission to update this session")
                }
            } else {
                throw Abort(.badRequest, reason: "Missing or incorrect family ID OR user doesn't have access to family")
            }
        }
    }
}
func uuid(_ raw: String?) -> UUID? {
    if let raw, let uuid = UUID(uuidString: raw) {
        return uuid
    } else {
        return nil
    }
}

extension CIFamily: Content {}

extension OBUserModel {
    func hasAccessToFamily(family: CIFamilyModel) throws -> Bool {
        return family.usersIDs.contains(try requireID())
    }
}


