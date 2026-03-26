import Foundation

final class KeyValueSyncBridge {
    private let keys: Set<String>
    private var isSyncing = false

    init(keys: Set<String>) {
        self.keys = keys
    }

    func start() {
        let cloud = NSUbiquitousKeyValueStore.default
        cloud.synchronize()

        for key in keys {
            if let cloudValue = cloud.object(forKey: key) {
                isSyncing = true
                UserDefaults.standard.set(cloudValue, forKey: key)
                isSyncing = false
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func cloudDidChange(_ notification: Notification) {
        guard !isSyncing else { return }
        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }
        let cloud = NSUbiquitousKeyValueStore.default
        isSyncing = true
        for key in changedKeys where keys.contains(key) {
            UserDefaults.standard.set(cloud.object(forKey: key), forKey: key)
        }
        isSyncing = false
    }

    @objc private func defaultsDidChange(_ notification: Notification) {
        guard !isSyncing else { return }
        let defaults = UserDefaults.standard
        let cloud = NSUbiquitousKeyValueStore.default
        isSyncing = true
        for key in keys {
            let localValue = defaults.object(forKey: key) as? NSObject
            let cloudValue = cloud.object(forKey: key) as? NSObject
            if localValue != cloudValue {
                cloud.set(localValue, forKey: key)
            }
        }
        isSyncing = false
    }
}
