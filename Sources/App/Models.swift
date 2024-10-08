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
    required init() {}
    
    init(id: UUID? = nil, uid: String = "fdsfsdf", username: String, email: String = UUID().uuidString, password: String = UUID().uuidString, authProvider: AuthProvider = .emailAndPassword) {
        self.id = id
        self.username = username
        self.email = email
        self.password = password
        self.authProvider = authProvider
    }
    static func userAlreadyExists(_ user: OBUserModel, database: Database = app.db) async throws -> Bool {
        let sameUsername = try await database.query(OBUserModel.self).filter(\.$username == user.username).all()
        let sameEmail = try await database.query(OBUserModel.self).filter(\.$email == user.email).all()
        return !sameUsername.isEmpty && !sameEmail.isEmpty
    }
    func asOBUser(database: Database = app.db) async throws -> OBUser {
        let id = try requireID()
        return OBUser(id: id, username: self.username, email: self.email)
    }
}

public struct OBUser: Codable {
    var id: UUID
    var username: String
    var email: String?
    init(id: UUID, username: String, email: String? = nil) {
        self.id = id
        self.username = username
        self.email = email
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
            .field("uid", .string)
            .field("username", .string)
            .field("email", .string)
            .field("groups", .array(of: .string))
            .field("password", .string)
            .field("auth_provider", .int)
            .create()
    }
    
}


