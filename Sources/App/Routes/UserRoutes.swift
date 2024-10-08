//
//  File.swift
//
//
//  Created by Payton Curry on 4/13/24.
//

import Foundation
import Vapor
import JWT
import Fluent

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension UserSignup: Content {}
extension NewSession: Content {}

extension UserSignup: Validatable {
    public static func validations(_ validations: inout Vapor.Validations) {
        validations.add("username", as: String.self, is: .alphanumeric)
        validations.add("password", as: String.self, is: !.empty)
        validations.add("email", as: String.self, is: !.empty)
    }
}

class UserRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let usersRoute = routes.grouped("users")
        usersRoute.post("signup") { req in
            let signup = try JSONDecoder().decode(UserSignup.self, from: req.body.data!)
            if signup.email.isEmpty || signup.password.isEmpty || signup.username.contains(" ") {
                throw Abort(.notAcceptable)
            }
//            print("new signup \(data)")
            let userModel = OBUserModel(id: UUID(), username: signup.username, email: signup.email.lowercased(), password: try Bcrypt.hash(signup.password))
            if !(try await OBUserModel.userAlreadyExists(userModel, database: req.db)) {
                let token = try userModel.createToken(source: .signup)
                try await userModel.save(on: req.db)
                try await token.save(on: req.db)
                return await NewSession(token: token.value, user: try userModel.asOBUser())
            } else {
                throw Abort(.conflict)
            }
        }

        usersRoute.post("pwresetemail", ":email") { req async throws -> HTTPStatus in
            if let email = req.parameters.get("email") {
                let usersEmail = try await OBUserModel.query(on: req.db).filter(\OBUserModel.$email == email.lowercased()).all()
                if usersEmail.count > 0 {
                    let user = usersEmail[0]
                    let token = try user.createPasswordResetToken()
                    try await token.save(on: req.db)
                    let apikey = "mlsn.d7c79076b637842c37990cd29836d81970f9a8788894b6f9629038a51180a5dd"
                    let requestBody: [String: Any] = [
                        "from": ["email": "noreply@ob.paytondev.cloud"],
                        "to": [["email": user.email]],
                        "personalization": [["email": user.email, "data": ["resetURL": "http://\(app.http.server.configuration.hostname):8080/users/reset-password/\(token.value)"]]],
                        "template_id":"jy7zpl9m3x3g5vx6",
                        "subject":"Outbit Password Reset"
                    ]
                    let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

                    // Prepare the request
                    let url = URL(string: "https://api.mailersend.com/v1/email")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
                    request.setValue("Bearer \(apikey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = jsonData
                    let (data, res) = try await URLSession(configuration: .default).data(for: request)
                    print(String(data: data, encoding: .utf8))
                    return HTTPStatus(statusCode: 200)
                } else {
                    throw Abort(.notFound)
                }
            } else {
                throw Abort(.badRequest)
            }
        }
        usersRoute.get("reset-password", ":token") { req async throws in
            return try await req.view.render("PasswordReset", ["token": req.parameters.get("token") ?? "its_fucked", "hostname":"\(app.http.server.configuration.hostname)"])
        }
        usersRoute.post("pwresetrequest", ":token") { req async throws -> HTTPStatus in
            if let token = req.parameters.get("token"), let authorization = req.headers.basicAuthorization?.password {
                print(token, authorization)
                let pwrequests = try await PasswordResetToken.query(on: req.db).filter(\PasswordResetToken.$value == token).all()
                print(pwrequests)
                if pwrequests.count > 0 {
                    let pwrequest = pwrequests[0]
                    if pwrequest.expiresAt! > Date() {
                        let userID = pwrequest.$user.$id.wrappedValue
                        let users = try await OBUserModel.query(on: req.db).filter(\OBUserModel.$id == userID).all()
                        print(users, userID)
                        if users.count > 0 {
                            let user = users[0]
                            print(user.password)
                            user.password = try Bcrypt.hash(authorization)
                            print(user.password)
                            try await user.update(on: req.db)
                            try await pwrequest.delete(on: req.db)
                            return HTTPStatus(statusCode: 200)
                        } else {
                            throw Abort(.notFound)
                        }
                    } else {
                        throw Abort(.expectationFailed)
                    }
                    try await pwrequest.delete(on: req.db)
                } else {
                    throw Abort(.notFound)
                }
            } else {
                throw Abort(.badRequest)
            }
            return HTTPStatus(statusCode: 500)
        }
        let passwordProtected = usersRoute.grouped(OBUserModel.authenticator())
        passwordProtected.put("login") { req in
            print(req.headers.basicAuthorization)
            let user = try req.auth.require(OBUserModel.self)
            if user.authProvider == .emailAndPassword {
                let token = try user.createToken(source: .login)
                
                try await token.save(on: req.db)
                return await NewSession(token: token.value, user: try user.asOBUser())
            } else {
                print(user.authProvider)
                throw Abort(.unauthorized)
            }
        }
        let tokenProtected = usersRoute.grouped(Token.authenticator())
        tokenProtected.get("fetch-user") { req in
            print("fetch users req")
            return try await req.auth.require(OBUserModel.self).asOBUser(database: req.db)
        }
        tokenProtected.get("validate-token") { req in
            return try await req.auth.require(OBUserModel.self).asOBUser(database: req.db)
        }
    }
    
}

extension OBUser: Content {}

struct PWResetData: Codable {
    var resetURL: String
}

public enum URLSessionAsyncErrors: Error {
    case invalidUrlResponse, missingResponseData
}
