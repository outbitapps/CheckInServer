//
//  File.swift
//  
//
//  Created by Payton Curry on 4/10/24.
//

import Foundation
import Vapor
import JWT
import Fluent

enum SessionSource: Int, Content {
    case signup
    case login
}

final class PasswordResetToken: Model {
    static let schema: String = "resettokens"
    
    @ID
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: OBUserModel
    
    @Field(key: "value")
    var value: String
    
    @Field(key: "expires_at")
    var expiresAt: Date?
    
    @Timestamp(key: "create_at", on: .create)
    var createdAt: Date?
    
    init() {}
    init(id: UUID? = nil, userID: OBUserModel.IDValue, token: String, expiresAt: Date?) {
        self.id = id
        self.$user.id = userID
        self.value = token
        self.expiresAt = expiresAt
    }
}





struct CreatePasswordTokens: Migration {
    func prepare(on database: any Database) -> EventLoopFuture<Void> {
        database.schema(PasswordResetToken.schema)
            .field("id", .uuid, .identifier(auto: true))
            .field("user_id", .uuid, .references("users", "id"))
            .field("value", .string, .required)
            .unique(on: "value")
            .field("create_at", .datetime, .required)
            .field("expires_at", .datetime)
            .create()
    }
    func revert(on database: any Database) -> EventLoopFuture<Void> {
        database.schema(PasswordResetToken.schema).delete()
    }
}

final class Token: Model {
    static let schema = "tokens"
    
    @ID
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: OBUserModel
    @Field(key: "value")
    var value: String
    
    @Field(key: "source")
    var source: SessionSource
    
    @Field(key: "expires_at")
    var expiresAt: Date?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    init() {}
    init(id: UUID? = nil, userId: OBUserModel.IDValue, token: String,
         source: SessionSource, expiresAt: Date?) {
        self.id = id
        self.$user.id = userId
        self.value = token
        self.source = source
        self.expiresAt = expiresAt
    }
}

final class FamilyJoinToken: Model {
    static let schema: String = "familytokens"
    
    @ID
    var id: UUID?
    
    @Parent(key: "family_id")
    var family: CIFamilyModel
    
    @Field(key: "value")
    var value: String
    
    @Field(key: "expires_at")
    var expiresAt: Date?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    init() {}
    init(id: UUID? = nil, family: CIFamilyModel.IDValue, value: String, expiresAt: Date? = nil) {
        self.id = id
        self.$family.id = family
        self.value = value
        self.expiresAt = expiresAt
    }
}

extension CIFamilyModel {
    func createJoinURL() async throws -> URL {
        let calendar = Calendar(identifier: .gregorian)
        let expiryDate = calendar.date(byAdding: .hour, value: 24, to: Date())
        let token = FamilyJoinToken(family: try requireID(), value: [UInt8].random(count: 16).base64.replacingOccurrences(of: "/", with: "-"), expiresAt: expiryDate)
        try await token.save(on: app.db)
        return URL(string: "http://check.paytondev.me/family/join/\(token.value)")!
    }
}

struct CreateFamilyJoinToken: Migration {
    func prepare(on database: any Database) -> EventLoopFuture<Void> {
        database.schema(FamilyJoinToken.schema)
            .field("id", .uuid, .identifier(auto: true))
            .field("family_id", .uuid, .references(CIFamilyModel.schema, "id"))
            .field("value", .string,.required)
            .unique(on: "value")
            .field("created_at", .datetime, .required)
            .field("expires_at", .datetime)
            .create()
    }
    func revert(on database: any Database) -> EventLoopFuture<Void> {
        database.schema(FamilyJoinToken.schema).delete()
    }
}

struct CreateTokens: Migration {
    func prepare(on database: any Database) -> EventLoopFuture<Void> {
        database.schema(Token.schema)
            .field("id", .uuid, .identifier(auto: true))
            .field("user_id", .uuid, .references("users", "id"))
            .field("value", .string, .required)
            .unique(on: "value")
            .field("source", .int, .required)
            .field("created_at", .datetime, .required)
            .field("expires_at", .datetime)
            .create()
    }
    func revert(on database: any Database) -> EventLoopFuture<Void> {
        database.schema(Token.schema).delete()
    }
}



extension Token: ModelTokenAuthenticatable {
    static let valueKey = \Token.$value
    static let userKey = \Token.$user
    var isValid: Bool {
        guard let expiryDate = expiresAt else {
            return true
        }
        print(expiryDate, expiryDate > Date())
        return expiryDate > Date()
    }
}

extension OBUserModel: ModelAuthenticatable {
    static var usernameKey: KeyPath<OBUserModel, Field<String>> = \OBUserModel.$email
    
    static var passwordHashKey: KeyPath<OBUserModel, Field<String>> = \OBUserModel.$password
    
    
    func verify(password: String) throws -> Bool {
        print("verifying \(password)")
        if self.authProvider == .emailAndPassword {
            return try Bcrypt.verify(password, created: self.password)
        } else {
            return false
        }
    }
    
    func createToken(source: SessionSource) throws -> Token {
        let calendar = Calendar(identifier: .gregorian)
        let expiryDate = calendar.date(byAdding: .year, value: 1, to: Date())
        return try Token(userId: requireID(), token: [UInt8].random(count: 16).base64.replacingOccurrences(of: "/", with: "-"), source: source, expiresAt: expiryDate)
    }
    
    func createPasswordResetToken() throws -> PasswordResetToken {
        let calendar = Calendar(identifier: .gregorian)
        let expiryDate = calendar.date(byAdding: .hour, value: 1, to: Date())
        return try PasswordResetToken(userID: requireID(), token: [UInt8].random(count: 32).base64.replacingOccurrences(of: "/", with: "-"), expiresAt: expiryDate)
    }
}

