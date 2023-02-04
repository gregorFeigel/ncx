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
import SwiftNetCDF
 
class FileIO {
    
    init(urls: [URL], date: Date) {
        self.urls = urls
        self.date = date
    }
    
    var urls:  [URL]
    var date: Date
    
    func dump() async throws {
        for url in urls {
            
            let file = try NetCDF.open(path: url.path, allowUpdate: false)
            var container: [[String]] = []

            let variables: [String] = file?.getVariables().compactMap { v in
                return v.name
            } ?? []
            
            var firstTimestamp: String = "-"
            var lastTimestamp: String = "-"
            var timeSteps: String = "-"

            // list all varaibles and their count
            for (i,n) in variables.enumerated() {
                let variable = file!.getVariable(name: n)
                container.append([n, "-", "-", "-", "-", "-"])
                // get variable
                if let count = variable?.count { container[i][1] = String(count) }
                
                if let contet = variable?.asType(Double.self) {
                    var nanCount: Int = 0
                    let content: [Double] = try contet.read()
                    
                    // get average
                    let sum = content.compactMap({ b in
                        if !b.isNaN {
                            if b < -9999.000 { nanCount += 1 }
                            return b
                        }
                        else { nanCount += 1; return nil }
                    })
                    container[i][2] = String(format: "%.3f", (sum.reduce(0, +) / Double(sum.count)))
                    
                    // get min and max
                    container[i][3] = String(sum.min() ?? -9999)
                    container[i][4] = String(sum.max() ?? -9999)
                    
                    // get error count
                    container[i][5] = String(nanCount)
                }
                else if let contet = variable?.asType(Float.self) {
                    var nanCount: Int = 0
                    let content: [Float] = try contet.read()
                    
                    // get average
                    let sum = content.compactMap({ b in
                        if !b.isNaN {
                            if b < -9999.000 { nanCount += 1 }
                            return b
                        }
                        else { nanCount += 1; return nil }
                    })
                    container[i][2] = String(format: "%.3f", (sum.reduce(0, +) / Float(sum.count)))
                    
                    // get min and max
                    container[i][3] = String(sum.min() ?? -9999)
                    container[i][4] = String(sum.max() ?? -9999)
                    
                    // get error count
                    container[i][5] = String(nanCount)
                }

                if n == "time", let vari = variable?.asType(Int64.self) {
                    let content = try vari.read().compactMap({ Int64($0) })
                    timeSteps = String(content[1] - content[0])
                    if let first = content.first, let last = content.last {
                         firstTimestamp = date(Double(first))
                         lastTimestamp = date(Double(last))
                    }
                }
                else if n == "time", let vari = variable?.asType(Float.self) {
                    let content = try vari.read().compactMap({ Int64($0) })
                    timeSteps = String(content[1] - content[0])
                     if let first = content.first, let last = content.last {
                         firstTimestamp = date(Double(first))
                         lastTimestamp = date(Double(last))
                    }
                }
                else if n == "time", let vari = variable?.asType(Double.self) {
                    let content = try vari.read().compactMap({ Int64($0) })
                    timeSteps = String(content[1] - content[0])
                     if let first = content.first, let last = content.last {
                         firstTimestamp = date(Double(first))
                         lastTimestamp = date(Double(last))
                    }
                }
             }
            
            // first and last timestamp
            print()
            print("[ Time ] begin:", firstTimestamp)
            print("[ Time ] end:  ", lastTimestamp)
            print("[ Time ] stepsize: ", timeSteps)
            print()
            print("Dimensions:")
            if let dims = file?.getDimensions() {
                for n in dims {
                    print(" -", n.name)
                }
            }
            
            print()
            table_of_content(container, tableHeader: "Values", "Count", "Average", "Min", "Max" ,"NaN & Err")
        }

    }
    
    func table_of_content(_ data: [[String]], tableHeader: String...)  {
        // create table header counts
        var counts: [Int] = tableHeader.map { header -> Int in
            return header.count
        }
        
        // write variable names
        for n in data {
            // get size for sub values
            for (i, x) in n.enumerated() {
                if counts[i] < x.count {  counts[i] = x.count }
            }
        }
        //print("\n")
        defer { print("\n") }
        
        // table header
        for (i,n) in tableHeader.enumerated() {
            if i != 0 { print(" | ", terminator: "") }
            print(n, terminator: "")
            spacing(index: i, value: n, spacer: " ")
        }
        print("\n", terminator: "")
        
        for (i,_) in tableHeader.enumerated() {
            spacing(index: i, value: "", spacer: "-")
            if i != tableHeader.count - 1 {  print("-|-", terminator: "") }
        }
        print("\n", terminator: "")

        // table content
        for n in data {
            for (ii, x) in n.enumerated() {
                if ii != 0 { print(" | ", terminator: "") }
                print(x, terminator: "")
                spacing(index: ii, value: x, spacer: " ")
            }
            print("\n", terminator: "")
        }

         func spacing(index: Int, value: String, spacer: String) {
            let valueSpacer = (counts[index]) - value.count
            if valueSpacer > 0 {
                for _ in 1...valueSpacer {  print(spacer, terminator: "") }
            }
        }
    }
    
    func gplot(name: String) async throws {
        for url in urls {
            let file = try NetCDF.open(path: url.path, allowUpdate: false)
            let variable = file?.getVariable(name: name)
            if let vari = variable?.asType(Double.self) {
                let content = try vari.read().compactMap({ $0.isNaN ? nil : $0 })
                 print()
                 await plot(values: content)
                 print()
            }
        }
    }
    
    func plot(values data: [Double]) async {
        
        let height: Int = 24//20
        let width:  Int = 100//90
        
        var matrix: [[String]] = []
        
        let baseline = Array(repeating: " ", count: width)
        matrix = Array(repeating: ["|"] + baseline, count: height)
        matrix.append(Array(repeating: "-", count: width))
        // calucate data
        // template data
        //let template: [Double] = [0, 5, 10, 15, 10, 5, 0, 5, 10, 15, 10, 5, 0]
        
        var values = data
        if data.count > width {
            values = data.movingAverage(sectionSize: Int(data.count / width))
        }
        
        let min: Double = values.min() ?? 0
        let max: Double = values.max() ?? 1
        
        // normalise data
        var nomalised = values.map { (1 - ($0 - min) / (max - min)) }
        if nomalised.count < width { nomalised = interpolate(width: width, data: nomalised) }
        while nomalised.count > width {
            nomalised.removeLast()
        }
        // calculate points
        for (i,n) in nomalised.enumerated() {
            let value = Double(height - 1) * n
            matrix[Int(value)][i + 1] = "•"
        }
        
        // print matrix
        for n in matrix {
            print(n.joined(separator: ""))
        }
        
    }
    
    func date(_ number: Double) -> String {
        let date = Date(timeInterval: number, since: date)
        return date.getDateFormattedBy("dd.MM.yyyy HH:mm:ss")
    }
    
    func interpolate(width: Int, data: [Double]) -> [Double] {
        let step_size: Int = Int(width / data.count)
        var new: [Double] = []
        for n in data {
            new.append(contentsOf: Array(repeating: n, count: step_size))
        }
        return new
    }
    
}


