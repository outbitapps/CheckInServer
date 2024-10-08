import Fluent
import FluentSQLiteDriver
import Leaf
import Vapor
// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    // register routes
//    app.logger.logLevel = .debug
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.jwt.signers.use(.hs256(key: "e2555f61-27c9-4593-acc3-d6510387be48"))
    app.jwt.apple.applicationIdentifier = "com.paytondeveloper.SharedQueue"
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    app.migrations.add(CreateUserModel())
    app.migrations.add(CreateTokens())
    app.migrations.add(CreatePasswordTokens())
    try app.register(collection: UserRoutes())
    app.views.use(.leaf)
    
    try routes(app)
    app.routes.defaultMaxBodySize = 1000000
}

