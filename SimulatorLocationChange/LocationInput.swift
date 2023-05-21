//
//  LocationInput.swift
//  SimulatorLocationChange
//
//  Created by Ahmad Alhayek on 5/19/23.
//

import SwiftUI

struct LocationInput: View {
    @State private var lat: Double = 0
    @State private var long: Double = 0
    
    let addLocationItem: (DeviceLocation) -> Void
    @State private var addressName = ""
    @State private var latText = ""
    @State private var longText = ""
    
    @State private var isLatValid = false
    @State private var isLongValid = false
    
    private var canSubmit: Bool {
        isLatValid && isLongValid
    }
    
    var body: some View {
        Form {
            TextField("Address", text: $addressName)
                .textFieldStyle(.roundedBorder)
            
            TextField("Latitude", text: $latText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Longitude", text: $longText)
                .textFieldStyle(.roundedBorder)
            
            Button("Submit") {
                checkIfLatIsValid()
                checkIfLongIsValid()
                
                guard canSubmit else {
                    // show alert
                    return
                }
                latText = ""
                longText = ""
                addressName = ""
                addLocationItem(.init(address: addressName, latitude: lat, longitude: long))
            }.buttonStyle(.bordered)
        }.padding()
    }

    private func checkIfLatIsValid() {
        guard let latitude = Double(latText) else {
            isLatValid = false
            return
        }
        guard isValidLatitude(latitude) else {
            isLatValid = false
            return
        }
        isLatValid = true
        self.lat = latitude
    }
    
    private func checkIfLongIsValid() {
        guard let longitude = Double(longText) else {
            isLongValid = false
            return
        }
        
        guard isValidLongitude(longitude) else {
            isLongValid = false
            return
        }
        isLongValid = true
        self.long = longitude
    }
}

struct LocationInput_Previews: PreviewProvider {
    static var previews: some View {
        LocationInput(addLocationItem: { _ in
            
        })
    }
}
