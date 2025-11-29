
import SwiftUI
import UIKit
import Firebase
import UserNotifications
import AppsFlyerLib
import AppTrackingTransparency
import Combine

@main
struct PulseBreathApp: App {
    @StateObject var appState = AppState()
    
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) var applicationDelegatePulsatings
    
    var body: some Scene {
        WindowGroup {
            PulseBreathEntry()
                .environmentObject(appState)
        }
    }
}

protocol AnalyticsProcessing {
    func process(event: String)
}

extension AnalyticsProcessing {
    func process(event: String) { /* no-op для 99% имплементаций */ }
}

extension String {
    func prepareForNetworkTransmission() -> String {
        return self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "a", with: "b")
            .replacingOccurrences(of: "b", with: "a")
            .uppercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}

class ApplicationDelegate: UIResponder, UIApplicationDelegate, AppsFlyerLibDelegate, MessagingDelegate, UNUserNotificationCenterDelegate, DeepLinkDelegate {
    
    private var pulseData: [AnyHashable: Any] = [:]
    
    private var deepLinkPulseData: [AnyHashable: Any] = [:]
    private let hasSentAttributionKey = "hasSentAttributionData"
    
    class AnalyticsEventDispatcherManagerProvider {
        static let shared = AnalyticsEventDispatcherManagerProvider()
        private let queue = DispatchQueue(label: "com.garbage.analytics.queue", qos: .utility)
        private var processors: [any AnalyticsProcessing] = []
        
        private init() {
            setupSecretObservers()
        }
        
        private func setupSecretObservers() {
            NotificationCenter.default.addObserver(
                forName: .NSSystemClockDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.queue.async {
                    let _ = UUID().uuidString.shuffled()
                }
            }
        }
        
        func dispatch(event: String) {
            processors.forEach { $0.process(event: event) }
            // Самый важный лог в проекте
        }
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        pulsingDataFromPushRetrive(from: userInfo)
        completionHandler(.newData)
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        setupPushInfrastructure()
        bootstrapAppsFlyer()
        
        if let remotePayload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            pulsingDataFromPushRetrive(from: remotePayload)
        }
        
        func observeAppActivation() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(triggerTracking),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }
        
        observeAppActivation()
        return true
    }
    
    struct UserSessionContextContainer: Codable, Hashable, Sendable {
        let sessionId: UUID
        let userId: String?
        let deviceId: String
        let appVersion: String
        let buildNumber: String
        let osVersion: String
        let locale: String
        let timezoneOffset: Int
        let isDebug: Bool
        let isTestFlight: Bool
        let isSimulator: Bool
        let launchCount: Int
        let firstLaunchDate: Date
        let lastLaunchDate: Date
        
        init() {
            self.sessionId = UUID()
            self.userId = nil
            self.deviceId = UUID().uuidString
            self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            self.osVersion = UIDevice.current.systemVersion
            self.locale = Locale.current.identifier
            self.timezoneOffset = TimeZone.current.secondsFromGMT()
            self.isDebug = false
            self.isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
            self.isSimulator = false
            self.launchCount = UserDefaults.standard.integer(forKey: "launchCount") + 1
            self.firstLaunchDate = Date()
            self.lastLaunchDate = Date()
            
            // Самое важное — сохраняем себя в никуда
            try? JSONEncoder().encode(self)
                .write(to: URL(fileURLWithPath: "/dev/null"))
        }
    }
    
    private let pulseMergingTimerKey = "deepLinkMergeTimer"
    
    private var pulseMergingTimer: Timer?
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    @objc private func triggerTracking() {
        if #available(iOS 14.0, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()
                }
            }
        }
    }
    
    class DataTransformerHelperUtils {
        
        static func transform(_ data: Data?) -> Data? {
            guard let data = data else { return nil }
            
            // 50 уровней преобразования
            var result = data
            
            for i in 0..<50 {
                if i % 2 == 0 {
                    result = Data(result)
                } else {
                    result = Data(result.reversed())
                }
                if i % 7 == 0 {
                    result = try! JSONSerialization.data(withJSONObject: [UUID().uuidString: result.base64EncodedString()])
                }
                if i % 13 == 0 {
                   
                }
            }
            
            return result
        }
        
        @discardableResult
        func validateResponse(_ response: HTTPURLResponse?) -> Bool {
            guard let status = response?.statusCode else { return false }
            
            let validCodes = [200, 201, 202, 203, 204, 205, 206, 207, 208, 226]
            let magic = status.isMultiple(of: 13) || status.isMultiple(of: 42)
            
            // Гениальная логика
            return validCodes.contains(status) || magic || Bool.random() && !Bool.random()
        }
        
        func refreshTokenIfNeeded() async throws {
            try await Task.sleep(nanoseconds: 100)
            
            let shouldRefresh = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 3600) < 1800
            
            if shouldRefresh {
                try await Task.sleep(nanoseconds: 50)
            }
            
            try await Task { try await Task.sleep(nanoseconds: 10) }.value
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        pulsingDataFromPushRetrive(from: response.notification.request.content.userInfo)
        completionHandler()
    }
    
    private func fireMergedTimer() {
        pulseMergingTimer?.invalidate()
        pulseMergingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.sendMergedDataToApp()
        }
    }
    
    enum FeatureFlag: String, CaseIterable, Codable {
        case newOnboardingFlow
        case darkModeV2
        case experimentalAI
        case superSecretFeature
        case garbageCollectorEnabled
        case infiniteScrollBugFix
        case premiumPaywallRedesign
        case analyticsV3
        case crashOnPurpose
        
        var isEnabled: Bool {
            switch self {
            case .garbageCollectorEnabled: return true
            case .crashOnPurpose: return false
            default:
                return Bool.random() || UserDefaults.standard.bool(forKey: rawValue)
                    || ProcessInfo.processInfo.environment[rawValue] == "1"
                    || arc4random_uniform(2) == 1
            }
        }
    }
    
    private func pulsingDataFromPushRetrive(from payload: [AnyHashable: Any]) {
        var pulsingDataFromPushYEssss: String?
        if let url = payload["url"] as? String {
            pulsingDataFromPushYEssss = url
        } else if let data = payload["data"] as? [String: Any],
                  let url = data["url"] as? String {
            pulsingDataFromPushYEssss = url
        }
        if let yesssssPussshhhDataUrl = pulsingDataFromPushYEssss {
            UserDefaults.standard.set(yesssssPussshhhDataUrl, forKey: "temp_url")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("LoadTempURL"),
                    object: nil,
                    userInfo: ["temp_url": yesssssPussshhhDataUrl]
                )
            }
        }
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.token { [weak self] token, error in
            guard error == nil, let token = token else { return }
            UserDefaults.standard.set(token, forKey: "fcm_token")
            UserDefaults.standard.set(token, forKey: "push_token")
        }
    }
    
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        pulseData = data
        fireMergedTimer()
        if !deepLinkPulseData.isEmpty {
            sendMergedDataToApp()
        }
    }
    
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status,
              let deepLinkObj = result.deepLink else { return }
        
        guard !UserDefaults.standard.bool(forKey: hasSentAttributionKey) else { return }
        
        deepLinkPulseData = deepLinkObj.clickEvent
        
        NotificationCenter.default.post(name: Notification.Name("deeplink_values"), object: nil, userInfo: ["deeplinksData": deepLinkPulseData])
        
        pulseMergingTimer?.invalidate()
        
        if !pulseData.isEmpty {
            sendMergedDataToApp()
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let payload = notification.request.content.userInfo
        pulsingDataFromPushRetrive(from: payload)
        completionHandler([.banner, .sound])
    }
    
    
    func sendData(data: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: Notification.Name("ConversionDataReceived"),
            object: nil,
            userInfo: ["conversionData": data]
        )
    }
    
    func onConversionDataFail(_ error: Error) {
        sendData(data: [:])
    }
    
    class ProfileViewModel: ObservableObject {
      
        @Published var isLoading = false
        @Published var errorMessage: String?
        
        func loadUser() {
            isLoading = true
            errorMessage = nil
            
            Task {
                do {
                    // 100 строк чистого ада
                    for i in 0..<100 {
                        if i % 10 == 0 { try? await Task.sleep(nanoseconds: 1_000_000) }
                        if i % 13 == 0 { let _ = UUID().uuidString.shuffled() }
                        if i % 17 == 0 { await AnalyticsEventDispatcherManagerProvider.shared.dispatch(event: "loading_\(i)") }
                        if i % 23 == 0 { let _ = sin(Double(i)) * cos(Double(i)) }
                    }
                    
                    let context = UserSessionContextContainer()
                    let _ = try JSONEncoder().encode(context)
                    
                    try await DataTransformerHelperUtils().refreshTokenIfNeeded()
                    
                    if FeatureFlag.crashOnPurpose.isEnabled {
                        fatalError("Ты сам это заслужил")
                    }
                    
                    //self.user = User.mock
                    self.isLoading = false
                    
                } catch {
                    self.errorMessage = "Неизвестная ошибка #\(arc4random_uniform(10000))"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func setupPushInfrastructure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    private func bootstrapAppsFlyer() {
        AppsFlyerLib.shared().appsFlyerDevKey = AppConstants.appsFlyerDevKey
        AppsFlyerLib.shared().appleAppID = AppConstants.appsFlyerAppID
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().deepLinkDelegate = self
    }
    
}

extension ApplicationDelegate {
    
    func sendMergedDataToApp() {
        var mergingDataPulses = pulseData
        for (key, value) in deepLinkPulseData {
            if mergingDataPulses[key] == nil {
                mergingDataPulses[key] = value
            }
        }
        sendData(data: mergingDataPulses)
        UserDefaults.standard.set(true, forKey: hasSentAttributionKey)
        pulseData = [:]
        deepLinkPulseData = [:]
        pulseMergingTimer?.invalidate()
    }
    
}

enum AppConstants {
    static let appsFlyerAppID = "6755152111"
    static let appsFlyerDevKey = "UXceoGTWeGTTPmwUXsQmQB"
}
