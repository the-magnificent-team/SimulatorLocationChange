//
//  ContentView+ViewModel.swift
//  SimulatorLocationChange
//
//  Created by Ahmad Alhayek on 5/20/23.
//

import SwiftUI
import CLogger
import Combine
import LocationSpoofer

extension ContentView {
    final class ViewModel: ObservableObject {
        @Published var simulators = [any Device]()
        @Published var selectedDevice: Device?
        
        
        private var cancellable =  Set<AnyCancellable>()
        init() {
            logger_initConsoleLogger(nil)
            IOSDevice.startGeneratingDeviceNotifications()
            SimulatorDevice.startGeneratingDeviceNotifications()
            simulators = SimulatorDevice.availableDevices + IOSDevice.availableDevices
            addObservable()
        }
        
        private func addObservable() {
            let deviceConnected = NotificationCenter.default.publisher(for: .DeviceConnected)
            let devicePaired =  NotificationCenter.default.publisher(for: .DevicePaired)
            
            deviceConnected.merge(with: devicePaired)
                .mapToDevice()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] device in
                    guard self?.simulators.first(where: {
                        $0.udid == device.udid
                    }) == nil else { return }
                    self?.simulators.append(device)
                }.store(in: &cancellable)

            NotificationCenter.default.publisher(for: .DeviceDisconnected)
                .mapToDevice()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] device in
                    self?.simulators.removeAll(where: {
                        $0.udid == device.udid
                    })
                }.store(in: &cancellable)
            
            NotificationCenter.default.publisher(for: .DeviceChanged)
                .mapToDevice()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] device in
                    guard let index = self?.simulators.firstIndex(where: {
                        $0.udid == device.udid
                    }) else { return }
                    
                    self?.simulators[index] = device
                    if device.udid == self?.selectedDevice?.udid {
                        self?.selectedDevice = device
                    }
                }.store(in: &cancellable)
        }
        
        func setDeviceLocation(_ location: DeviceLocation) {
            self.selectedDevice?.simulateLocation(.init(latitude: location.latitude,
                                                         longitude: location.longitude))
           
        }

    }
}


extension Array: PropertyListRepresentable where Element: Codable {
    
}

extension Publisher where Output == Notification {
    func mapToDevice() -> Publishers.CompactMap<Self, Device> {
        compactMap {
            $0.userInfo?["device"] as? Device
        }
    }
}
