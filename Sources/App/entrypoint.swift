import Vapor
import Logging



var app: Application!
@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        app = Application(env)
        defer { app.shutdown() }
        var data = try? JSONDecoder().decode(VersionInfo.self, from: (try? Data(contentsOf: Bundle.module.url(forResource: "version", withExtension: "json") ?? URL(string: "file://ex.txt")!)) ?? Data())
        
        do {
            try await configure(app)
            print("Running Outbit Server v\(data?.versionNumber ?? 0.0)b\(data?.buildNumber ?? 0)")
        } catch {
            app.logger.report(error: error)
            throw error
        }
        try await app.execute()
    }
}

struct VersionInfo: Codable {
    var versionNumber: Double
    var buildNumber: Int
}
