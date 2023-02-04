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

extension String {
    
    func toDate(format: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = format
        return dateFormatter.date(from: self)
    }
    
}

extension Array where Element == Double {

    func movingAverage(sectionSize: Int) -> [Double] {
             var result : [Double] = []

            for n in self.chunked(into: sectionSize) {
                result.append(n.reduce(0, +) / Double(n.count))
            }
            return result
     }

    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

}

extension Date {

    func getDateFormattedBy(_ format: String) -> String {
        let dateformat = DateFormatter()
        dateformat.timeZone = TimeZone(identifier: "UTC")
        dateformat.dateFormat = format
        return dateformat.string(from: self)
    }

    func logDate() -> String {
        let dateformat = DateFormatter()
        dateformat.timeZone = TimeZone(abbreviation: "UTC")
        dateformat.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateformat.string(from: self)
    }

    func isOlderThan(minutes: Int) -> Bool {
       return Date() > self.advanced(by: Double(minutes) * 60.0)
    }

}
