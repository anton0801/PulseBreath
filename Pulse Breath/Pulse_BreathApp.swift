
import SwiftUI
import UIKit
import Firebase
import UserNotifications
import AppsFlyerLib
import AppTrackingTransparency

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


class ApplicationDelegate: UIResponder, UIApplicationDelegate, AppsFlyerLibDelegate, MessagingDelegate, UNUserNotificationCenterDelegate, DeepLinkDelegate {
    
    private var pulseData: [AnyHashable: Any] = [:]
    
    private var deepLinkPulseData: [AnyHashable: Any] = [:]
    private let hasSentAttributionKey = "hasSentAttributionData"
    
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
