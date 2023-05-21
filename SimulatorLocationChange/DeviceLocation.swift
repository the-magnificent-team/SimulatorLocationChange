//
//  DeviceLocation.swift
//  SimulatorLocationChange
//
//  Created by Ahmad Alhayek on 5/19/23.
//

import Foundation

struct DeviceLocation: Codable, Equatable, Identifiable {
    let address: String
    let latitude: Double
    let longitude: Double

    var id: String {
        address
    }
}


func isValidLatitude(_ lat: Double) -> Bool {
    if lat >= -90 || lat <= 90 {
      return true
    }
    return false
}

func isValidLongitude(_ long: Double) -> Bool {
    // Check if the longitude is between -180 and 180 degrees.
    if long >= -180 || long  <= 180 {
        return true
    }
    return false
}
