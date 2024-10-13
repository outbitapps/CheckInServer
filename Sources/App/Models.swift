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

final class CISessionModel: Model {
    static let schema: String = "cisessions"
    
    @ID
    var id: UUID?
    
    @Parent(key: "user")
    var host: OBUserModel
    
    @Field(key: "last_lat")
    var latitude: Float
    
    @Field(key: "last_long")
    var longitude: Float
    
    @Timestamp(key: "last_upd", on: .update)
    var lastUpdate: Date?
    
    @Field(key: "battery")
    var batteryLevel: Double
    
    @Timestamp(key: "started", on: .create)
    var started: Date?
    
    @Field(key: "dest_lat")
    var destinationLat: Float
    @Field(key: "dest_long")
    var destinationLong: Float
    
    @Parent(key: "family")
    var family: CIFamilyModel
    init() {}
    init(id: UUID? = nil, host: OBUserModel.IDValue, latitude: Float, longitude: Float, lastUpdate: Date? = nil, batteryLevel: Double, started: Date? = nil, destinationLat: Float, destinationLong: Float, family: CIFamilyModel.IDValue) {
        self.id = id
        self.$host.id = host
        self.latitude = latitude
        self.longitude = longitude
        self.lastUpdate = lastUpdate
        self.batteryLevel = batteryLevel
        self.started = started
        self.destinationLat = destinationLat
        self.destinationLong = destinationLong
        self.$family.id = family
    }
    func toCISession(database: Database = app.db) async throws -> CISession {
        print("tocisession")
        var hostOBUser = try await $host.get(on: database).asOBUser(database: database)
        
        return CISession(id: try requireID(), host: hostOBUser, latitude: latitude, longitude: longitude, destinationLat: destinationLat, destinationLong: destinationLong, lastUpdate: lastUpdate!, batteryLevel: batteryLevel, started: started!)
    }
}

struct CreateCISession: Migration {
    func prepare(on database: any Database) -> EventLoopFuture<Void> {
        database.schema(CISessionModel.schema)
            .field("id", .uuid, .identifier(auto: true))
            .field("user", .uuid, .references("users", "id"))
            .field("last_lat", .float)
            .field("last_long", .float)
            .field("last_upd", .datetime)
            .field("battery", .double)
            .field("started", .datetime)
            .field("dest_lat", .float)
            .field("dest_long", .float)
            .field("family", .uuid, .references("cifamilies", "id"))
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
    var latitude: Float
    var longitude: Float
    var destinationLat: Float
    var destinationLong: Float
    var lastUpdate: Date
    var batteryLevel: Double
    var started: Date
    init(id: UUID, host: OBUser, latitude: Float, longitude: Float, destinationLat: Float, destinationLong: Float, lastUpdate: Date, batteryLevel: Double, started: Date) {
        self.id = id
        self.host = host
        self.latitude = latitude
        self.longitude = longitude
        self.destinationLat = destinationLat
        self.destinationLong = destinationLong
        self.lastUpdate = lastUpdate
        self.batteryLevel = batteryLevel
        self.started = started
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


