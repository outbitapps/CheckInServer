import Fluent
import FluentSQLiteDriver
import Leaf
import Vapor
import FCM

var hostname = Environment.get("domain") ?? "check.paytondev.cloud"
// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    // register routes
//    app.logger.logLevel = .debug
    app.http.server.configuration.port = 80
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.jwt.signers.use(.hs256(key: "e2555f61-27c9-4593-acc3-d6510387be48"))
    app.jwt.apple.applicationIdentifier = "com.paytondeveloper.SharedQueue"
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    app.migrations.add(CreateUserModel())
    app.migrations.add(CreateFamilyModel())
    app.migrations.add(CreateFamilyJoinToken())
    app.migrations.add(CreateTokens())
    app.migrations.add(CreatePasswordTokens())
    app.migrations.add(CreateCISession())
    app.fcm.configuration = .envServiceAccountKey
    try app.register(collection: UserRoutes())
    try app.register(collection: FamilyRoutes())
    app.views.use(.leaf)
    
    try routes(app)
    app.routes.defaultMaxBodySize = 1000000
}

