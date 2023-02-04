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
    
    @Option(help: "Reference date. Timeinterval [sec] since <date>.",
            transform: { $0.toDate(format: "yyyy-MM-dd'T'HH:mm:ssZ") ?? .init(timeIntervalSince1970: 0) }   )
            var date: Date = .init(timeIntervalSince1970: 0)
    
    @Option(help: "Varibale to plot.") var var_name: String = ""
 
}

extension NCX_Tool {
    func run() async throws {
        if dump { try await FileIO(urls: inputFile, date: date).dump() }
        else if gdump { try await FileIO(urls: inputFile, date: date).gplot(name: var_name) }
    }
}
