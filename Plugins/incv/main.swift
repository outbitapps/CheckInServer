//
//  File.swift
//  
//
//  Created by Payton Curry on 3/31/24.
//

import Foundation
import PackagePlugin

@main
struct VersionNumberPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        print("workdir \(context.package.directory.string), \(URL(string: context.package.directory.appending(["Sources/App","version.json"]).string)!)")
            
            let data = try Data(contentsOf: URL(string: "file://\(context.package.directory.appending(["Sources/App","version.json"]).string)")!)
                var versionInfo = try JSONDecoder().decode(VersionInfo.self, from: data)
        if arguments.contains("--build-inc") {
            versionInfo.buildNumber += 1
        }
        if arguments.contains("--version-inc") {
            versionInfo.versionNumber += 1
        }
                    print("v\(versionInfo.versionNumber)b\(versionInfo.buildNumber)")
                    let versionData = try! JSONEncoder().encode(versionInfo)
                    try! versionData.write(to: URL(string: "file://\(context.package.directory.appending(["Sources/App","version.json"]).string)")!)
    }
}
struct VersionInfo: Codable {
    var versionNumber: Double
    var buildNumber: Int
}
