import Vapor
import Leaf
import Fluent
import MapboxDirections

let directions = Directions(credentials: Credentials(accessToken: "sk.eyJ1IjoicGF5dG9uZGV2IiwiYSI6ImNtMjd3eGE2dTFsc3Yyam9oaGN3ajU4Y2UifQ.oZElYBFR-qFRxGuaLQCZug"))

func routes(_ app: Application) throws {
    app.get("server-version") { req in
        let data = try? JSONDecoder().decode(VersionInfo.self, from: (try? Data(contentsOf: Bundle.module.url(forResource: "version", withExtension: "json") ?? URL(string: "file://ex.txt")!)) ?? Data())
        if let data = data {
            return "v\(data.versionNumber)b\(data.buildNumber)"
        }
        return "couldn't get version info :("
    }
}


