import AVFoundation
import Capacitor
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Sound effects mix with the player's music and follow the silent switch, as in the
        // Swift app. (The web layer also asks for this on iOS 17+ through navigator.audioSession.)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        migrateSwiftAppData()
        return true
    }

    /// The Swift version of Frost Slide kept its save as JSON data under `frostslide.save.v1` and
    /// the Remove Ads flag as a Bool. The web build reads both through Capacitor Preferences,
    /// which stores strings under a `CapacitorStorage.` prefix. Copy them across once, so an
    /// update from the Swift app keeps every course, record, ghost and purchase.
    private func migrateSwiftAppData() {
        let defaults = UserDefaults.standard
        let saveKey = "CapacitorStorage.frostslide.save.v1"
        if defaults.string(forKey: saveKey) == nil,
           let data = defaults.data(forKey: "frostslide.save.v1"),
           let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: saveKey)
        }
        let adsKey = "CapacitorStorage.frostslide.adsRemoved"
        if defaults.string(forKey: adsKey) == nil, defaults.bool(forKey: "frostslide.adsRemoved") {
            defaults.set("true", forKey: adsKey)
        }
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration",
                                          sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
