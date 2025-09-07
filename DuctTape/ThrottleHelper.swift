import Foundation

class ThrottleHelper<T> {
    private var lastUpdate: Date = .distantPast
    private var pendingValue: T?
    private var timer: Timer?
    private let interval: TimeInterval
    private let updateHandler: (T) -> Void

    init(interval: TimeInterval, updateHandler: @escaping (T) -> Void) {
        self.interval = interval
        self.updateHandler = updateHandler
    }

    func update(_ value: T) {
        let now = Date()
        if now.timeIntervalSince(lastUpdate) >= interval {
            updateHandler(value)
            lastUpdate = now
        } else {
            pendingValue = value
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
                if let pending = self.pendingValue {
                    self.updateHandler(pending)
                    self.lastUpdate = Date()
                    self.pendingValue = nil
                }
                self.timer = nil
            }
        }
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
        pendingValue = nil
    }
}