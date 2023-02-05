//===----------------------------------------------------------------------===//
//
// This source file is part of the ncx project
//
// Copyright (c) 2022 Gregor Feigel.
//
// See README.md for more information
//
//===----------------------------------------------------------------------===//

import Foundation
import ArgumentParser

@main struct NCX_Tool: AsyncParsableCommand {
    
    @Argument(help: "The input .nc file.",
              completion: .file(extensions: [".nc"]), transform: URL.init(fileURLWithPath:))
    var inputFile: [URL] = []
    
    @Flag() var dump: Bool = false
    @Flag() var gdump: Bool = false
    @Flag() var convert_type: Bool = false
    @Flag(name: .shortAndLong, help: "force") var force: Bool = false


    @Option(help: "Reference date. Timeinterval [sec] since <date>.",
            transform: { $0.toDate(format: "yyyy-MM-dd'T'HH:mm:ssZ") ?? .init(timeIntervalSince1970: 0) }   )
            var date: Date = .init(timeIntervalSince1970: 0)
    
    @Option(help: "Varibale to plot.") var var_name: String = ""
    
    @Option(help: "Varibale type to convert from.") var from_type: NetCDF_Values = .float
    @Option(help: "Varibale type to convert to.") var to_type: NetCDF_Values = .float
    
    @Option(help: "Varibale type to drop.") var drop: [String] = []
    
    var files: [URL] {
        get throws {
            let data = try FileHandle.standardInput.readToEnd()
            let str = String(data: data!, encoding: .utf8)
            return (str?.components(separatedBy: [" ", "\n"]).compactMap({ str -> URL in
                return URL(fileURLWithPath: str)
            }))!
        }
    }

}

extension NCX_Tool {
    mutating func run() async throws {
        // read from pipe if no data is enterd
        if inputFile.isEmpty { inputFile = try files }
        
        let file = FileIO(urls: inputFile, date: date)
        if dump { try await file.dump() }
        else if gdump { try await file.gplot(name: var_name) }
        else if !drop.isEmpty { try file.drop(var_names: drop, force: force) }
     }
}

enum NetCDF_Values: String, Codable, ExpressibleByArgument {
    case int16 = "int16"
    case int32 = "int32"
    case int64 = "int64"
    case float = "float"
    case float64 = "float64"
}
