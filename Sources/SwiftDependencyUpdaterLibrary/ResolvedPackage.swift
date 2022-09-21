import Foundation
import Releases
import ShellOut

struct ResolvedVersion: Decodable {

    enum CodingKeys: String, CodingKey {
        case branch
        case revision
        case version
    }

    let branch: String?
    let revision: String
    let version: Version?

    public var versionNumberOrRevision: String {
        version.map { $0.string } ?? revision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        branch = try? container.decode(String?.self, forKey: .branch)
        revision = try container.decode(String.self, forKey: .revision)
        if let versionString = try? container.decode(String?.self, forKey: .version) {
            version = try Version(string: versionString)
        } else {
            version = nil
        }
    }
}

protocol ResolvedDependency {
    var name: String { get }
    var url: URL { get }
    var version: ResolvedVersion { get }
}

enum ResolvedPackageError: Error, Equatable {
    case resolvingFailed(String)
    case readingFailed(String)
    case parsingFailed(String, String)
}

struct ResolvedPackage {
    // Representation of a Package.resolved file
    // The format is defined in https://github.com/apple/swift-package-manager/blob/main/Sources/PackageGraph/PinsStore.swift

    private struct V1: Decodable {
        static let version = 1

        struct Container: Decodable {
            struct Pin: ResolvedDependency, Decodable {
                enum CodingKeys: String, CodingKey {
                    case name = "package"
                    case url = "repositoryURL"
                    case version = "state"
                }

                let name: String
                let url: URL
                let version: ResolvedVersion
            }

            let pins: [Pin]
        }

        let object: Container
    }

    private struct V2: Decodable {
        static let version = 2

        struct Pin: ResolvedDependency, Decodable {
            enum CodingKeys: String, CodingKey {
                case name = "identity"
                case url = "location"
                case version = "state"
            }

            let name: String
            let url: URL
            let version: ResolvedVersion
        }

        let pins: [Pin]
    }

    let dependencies: [ResolvedDependency]
}

extension ResolvedPackage: Decodable {
    private enum CodingKeys: String, CodingKey {
        case version
    }

    private struct InvalidVersionError: LocalizedError {
        let version: Int

        var errorDescription: String? {
            "Unsupported resolved package version \(version)"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)

        switch version {
        case V1.version:
            self.dependencies = try V1(from: decoder).object.pins
        case V2.version:
            self.dependencies = try V2(from: decoder).pins
        default:
            throw InvalidVersionError(version: version)
        }
    }
}

extension ResolvedPackage {
    static func resolveAndLoadResolvedPackage(from folder: URL) throws -> ResolvedPackage {
         do {
            try shellOut(to: "swift", arguments: ["package", "--package-path", "\"\(folder.path)\"", "resolve" ])
        } catch {
            let error = error as! ShellOutError // swiftlint:disable:this force_cast
            throw ResolvedPackageError.resolvingFailed(error.message)
        }
        return try loadResolvedPackage(from: folder)
    }

    static func loadResolvedPackage(from folder: URL) throws -> ResolvedPackage {
        let data = try readResolvedPackageData(from: folder)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ResolvedPackage.self, from: data)
        } catch {
            throw ResolvedPackageError.parsingFailed(error.localizedDescription, String(decoding: data, as: UTF8.self))
        }
    }

    private static func readResolvedPackageData(from folder: URL) throws -> Data {
        let resolvedPackage = folder.appendingPathComponent("Package.resolved", isDirectory: false)
        do {
            let contents = try Data(contentsOf: resolvedPackage)
            return contents
        } catch {
            throw ResolvedPackageError.readingFailed(error.localizedDescription)
        }
    }
}

extension ResolvedPackageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .resolvingFailed(error):
            return "Running swift package resolved failed: \(error)"
        case let .readingFailed(error):
            return "Could not read Package.resolved file: \(error)"
        case let .parsingFailed(error, packageData):
            return "Could not parse package data: \(error)\n\nPackage Data: \(packageData)"
        }
    }
}

extension ResolvedVersion: CustomStringConvertible {
    public var description: String {
        if let version = version {
            return "\(version) (\(revision)\(branch != nil ? ", branch: \(branch!)" : ""))"
        } else {
            return "\(revision)\(branch != nil ? " (branch: \(branch!))" : "")"
        }
    }
}
