import Foundation
import XCTest

extension XCTestCase {

    func temporaryFileURL(in folder: URL? = nil, name: String? = nil) -> URL {
        let directory = NSTemporaryDirectory()
        let url = (folder ?? URL(fileURLWithPath: directory)).appendingPathComponent(name ?? UUID().uuidString)

        addTeardownBlock {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    XCTFail("Error deleting temporary file: \(error)")
                }
            }
            XCTAssertFalse(fileManager.fileExists(atPath: url.path))
        }

        return url
    }

    func createFile(at url: URL, content: String) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Error writing temporary file: \(error)")
        }
    }

    func emptyFileURL() -> URL {
        let url = temporaryFileURL()
        createFile(at: url, content: "\n")
        return url
    }

    func emptyFolderURL() -> URL {
        let folder = temporaryFileURL()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            XCTFail("Error writing creating folder: \(error)")
        }
        return folder
    }

    func folderURL(packageContent: String?, packageResolvedContent: String?) -> URL {
        let folder = emptyFolderURL()

        if let packageContent = packageContent {
            let packageFile = temporaryFileURL(in: folder, name: "Package.swift")
            createFile(at: packageFile, content: packageContent)
        }

        if let packageResolvedContent = packageResolvedContent {
            let resolvedFile = temporaryFileURL(in: folder, name: "Package.resolved")
            createFile(at: resolvedFile, content: packageResolvedContent)
        }

        return folder
    }

    func createEmptySwiftPackage() -> URL {
        let folder = folderURL(packageContent: TestUtils.emptyPackageSwiftFileContent, packageResolvedContent: TestUtils.packageResolvedV2FileContent)
        let sourceFile = temporaryFileURL(in: folder.appendingPathComponent("Sources/Name"), name: "Name.swift")
        createFile(at: sourceFile, content: "")

        return folder
    }


    func assert<T, E: Error & Equatable>(_ expression: @autoclosure () throws -> T, throws expectedError: E, in file: StaticString = #file, line: UInt = #line) {
        var caughtError: Error?

        XCTAssertThrowsError(try expression(), file: file, line: line) {
            caughtError = $0
        }

        guard let error = caughtError as? E else {
            XCTFail("Unexpected error type, got \(type(of: caughtError!)) instead of \(E.self)", file: file, line: line)
            return
        }

        XCTAssertEqual(error, expectedError, file: file, line: line)
    }

    func assert<T, E: Error & Equatable>(_ expression: @autoclosure () throws -> T, throws expectedErrors: [E], in file: StaticString = #file, line: UInt = #line) {
        var caughtError: Error?

        XCTAssertThrowsError(try expression(), file: file, line: line) {
            caughtError = $0
        }

        guard let error = caughtError as? E else {
            XCTFail("Unexpected error type, got \(type(of: caughtError!)) instead of \(E.self)", file: file, line: line)
            return
        }

        XCTAssert(expectedErrors.contains(error), "Received \(error) instead of expected error", file: file, line: line)
    }

}
