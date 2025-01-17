import ArgumentParser
import Foundation

struct UpdateCommand: ParsableCommand {

    static var configuration = CommandConfiguration(commandName: "update", abstract: "Updates dependencies")

    @Option(help: "Dependency to skip") private var skip: [String] = []
    @Argument(help: "Path of the swift package") var folder: String = "."
    @ArgumentParser.Flag(help: "Do not change version requirements in the Package.swift file.") private var keepRequirements = false

    func run() throws {
        let folder = URL(fileURLWithPath: folder)
        guard folder.hasDirectoryPath else {
            print("Folder argument must be a directory.".red)
            throw ExitCode.failure
        }
        do {
            var dependencies = try Dependency.loadDependencies(from: folder)
            dependencies = dependencies.filter { dependency in
                !skip.contains(where: { $0.lowercased() == dependency.name.lowercased() })
            }
            dependencies = dependencies.filter { $0.update != nil && $0.update != .skipped }
            if keepRequirements {
                dependencies = dependencies.filter {
                    if case .withChangingRequirements = $0.update {
                        return false
                    } else {
                        return true
                    }
                }
            }
            if dependencies.isEmpty {
                print("Everything is already up-to-date!".green)
            } else {
                try dependencies.forEach {
                    do {
                        try $0.update(in: folder)
                    } catch let SwiftPackageError.resultCountMismatch(name, count) where count == 0 { // false positive, count is an integer swiftlint:disable:this empty_count
                        print("Warning: Could not find version requirement for \(name) in Package.swift - " +
                              "this could be due to the dependency only beeing required on a specific platform.".yellow)
                    } catch {
                        throw error
                    }
                }
            }
        } catch {
            print(error.localizedDescription.red)
            throw ExitCode.failure
        }
    }

}
