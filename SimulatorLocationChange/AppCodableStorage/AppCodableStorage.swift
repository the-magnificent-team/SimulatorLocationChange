//
//  AppCodableStorage.swift
//  SimulatorLocationChange
//
//  Created by Ahmad Alhayek on 5/20/23.
//

import SwiftUI


@MainActor
@propertyWrapper
public struct AppCodableStorage<Value: PropertyListRepresentable>: DynamicProperty {
    private let triggerUpdate: ObservedObject<DefaultsWriter<Value>>
    // Uses the shared
    private let writer: DefaultsWriter<Value>
    
    public init(wrappedValue: Value, _ key: String, defaults: UserDefaults? = nil) {
        writer = DefaultsWriter<Value>.shared(defaultValue: wrappedValue, key: key, defaults: defaults ?? .standard)
        triggerUpdate = .init(wrappedValue: writer)
    }
    
    public var wrappedValue: Value {
        get { writer.state }
        nonmutating set { writer.state = newValue }
    }
    
    public var projectedValue: Binding<Value> {
        Binding(
            get: { writer.state },
            set: { writer.state = $0 }
        )
    }
}

/// API to observe UserDefaults with a `String` key (not `KeyPath`),  as `AppStorage` and `.string( forKey:)` use
extension UserDefaults {

    // Just a BS object b/c we can't use the newer observation syntax
    class UserDefaultsStringKeyObservation: NSObject {
        
        // Handler recieves the updated value from userdefaults
        fileprivate init(defaults: UserDefaults, key: String, handler: @escaping (Any?) -> Void) {
            self.defaults = defaults
            self.key = key
            self.handler = handler
            super.init()
            // print("Adding observer \(self) for keyPath: \(key)")
            defaults.addObserver(self, forKeyPath: key, options: .new, context: nil)
        }
        let defaults: UserDefaults
        let key: String
        
        // This prevents us from double-removing ourselves as the observer (if we are cancelled, then deinit)
        private var isCancelled: Bool = false

        private let handler: (Any?) -> Void
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard (object as? UserDefaults) == defaults else { fatalError("AppCodableStorage: Somehow observing wrong defaults") }
            let newValue = change?[.newKey]
            handler(newValue)
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            defaults.removeObserver(self, forKeyPath: key)
        }

        deinit {
            cancel()
        }
    }
    
    func observe(key: String, changeHandler: @escaping (Any?) -> Void) -> UserDefaultsStringKeyObservation {
        return UserDefaultsStringKeyObservation(defaults: self, key: key, handler: changeHandler)
    }
}

import Combine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension UserDefaults.UserDefaultsStringKeyObservation: Cancellable {}


public protocol PropertyListRepresentable {
    init(propertyList: Any) throws
    var propertyListValue: Any { get throws }
}

// Default implementation of PropertyListRepresentable for objects that are Decobable
public extension PropertyListRepresentable where Self: Decodable {
    init(propertyList: Any) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: propertyList, format: .binary, options: 0)
        let dec = PropertyListDecoder()
        self = try dec.decode(Self.self, from: data)
    }
}

// Default implementation of PropertyListRepresentable for objects that are Encodable
public extension PropertyListRepresentable where Self: Encodable {
    var propertyListValue: Any {
        get throws {
            // Encode to plist, decode :(
            // We can copy https://github.com/apple/swift-corelibs-foundation/blob/main/Darwin/Foundation-swiftoverlay/PlistEncoder.swift
            // to fix this, just not slow enough afaik
            let data = try PropertyListEncoder().encode(self)
            return try PropertyListSerialization.propertyList(from: data, format: nil)
        }
    }
}

public final class DefaultsWriter<Value: PropertyListRepresentable>: ObservableObject {
    
    public let key: String
    public let defaults: UserDefaults

    // Var to get around issue with init and callback fn
    private var defaultsObserver: UserDefaults.UserDefaultsStringKeyObservation!
    private let defaultValue: Value
    private var pausedObservation: Bool = false
    
    // Experimental API… I had some situations outside of SwiftUI where I need to get the value AFTER the change
    public let objectDidChange: AnyPublisher<Value, Never>
    private let _objectDidChange: PassthroughSubject<Value, Never>
    
    public var state: Value {
        willSet{
            objectWillChange.send()
        }
        didSet {
            if let encoded = try? state.propertyListValue {
                // We don't want to observe the redundant notification that will come from UserDefaults
                pausedObservation = true
                defaults.set(encoded, forKey: key)
                pausedObservation = false
            }
            _objectDidChange.send(state)
        }
    }

    public init(defaultValue: Value, key: String, defaults: UserDefaults? = nil) {
        let defaults = defaults ?? .standard
        self.key = key
        self.state = Self.read(from: defaults, key: key) ?? defaultValue
        self.defaults = defaults
        self.defaultValue = defaultValue
        self.defaultsObserver = nil
        self._objectDidChange = PassthroughSubject<Value, Never>()
        self.objectDidChange = _objectDidChange.eraseToAnyPublisher()
        
        // When defaults change externally, update our value
        // We cannot use the newer defaults.observe() because we have a keyPath String not a KeyPath<Defaults, Any>
        // This means we don't force you to declare your keypath in a UserDefaults extension
        self.defaultsObserver = defaults.observe(key: key){[weak self] newValue in
            guard let self = self, self.pausedObservation == false else { return }
            self.observeDefaultsUpdate(newValue)
        }
    }
    
    // Take in a new object value from UserDefaults, updating our state
    internal func observeDefaultsUpdate(_ newValue: Any?) {
        if newValue is NSNull {
            self.state = defaultValue
        } else if let newValue = newValue {
            do {
                let newState = try Value(propertyList: newValue)
                // print("Observed defaults new state is \(newValue)")
                self.state = newState
            } catch {
                print("DefaultsWriter could not deserialize update from UserDefaults observation. Not updating. \(error)")
            }
        } else {
            self.state = defaultValue
        }
    }
    
    internal static func read(from defaults: UserDefaults, key: String) -> Value? {
        if let o = defaults.object(forKey: key) {
            return try? Value(propertyList: o)
        } else {
            return nil
        }
    }

}

@MainActor
internal var sharedDefaultsWriters: [WhichDefaultsAndKey: Any /* Any DefaultsWriter<_> */] = [:]

struct WhichDefaultsAndKey: Hashable {
    let defaults: UserDefaults
    let key: String
}

extension DefaultsWriter {
    
    @MainActor
    public static func shared(defaultValue: PropertyListRepresentable, key: String, defaults: UserDefaults) -> Self {
        let kdPr = WhichDefaultsAndKey(defaults: defaults, key: key)
        if let existing = sharedDefaultsWriters[kdPr] {
            guard let typed = existing as? Self else {
                fatalError("Type \(Value.self) must remain consistent for key \(key). Existing: \(existing)")
            }
            return typed
        }
        let neue = Self(defaultValue: defaultValue as! Value, key: key, defaults: defaults)
        sharedDefaultsWriters[kdPr] = neue
        return neue
    }
}
