//
//  Date+.swift
//  PPS
//
//  Created by Kevin Boulala on 24/06/2025.
//

import Foundation

extension Date {
    /// Date with this format "yyyy-MM-dd"
    var shortDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: self)
    }

    var day: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd"
        return dateFormatter.string(from: self)
    }

    var month: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM"
        return dateFormatter.string(from: self)
    }

    var year: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        return dateFormatter.string(from: self)
    }
}
