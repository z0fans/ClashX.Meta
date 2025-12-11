import Foundation

// LogRateLimiter - macOS 10.14 compatible version
// Replaced actor with class + DispatchQueue for thread safety
class LogRateLimiter {
    private let maxLogsCount: Int = 20000
    private let timeDuration: TimeInterval = 5.0
    private var logCount: Int = 0
    private var startTime: TimeInterval = CFAbsoluteTimeGetCurrent()
    private var lastTimeCheck: TimeInterval = CFAbsoluteTimeGetCurrent()
    private var isBlocked = false

    private let onRateLimitTriggered: () -> Void
    private let queue = DispatchQueue(label: "com.metacubex.ClashX.LogRateLimiter")

    init(onRateLimitTriggered: @escaping () -> Void) {
        self.onRateLimitTriggered = onRateLimitTriggered
    }

    // Returns true if log can be processed, false if rate limited
    func processLog() -> Bool {
        return queue.sync {
            guard !isBlocked else { return false }

            let now = CFAbsoluteTimeGetCurrent()

            // Only check time and count every 1 second to reduce overhead
            if now - lastTimeCheck >= 1.0 {
                lastTimeCheck = now

                // Reset counter if time window has passed
                if now - startTime >= timeDuration {
                    startTime = now
                    logCount = 0
                }

                // Check if rate limit exceeded
                if logCount >= maxLogsCount {
                    triggerRateLimit()
                    return false
                }
            }

            logCount += 1
            return true
        }
    }

    private func triggerRateLimit() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isBlocked = true

            // Execute callback on main queue
            DispatchQueue.main.async {
                self.onRateLimitTriggered()
                Logger.log("⚠️ Rate limit triggered: >\(self.maxLogsCount) logs/\(self.timeDuration)sec, paused for 1min")
            }

            // Resume after 60 seconds
            Thread.sleep(forTimeInterval: 60.0)

            self.isBlocked = false

            DispatchQueue.main.async {
                Logger.log("✅ Rate limit resumed")
            }
        }
    }
}
