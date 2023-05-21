//
//  ContentView.swift
//  SimulatorLocationChange
//
//  Created by Ahmad Alhayek on 5/19/23.
//

import SwiftUI
import CLogger
import Combine
import LocationSpoofer

extension Device {
    var deviceText: String {
        "\(name) \(majorVersion ?? 0).\(minorVersion)"
    }
}

struct ContentView: View {
    @AppCodableStorage("device-locations") var locations = [DeviceLocation]()


    @ObservedObject var viewModel: ViewModel
    var body: some View {
      VStack {
          Text("Selected Device: \(viewModel.selectedDevice?.deviceText ?? "No device selected")")
              .frame(maxWidth: .infinity, alignment: .leading)
          HStack {
              ScrollView {
                  LazyVStack(alignment: .leading) {
                      ForEach(viewModel.simulators, id: \.udid) { device in
                          VStack {
                              Button(device.deviceText) {
                                  viewModel.selectedDevice = device
                              }
                          }
                         
                      }
                  }
              }
              
              ScrollView {
                  LazyVStack {
                      ForEach(locations) { location in
                          VStack(alignment: .leading) {
                              Text(location.address)
                              HStack {
                                  Text("Latitude: \(location.latitude)")
                                  Text("Longitude: \(location.longitude)")
                              }
                              Button("Select Location") {
                                  viewModel.setDeviceLocation(location)
                              }
                          }.padding()
                      }
                  }
              }
              
          }
            LocationInput {
                guard !locations.contains($0) else { return }
                locations.append($0)
            }
           
        }
   
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: .init())
    }
}

