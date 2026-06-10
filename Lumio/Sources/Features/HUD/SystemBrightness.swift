import CoreGraphics
import Foundation

// DisplayServices is a private framework; resolved at runtime so we link nothing.
enum SystemBrightness {
    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private nonisolated(unsafe) static let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY
    )

    private nonisolated(unsafe) static let getFn: GetBrightnessFn? = {
        guard let handle, let sym = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(sym, to: GetBrightnessFn.self)
    }()

    private nonisolated(unsafe) static let setFn: SetBrightnessFn? = {
        guard let handle, let sym = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(sym, to: SetBrightnessFn.self)
    }()

    static var brightness: Float {
        get {
            var value: Float = 0
            guard getFn?(CGMainDisplayID(), &value) == 0 else { return 0 }
            return value
        }
        set {
            _ = setFn?(CGMainDisplayID(), min(1, max(0, newValue)))
        }
    }
}
