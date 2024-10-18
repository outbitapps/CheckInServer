//
//  File.swift
//  
//
//  Created by Payton Curry on 3/24/24.
//

import Foundation
import FluentKit
import Vapor
import Fluent

enum AuthProvider: Int, Codable {
    case emailAndPassword
    case apple
    case google
}

final class OBUserFamilyPivot: Model {
    static let schema = "user_and_family"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: OBUserModel
    
    @Parent(key: "family_id")
    var family: CIFamilyModel
    
    init() {}
    
    init(userID: UUID, familyID: UUID) {
        self.$user.id = userID
        self.$family.id = familyID
    }
}

final class OBUserModel: Model {
    
    static let schema: String = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "username")
    var username: String
    @Field(key: "email")
    var email: String
    @Field(key: "password")
    var password: String
    @Field(key: "auth_provider")
    var authProvider: AuthProvider
    @Field(key: "familyIDs")
    var familyIDs: [UUID]
    
    @Field(key: "apnsToken")
    var apnsToken: String?
    
    required init() {}
    
    init(id: UUID? = nil, username: String, email: String = UUID().uuidString, password: String = UUID().uuidString, authProvider: AuthProvider = .emailAndPassword, apnsToken: String? = nil) {
        self.id = id
        self.username = username
        self.email = email
        self.password = password
        self.authProvider = authProvider
        self.apnsToken = apnsToken
        self.familyIDs = []
    }
    static func userAlreadyExists(_ user: OBUserModel, database: Database = app.db) async throws -> Bool {
        let sameUsername = try await database.query(OBUserModel.self).filter(\.$username == user.username).all()
        let sameEmail = try await database.query(OBUserModel.self).filter(\.$email == user.email).all()
        return !sameUsername.isEmpty && !sameEmail.isEmpty
    }
    func asOBUser(database: Database = app.db) async throws -> OBUser {
        let id = try requireID()
        return OBUser(id: id, username: self.username, email: self.email, familyIDs: familyIDs)
    }
}

final class CIFamilyModel: Model {
   
    
    
    static let schema: String = "cifamilies"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    @Field(key: "userIds")
    var usersIDs: [UUID]
    
    @OptionalChild(for: \CISessionModel.$family)
    var currentSession: CISessionModel?
    
    init() {
        
    }
    init(id: UUID? = nil, name: String, userIDs: [UUID]) {
        self.id = id
        self.name = name
        self.usersIDs = userIDs
    }
    func asCIFamily(database: Database = app.db) async throws -> CIFamily {
        let id = try requireID()
        var users: [OBUser] = []
        for usersId in usersIDs {
            var user = try await database.query(OBUserModel.self).filter(\OBUserModel.$id == usersId).all()[0].asOBUser(database: database)
            users.append(user)
        }
        var session: CISession? = nil
        
        if let currentSession = try await $currentSession.get(on: database)  {
            session = try await currentSession.toCISession(database: database)
        }
        return CIFamily(id: try requireID(), name: name, users: users, currentSession: session)
    }
}

class CreateFamilyModel: AsyncMigration {
    func revert(on database: FluentKit.Database) async throws {
        try await database.schema("cifamilies").delete()
    }
    
    func prepare(on database: Database) async throws {
        try await database.schema("cifamilies")
            .id()
            .field("name", .string)
            .field("userIds", .array(of: .uuid))
            .field("session", .uuid, .references("cisessions", "id"))
            .create()
    }
    
}

struct CILatLong: Codable {
    var latitude: Double
    var longitude: Double
}

struct CISessionLocationHistory: Codable {
    var location: CILatLong
    var timestamp: Date
}

final class CISessionModel: Model {
    static let schema: String = "cisessions"
    
    @ID
    var id: UUID?
    
    @Parent(key: "user")
    var host: OBUserModel
    
    @Field(key: "current_location")
    var location: CILatLong
    
    @Timestamp(key: "last_upd", on: .update)
    var lastUpdate: Date?
    
    @Field(key: "battery")
    var batteryLevel: Double
    
    @Timestamp(key: "started", on: .create)
    var started: Date?
    
    @Field(key: "dest_location")
    var destination: CILatLong
    
    @Parent(key: "family")
    var family: CIFamilyModel
    @Field(key: "radius")
    var radius: Double
    
    @Field(key: "distance")
    var distance: Double
    
    @Field(key: "noProgressInstances")
    var noProgressInstances: Int
    @Field(key: "placeName")
    var placeName: String?
    
    @Field(key: "history")
    var history: [CISessionLocationHistory]
    
    init() {}
    init(id: UUID? = nil, host: OBUserModel.IDValue, location: CILatLong, lastUpdate: Date? = nil, batteryLevel: Double, started: Date? = nil, destination: CILatLong, family: CIFamilyModel.IDValue, radius: Double, distance: Double, placeName: String?, history: [CISessionLocationHistory]) {
        self.id = id
        self.$host.id = host
        self.location = location
        self.lastUpdate = lastUpdate
        self.batteryLevel = batteryLevel
        self.started = started
        self.destination = destination
        self.$family.id = family
        self.radius = radius
        self.distance = distance
        self.noProgressInstances = 0
        self.placeName = placeName
        self.history = history
    }
    func toCISession(database: Database = app.db) async throws -> CISession {
        print("tocisession")
        var hostOBUser = try await $host.get(on: database).asOBUser(database: database)
        
        return CISession(id: try requireID(), host: hostOBUser, location: self.location, destination: self.destination, lastUpdate: lastUpdate!, batteryLevel: batteryLevel, started: started!, radius: self.radius, distance: self.distance, placeName: self.placeName, history: self.history)
    }
}


struct CreateCISession: Migration {
    func prepare(on database: any Database) -> EventLoopFuture<Void> {
        database.schema(CISessionModel.schema)
            .field("id", .uuid, .identifier(auto: true))
            .field("user", .uuid, .references("users", "id"))
            .field("current_location", .dictionary)
            .field("last_upd", .datetime)
            .field("battery", .double)
            .field("started", .datetime)
            .field("dest_location", .dictionary)
            .field("family", .uuid, .references("cifamilies", "id"))
            .field("radius", .double)
            .field("distance", .double)
            .field("noProgressInstances", .int)
            .field("placeName", .string)
            .field("history", .array(of: .dictionary))
            .create()
    }
    func revert(on database: any Database) -> EventLoopFuture<Void> {
        database.schema(CISessionModel.schema).delete()
    }
}



public struct OBUser: Codable {
    var id: UUID
    var username: String
    var email: String?
    var familyIDs: [UUID]
    var apnsToken: String? = nil
    init(id: UUID, username: String, email: String? = nil, familyIDs: [UUID], apnsToken: String? = nil) {
        self.id = id
        self.username = username
        self.email = email
        self.familyIDs = familyIDs
        self.apnsToken = apnsToken
    }
}

public struct CIFamily: Codable {
    var id: UUID
    var name: String
    var users: [OBUser]
    var currentSession: CISession?
    init(id: UUID, name: String, users: [OBUser], currentSession: CISession? = nil) {
        self.id = id
        self.name = name
        self.users = users
        self.currentSession = currentSession
    }
}

public struct CISession: Codable {
    var id: UUID
    var host: OBUser
    var location: CILatLong
    var destination: CILatLong
    var lastUpdate: Date
    var batteryLevel: Double
    var started: Date
    var radius: Double
    var distance: Double
    var placeName: String?
    var history: [CISessionLocationHistory]
    init(id: UUID, host: OBUser, location: CILatLong, destination: CILatLong, lastUpdate: Date, batteryLevel: Double, started: Date, radius: Double, distance: Double, placeName: String?, history: [CISessionLocationHistory]) {
        self.id = id
        self.host = host
        self.location = location
        self.destination = destination
        self.lastUpdate = lastUpdate
        self.batteryLevel = batteryLevel
        self.started = started
        self.radius = radius
        self.distance = distance
        self.placeName = placeName
        self.history = history
    }
}

public struct NewSession: Codable {
  public let token: String
    public let user: OBUser
    public init(token: String, user: OBUser) {
        self.token = token
        self.user = user
    }
}

public struct UserSignup: Codable {
    public let email: String
    public let username: String
    public let password: String
    public init(email: String, username: String, password: String) {
        self.email = email
        self.username = username
        self.password = password
    }
}

class CreateUserModel: AsyncMigration {
    func revert(on database: FluentKit.Database) async throws {
        try await database.schema("users").delete()
    }
    
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("username", .string)
            .field("email", .string)
            .field("password", .string)
            .field("auth_provider", .int)
            .field("apnsToken", .string)
            .field("familyIDs", .array(of: .uuid))
            .create()
    }
    
}


