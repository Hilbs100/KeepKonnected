import Foundation
import Combine

final class IntroState: ObservableObject {
    private static let key = "intro_state"
    @Published var value: Int {
        didSet { UserDefaults.standard.set(value, forKey: Self.key) }
    }
    
    init(_ defaultValue: Int = 1) {
        if UserDefaults.standard.object(forKey: Self.key) != nil {
            self.value = UserDefaults.standard.integer(forKey: Self.key)
        } else {
            self.value = defaultValue
            UserDefaults.standard.set(self.value, forKey: Self.key)
        }
    }
    
    func disableIntro() {
        value = 4 // switch to main app
    }
    
    func enableIntro() {
        value = 1 // force show intro
    }
    
    func reset() {
        UserDefaults.standard.removeObject(forKey: Self.key)
        value = 1
    }
}
