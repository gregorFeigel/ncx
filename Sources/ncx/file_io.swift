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
    
    // MARK: Print a table of the file content
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
                let var_type: String = get_variable_type(vari: variable!) + " "
                            //    name            unit count avg min  max  err
                container.append([(var_type + n), "-", "-", "-", "-", "-", "-"])
                // get variable
                if let count = variable?.count { container[i][2] = String(count) }
                container[i][1] = try get_variable_unit(vari: variable!)
                
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
                    container[i][3] = String(format: "%.3f", (sum.reduce(0, +) / Double(sum.count)))
                    
                    // get min and max
                    container[i][4] = String(sum.min() ?? -9999)
                    container[i][5] = String(sum.max() ?? -9999)
                    
                    // get error count
                    container[i][6] = String(nanCount)
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
                    container[i][3] = String(format: "%.3f", (sum.reduce(0, +) / Float(sum.count)))
                    
                    // get min and max
                    container[i][4] = String(sum.min() ?? -9999)
                    container[i][5] = String(sum.max() ?? -9999)
                    
                    // get error count
                    container[i][6] = String(nanCount)
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
            print("[ File ]", url.lastPathComponent)
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
            table_of_content(container, tableHeader: "Values", "Unit", "Count", "Average", "Min", "Max" ,"NaN & Err")
        }
        
    }
    
    internal func get_variable_type(vari: Variable) -> String {
        switch vari.type.asExternalDataType() {
            case .none:          return "(---)"
            case .some(.float):  return "(f32)"
            case .some(.byte):   return "(byte)"
            case .some(.char):   return "(char)"
            case .some(.short):  return "(i16)"
            case .some(.int32):  return "(i32)"
            case .some(.double): return "(f64)"
            case .some(.ubyte):  return "(ubyt)"
            case .some(.ushort): return "(ui16)"
            case .some(.uint32): return "(ui32)"
            case .some(.int64):  return "(i64)"
            case .some(.uint64): return "(ui64)"
            case .some(.string): return "(str)"
        }
    }
    
    internal func get_variable_unit(vari: Variable) throws -> String {
        for n in try vari.getAttributes() where n.name == "units" {
            switch n.type.asExternalDataType() {
                case .none:         break
                case .some(.float): break
                case .some(.byte):  break
                case .some(.char):
                    var x: [UInt8] = try n.read() ?? []
                    return String(data: Data(x), encoding: .utf8) ?? "err"
                case .some(.short):  break
                case .some(.int32):  break
                case .some(.double): break
                case .some(.ubyte):  break
                case .some(.ushort): break
                case .some(.uint32): break
                case .some(.int64):  break
                case .some(.uint64): break
                case .some(.string):
                    let x: [String] = try n.read() ?? []
                    return x.joined(separator: "; ")
            }
        }
        return "-"
    }
    
    internal func table_of_content(_ data: [[String]], tableHeader: String...)  {
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
    
    // MARK: Graphic plot
    func gplot(name: String) async throws {
        for url in urls {
            let file = try NetCDF.open(path: url.path, allowUpdate: false)
            let variable = file?.getVariable(name: name)
            if let vari = variable?.asType(Double.self) {
                let content = try vari.read().compactMap({ $0.isNaN ? nil : $0 })
                print()
                print("[ File ]", url.lastPathComponent)
                print()
                await plot(values: content)
                print()
            }
        }
    }
    
    internal func plot(values data: [Double]) async {
        
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
    
    internal func date(_ number: Double) -> String {
        let date = Date(timeInterval: number, since: date)
        return date.getDateFormattedBy("dd.MM.yyyy HH:mm:ss")
    }
    
    internal func interpolate(width: Int, data: [Double]) -> [Double] {
        let step_size: Int = Int(width / data.count)
        var new: [Double] = []
        for n in data {
            new.append(contentsOf: Array(repeating: n, count: step_size))
        }
        return new
    }
    
    func drop(var_names: [String], force: Bool) throws {
        if urls.count != 2  { print("missing input or output file."); exit(1) }
        if urls[0] == urls[1] && force == false { print("Can not write to output to input file. Use -f to override input file"); exit(1) }
        let file = try NetCDF.open(path: urls[0].path, allowUpdate: false)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try copy_file(from: file!, to: tempURL, exclude: var_names)
        try FileManager.default.removeItem(at: urls[1])
        try FileManager.default.moveItem(at: tempURL, to: urls[1])
    }
    
    // MARK: Copy File
    internal func copy_file(from: Group, to: URL, exclude: [String]) throws {
        var new_file = try NetCDF.create(path: to.path, overwriteExisting: true)
        try copy_group(copyFrom: from, to: &new_file, exclude: exclude)
    }

    internal func copy_group(copyFrom file: Group, to new_file: inout Group, exclude: [String]) throws {
        // copy dimensions
        for n in file.getDimensions() {
            _ = try new_file.createDimension(name: n.name, length: n.length, isUnlimited: n.isUnlimited)
        }
        
        for n in file.getVariables() where !exclude.contains(where: { n.name == $0 })  {
            switch n.type.asExternalDataType() {
                case .none: print("[ ERROR ] invalid data type for \(n.name).")
                case .some(.float):
                    var vari = try new_file.createVariable(name: n.name, type: Float.self, dimensions: n.dimensions)
                    try copy_attributes_for_variable(n: n, vari: &vari, t: Float.self)
                    try vari.write((n.asType(Float.self)?.read())!)
                case .some(.byte):
                    var vari = try new_file.createVariable(name: n.name, type: Int8.self, dimensions: n.dimensions)
                    try vari.write((n.asType(Int8.self)?.read())!)
                    try copy_attributes_for_variable(n: n, vari: &vari, t: Int8.self)
                case .some(.char):
                    var vari = try new_file.createVariable(name: n.name, type: Int8.self, dimensions: n.dimensions)
                    try vari.write((n.asType(Int8.self)?.read())!)
                    try copy_attributes_for_variable(n: n, vari: &vari, t: Int8.self)
                case .some(.short):
                    var vari = try new_file.createVariable(name: n.name, type: Int16.self, dimensions: n.dimensions)
                    try vari.write((n.asType(Int16.self)?.read())!)
                    try copy_attributes_for_variable(n: n, vari: &vari, t: Int16.self)
                case .some(.int32):
                    var vari = try new_file.createVariable(name: n.name, type: Int32.self, dimensions: n.dimensions)
                    try vari.write((n.asType(Int32.self)?.read())!)
                    try copy_attributes_for_variable(n: n, vari: &vari, t: Int32.self)
                case .some(.double):
                    var vari = try new_file.createVariable(name: n.name, type: Float64.self, dimensions: n.dimensions)
                    try copy_attributes_for_variable(n: n, vari: &vari, t: Float64.self)
                    try vari.write((n.asType(Float64.self)?.read())!)
                case .some(.ubyte):
                    var vari = try new_file.createVariable(name: n.name, type: UInt8.self, dimensions: n.dimensions)
                    try vari.write((n.asType(UInt8.self)?.read())!)
                    try copy_attributes_for_variable(n: n, vari: &vari, t: UInt8.self)
                case .some(.ushort):
                    var vari = try new_file.createVariable(name: n.name, type: UInt16.self, dimensions: n.dimensions)
                    try vari.write((n.asType(UInt16.self)?.read())!)
                    try copy_attributes_for_variable(n: n, vari: &vari, t: UInt16.self)
                case .some(.uint32):
                    var vari = try new_file.createVariable(name: n.name, type: UInt32.self, dimensions: n.dimensions)
                    try vari.write((n.asType(UInt32.self)?.read())!)
                    try copy_attributes_for_variable(n: n, vari: &vari, t: UInt32.self)
                case .some(.int64):
                    var vari = try new_file.createVariable(name: n.name, type: Int64.self, dimensions: n.dimensions)
                    try vari.write((n.asType(Int64.self)?.read())!)
                    try copy_attributes_for_variable(n: n, vari: &vari, t: Int64.self)
                case .some(.uint64):
                    var vari = try new_file.createVariable(name: n.name, type: UInt64.self, dimensions: n.dimensions)
                    try vari.write((n.asType(UInt64.self)?.read())!)
                    try copy_attributes_for_variable(n: n, vari: &vari, t: UInt64.self)
                case .some(.string):
                    var vari = try new_file.createVariable(name: n.name, type: String.self, dimensions: n.dimensions)
                    try copy_attributes_for_variable(n: n, vari: &vari, t: String.self)
                    try vari.write((n.asType(String.self)?.read())!)
            }
        }

        try copy_attributes_for_group(n: file, vari: &new_file)
        
        for n in file.getGroups() {
            var group = try file.createGroup(name: n.name)
            for c in n.getDimensions() {
                _ = try group.createDimension(name: c.name, length: c.length, isUnlimited: c.isUnlimited)
            }
            try copy_group(copyFrom: n.group, to: &group, exclude: exclude)
            try copy_attributes_for_group(n: file, vari: &new_file)
        }
    }

    internal func copy_attributes_for_variable<T: NetcdfConvertible>(n: Variable, vari: inout VariableGeneric<T>, t: T.Type) throws {
        for p in try n.getAttributes() {
            switch p.type.asExternalDataType() {
                case .none: print("[ ERROR ] while reading data from attribute of \(vari.variable.name)")
                case .some(.float):
                    let x: [Float] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.byte):
                    let x: [Int8] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.char):
    //                    let x: [CChar] = try p.read() ?? []
    //                    try vari.setAttribute(p.name, x)
                    let x: [UInt8] = try p.read() ?? []
                    let res = String(data: Data(x), encoding: .utf8) ?? "error while copying attribute"
                    try vari.setAttribute(p.name, res)
                case .some(.short):
                    let x: [Int16] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.int32):
                    let x: [Int32] = try p.read() ?? []
                    try vari.setAttribute(p.name, x)
                case .some(.double):
                    let x: [Double] = try p.read() ?? []
                    try vari.setAttribute(p.name, x)
                case .some(.ubyte):
                    let x: [UInt8] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.ushort):
                    let x: [UInt8] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.uint32):
                    let x: [UInt32] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.int64):
                    let x: [Int64] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.uint64):
                    let x: [UInt64] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.string):
                    let x: [String] = try p.read()!
                    try vari.setAttribute(p.name, x)
            }
        }
    }

    internal func copy_attributes_for_group(n: Group, vari: inout Group) throws {
        for p in try n.getAttributes() {
            switch p.type.asExternalDataType() {
                case .none: print("[ ERROR ] while reading data from attribute of \(vari.name)")
                case .some(.float):
                    let x: [Float] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.byte):
                    let x: [Int8] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.char):
                    let x: [UInt8] = try p.read() ?? []
                    let res = String(data: Data(x), encoding: .utf8) ?? "error while copying attribute"
                    try vari.setAttribute(p.name, res)
                case .some(.short):
                    let x: [Int16] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.int32):
                    let x: [Int32] = try p.read() ?? []
                    try vari.setAttribute(p.name, x)
                case .some(.double):
                    let x: [Double] = try p.read() ?? []
                    try vari.setAttribute(p.name, x)
                case .some(.ubyte):
                    let x: [UInt8] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.ushort):
                    let x: [UInt8] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.uint32):
                    let x: [UInt32] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.int64):
                    let x: [Int64] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.uint64):
                    let x: [UInt64] = try p.read()!
                    try vari.setAttribute(p.name, x)
                case .some(.string):
                    let x: [String] = try p.read()!
                    try vari.setAttribute(p.name, x)
            }
        }
    }

}


 
/*
 // open old NetCDF read var and write it to new NetCDF
 func change_variable(name: String, format_is: NetCDF_Values, format_to: NetCDF_Values) async {
     // check if there are two files
     if urls.count != 2 { print("missing input or output file."); exit(1) }
     // check that format differs
     if format_is == format_to { print("output format must differ from input format."); exit(1) }
     do {
         let file: Group? = try NetCDF.open(path: urls[0].path, allowUpdate: false)
         if let variable = file?.getVariable(name: name) {
             // read data
             switch format_is {
                 case .int16:
                     if let values: [Int16] = try variable.asType(Int16.self)?.read() {
                         switch format_to {
                             case .int16: break
                             case .int32:
                                 let new_values: [Int32] = values.map({ Int32($0) })
                                 try await copyFile(file: file!, var_name: name, type: Int32.self, data: new_values, from: urls[0],to: urls[1])
                             case .int64:
                                 let new_values: [Int64] = values.map({ Int64($0) })
                                 try await copyFile(file: file!, var_name: name, type: Int64.self, data: new_values, from: urls[0],to: urls[1])
                             case .float:
                                 let new_values: [Float32] = values.map({ Float32($0) })
                                 try await copyFile(file: file!, var_name: name, type: Float32.self, data: new_values, from: urls[0],to: urls[1])
                             case .float64:
                                 let new_values: [Float64] = values.map({ Float64($0) })
                                 try await copyFile(file: file!, var_name: name, type: Float64.self, data: new_values, from: urls[0],to: urls[1])
                         }
                     }
                 case .int32:
                     if let values: [Int32] = try variable.asType(Int32.self)?.read() {
                         switch format_to {
                             case .int16:
                                 let new_values: [Int16] = values.map({ Int16($0) })
                                 try await copyFile(file: file!, var_name: name, type: Int16.self, data: new_values,from: urls[0],to: urls[1])
                             case .int32: break
                             case .int64:
                                 let new_values: [Int64] = values.map({ Int64($0) })
                                 try await copyFile(file: file!, var_name: name, type: Int64.self, data: new_values,  from: urls[0],to: urls[1])
                             case .float:
                                 let new_values: [Float32] = values.map({ Float32($0) })
                                 try await copyFile(file: file!, var_name: name, type: Float32.self, data: new_values, from: urls[0], to: urls[1])
                             case .float64:
                                 let new_values: [Float64] = values.map({ Float64($0) })
                                 try await copyFile(file: file!, var_name: name, type: Float64.self, data: new_values, from: urls[0], to: urls[1])
                         }
                     }
                 case .int64:
                     print("read as int64")
                     if let values: [Int64] = try variable.asType(Int64.self)?.read() {
                         switch format_to {
                             case .int16:
                                 let new_values: [Int16] = values.map({ Int16($0) })
                                 try await copyFile(file: file!, var_name: name, type: Int16.self, data: new_values, from: urls[0], to: urls[1])
                             case .int32:
                                 let new_values: [Int32] = values.map({ Int32($0) })
                                 try await copyFile(file: file!, var_name: name, type: Int32.self, data: new_values, from: urls[0],to: urls[1])
                             case .int64: break
                             case .float:
                                 let new_values: [Float32] = values.map({ Float32($0) })
                                 try await copyFile(file: file!, var_name: name, type: Float32.self, data: new_values, from: urls[0],to: urls[1])
                             case .float64:
                                 let new_values: [Float64] = values.map({ Float64($0) - 1.5 })
                                 print("convert to f64")
                                 try await copyFile(file: file!, var_name: name, type: Float64.self, data: new_values, from: urls[0], to: urls[1])
                         }
                     }
                 case .float:
                     if let values: [Float32] = try variable.asType(Float.self)?.read() {
                         switch format_to {
                             case .int16:
                                 let new_values: [Int16] = values.map({ Int16($0) })
                                 try await copyFile(file: file!, var_name: name, type: Int16.self, data: new_values, from: urls[0],to: urls[1])
                             case .int32:
                                 let new_values: [Int32] = values.map({ Int32($0) })
                                 try await copyFile(file: file!, var_name: name, type: Int32.self, data: new_values,from: urls[0], to: urls[1])
                             case .int64:
                                 let new_values: [Int64] = values.map({ Int64($0) })
                                 try await copyFile(file: file!, var_name: name, type: Int64.self, data: new_values, from: urls[0], to: urls[1])
                             case .float: break
                             case .float64:
                                 let new_values: [Float64] = values.map({ Float64($0) })
                                 try await copyFile(file: file!, var_name: name, type: Float64.self, data: new_values, from: urls[0], to: urls[1])
                         }
                     }
                 case .float64:
                     if let values: [Float64] = try variable.asType(Double.self)?.read() {
                         switch format_to {
                             case .int16:
                                 let new_values: [Int16] = values.map({ Int16($0) })
                                 try await copyFile(file: file!, var_name: name, type: Int16.self, data: new_values, from: urls[0], to: urls[1])
                             case .int32:
                                 let new_values: [Int32] = values.map({ Int32($0) })
                                 try await copyFile(file: file!, var_name: name, type: Int32.self, data: new_values, from: urls[0],to: urls[1])
                             case .int64:
                                 let new_values: [Int64] = values.map({ Int64($0) })
                                 try await copyFile(file: file!, var_name: name, type: Int64.self, data: new_values, from: urls[0], to: urls[1])
                             case .float:
                                 let new_values: [Float32] = values.map({ Float32($0) })
                                 try await copyFile(file: file!, var_name: name, type: Float32.self, data: new_values, from: urls[0], to: urls[1])
                             case .float64: break
                         }
                     }
             }
         }
         else { print("no variable named: \(name) found."); exit(1) }
     }
     catch { print("\n\n"); print("[ ERROR ] ", error); exit(1) }
 }
 
 func copyFile<T: NetcdfConvertible>(file: Group?, var_name: String, type: T.Type, data: [T], from: URL, to: URL) async throws {
     print("write...")
     try copy_file(from: file!, to: to, exclude: [])
 }
 */
