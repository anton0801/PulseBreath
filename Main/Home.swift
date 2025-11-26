
import SwiftUI
import AVFoundation
import UserNotifications
import Combine
import FirebaseCore
import Network
import WebKit
import FirebaseMessaging
import AppsFlyerLib
import AppTrackingTransparency

class AppState: ObservableObject {
    @Published var currentTheme: Theme = .dark
    @Published var hapticsEnabled: Bool = true
    @Published var audioEnabled: Bool = true
    @Published var selectedMode: BreathingMode = .sleep {
        didSet {
            saveData()
        }
    }
    @Published var sessions: [SessionLog] = [] {
        didSet {
            saveData()
        }
    }
    @Published var reminders: [Reminder] = [] {
        didSet {
            saveData()
        }
    }
    @Published var programs: [Program] = [
        Program(name: "Before Sleep", duration: 600, days: 7, mode: .sleep),
        Program(name: "Calm at Work", duration: 300, days: 10, mode: .relax),
        Program(name: "Public Speaking", duration: 300, days: 5, mode: .focus)
    ] {
        didSet {
            saveData()
        }
    }
    @Published var disclaimerShowed = UserDefaults.standard.bool(forKey: "disclaimer_showed") {
        didSet {
            UserDefaults.standard.set(disclaimerShowed, forKey: "disclaimer_showed")
        }
    }
    @Published var streakCount: Int = 0 {
        didSet { saveData() }
    }
    @Published var lastSessionDate: Date? = nil {
        didSet { saveData() }
    }
  
    // Audio Player
    var audioPlayer: AVAudioPlayer?
  
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "sessions"
    private let programsKey = "programs"
    private let remindersKey = "reminders"
    private let selectedModeKey = "selectedMode"
  
    init() {
        loadData()
        streakCount = userDefaults.integer(forKey: "streakCount")
        if let date = userDefaults.object(forKey: "lastSessionDate") as? Date {
            lastSessionDate = date
        }
    }
  
    // Play sound
    func playClickSound() {
        if audioEnabled {
            guard let url = Bundle.main.url(forResource: "click", withExtension: "mp3") else { return }
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
            } catch {}
        }
    }
  
    // Haptics
    func triggerHaptic() {
        if hapticsEnabled {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
  
    func scheduleReminder(at date: Date) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        let content = UNMutableNotificationContent()
        content.title = "Time to Breathe"
        content.body = "Start your session now!"
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
  
    func saveData() {
        do {
            let sessionsData = try JSONEncoder().encode(sessions)
            userDefaults.set(sessionsData, forKey: sessionsKey)
          
            let programsData = try JSONEncoder().encode(programs)
            userDefaults.set(programsData, forKey: programsKey)
          
            let remindersData = try JSONEncoder().encode(reminders)
            userDefaults.set(remindersData, forKey: remindersKey)
          
            let modeData = try JSONEncoder().encode(selectedMode)
            userDefaults.set(modeData, forKey: selectedModeKey)
        } catch {
            print("Error saving data: \(error)")
        }
    }
  
    private func loadData() {
        if let sessionsData = userDefaults.data(forKey: sessionsKey) {
            do {
                sessions = try JSONDecoder().decode([SessionLog].self, from: sessionsData)
            } catch {
                print("Error loading sessions: \(error)")
            }
        }
      
        if let programsData = userDefaults.data(forKey: programsKey) {
            do {
                programs = try JSONDecoder().decode([Program].self, from: programsData)
            } catch {
                print("Error loading programs: \(error)")
            }
        }
      
        if let remindersData = userDefaults.data(forKey: remindersKey) {
            do {
                reminders = try JSONDecoder().decode([Reminder].self, from: remindersData)
            } catch {
                print("Error loading reminders: \(error)")
            }
        }
      
        if let modeData = userDefaults.data(forKey: selectedModeKey) {
            do {
                selectedMode = try JSONDecoder().decode(BreathingMode.self, from: modeData)
            } catch {
                print("Error loading selectedMode: \(error)")
            }
        }
    }
    
    func updateStreakIfNeeded() {
        guard let lastDate = lastSessionDate else {
            // Первый раз
            streakCount = 1
            lastSessionDate = Date()
            scheduleStreakRiskNotificationIfNeeded()
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let last = calendar.startOfDay(for: lastDate)
        
        if calendar.isDate(today, inSameDayAs: last) {
            // Уже было сегодня — не увеличиваем
            return
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  calendar.isDate(last, inSameDayAs: yesterday) {
            // Вчера было — увеличиваем
            streakCount += 1
        } else {
            // Пропуск — сбрасываем
            streakCount = 1
        }
        
        lastSessionDate = Date()
        scheduleStreakRiskNotificationIfNeeded()
    }
    
    private func scheduleStreakRiskNotificationIfNeeded() {
        guard streakCount >= 2 else { return }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streakRisk"])
        
        let content = UNMutableNotificationContent()
        content.title = "Огонь Не потеряй стрик!"
        content.body = streakCount >= 6
            ? "Ты на \(streakCount)-дневном стрике! Не потеряй огонь сегодня"
            : "У тебя уже \(streakCount)-дневный стрик! Дыши сегодня, чтобы не сбросить"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 20   // 20:00 вечера
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "streakRisk", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}

enum Theme: String {
    case dark, neon, calm
}

struct SessionLog: Identifiable, Codable {
    let id: UUID
    let date: Date
    let mode: BreathingMode
    let duration: TimeInterval
    let isCompleted: Bool
  
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case mode
        case duration
        case isCompleted
    }
  
    init(id: UUID = UUID(), date: Date, mode: BreathingMode, duration: TimeInterval, isCompleted: Bool) {
        self.id = id
        self.date = date
        self.mode = mode
        self.duration = duration
        self.isCompleted = isCompleted
    }
  
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        mode = try container.decode(BreathingMode.self, forKey: .mode)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
    }
  
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(mode, forKey: .mode)
        try container.encode(duration, forKey: .duration)
        try container.encode(isCompleted, forKey: .isCompleted)
    }
}

struct Reminder: Identifiable, Codable {
    let id: UUID
    let time: Date
    let days: [Int] // 1-7 for weekdays
  
    enum CodingKeys: String, CodingKey {
        case id
        case time
        case days
    }
  
    init(id: UUID = UUID(), time: Date, days: [Int]) {
        self.id = id
        self.time = time
        self.days = days
    }
  
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        time = try container.decode(Date.self, forKey: .time)
        days = try container.decode([Int].self, forKey: .days)
    }
  
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(time, forKey: .time)
        try container.encode(days, forKey: .days)
    }
}

// Breathing Mode Model
struct BreathingMode: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let description: String
    let inhale: Double
    let holdAfterInhale: Double
    let exhale: Double
    let holdAfterExhale: Double
    let colorHex: String
    let tempoScale: Double
  
    var color: Color {
        Color(hex: colorHex)
    }
  
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case inhale
        case holdAfterInhale
        case exhale
        case holdAfterExhale
        case colorHex
        case tempoScale
    }
  
    init(name: String, description: String, inhale: Double, holdAfterInhale: Double, exhale: Double, holdAfterExhale: Double, color: Color, tempoScale: Double = 1.0) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.inhale = inhale
        self.holdAfterInhale = holdAfterInhale
        self.exhale = exhale
        self.holdAfterExhale = holdAfterExhale
        self.colorHex = color.hexString
        self.tempoScale = tempoScale
    }
  
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        inhale = try container.decode(Double.self, forKey: .inhale)
        holdAfterInhale = try container.decode(Double.self, forKey: .holdAfterInhale)
        exhale = try container.decode(Double.self, forKey: .exhale)
        holdAfterExhale = try container.decode(Double.self, forKey: .holdAfterExhale)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        tempoScale = try container.decode(Double.self, forKey: .tempoScale)
    }
  
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(inhale, forKey: .inhale)
        try container.encode(holdAfterInhale, forKey: .holdAfterInhale)
        try container.encode(exhale, forKey: .exhale)
        try container.encode(holdAfterExhale, forKey: .holdAfterExhale)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(tempoScale, forKey: .tempoScale)
    }
  
    static let sleep = BreathingMode(name: "Sleep", description: "4-7-8 breathing", inhale: 4, holdAfterInhale: 7, exhale: 8, holdAfterExhale: 0, color: Color(hex: "#5B7CFF"))
    static let focus = BreathingMode(name: "Focus", description: "3-3-3-3", inhale: 3, holdAfterInhale: 3, exhale: 3, holdAfterExhale: 3, color: Color(hex: "#4FFFE0"))
    static let relax = BreathingMode(name: "Relax", description: "5-5", inhale: 5, holdAfterInhale: 0, exhale: 5, holdAfterExhale: 0, color: Color(hex: "#FF4FBF"))
    static let energy = BreathingMode(name: "Energy", description: "2-0-4-0", inhale: 2, holdAfterInhale: 0, exhale: 4, holdAfterExhale: 0, color: Color(hex: "#FFC34F"))
    static let box = BreathingMode(name: "Box Breathing", description: "4-4-4-4", inhale: 4, holdAfterInhale: 4, exhale: 4, holdAfterExhale: 4, color: Color(hex: "#00FFFF"))
    static let coherent = BreathingMode(name: "Coherent", description: "5.5-5.5", inhale: 5.5, holdAfterInhale: 0, exhale: 5.5, holdAfterExhale: 0, color: Color(hex: "#A020F0"))
    static let panicRelief = BreathingMode(
        name: "Быстрый спасатель",
        description: "Мгновенное снятие тревоги",
        inhale: 4,
        holdAfterInhale: 0,
        exhale: 8,
        holdAfterExhale: 0,
        color: Color(hex: "#FF6B9D")
    )
  
    static var predefined: [BreathingMode] = [.sleep, .focus, .relax, .energy, .box, .coherent, .panicRelief]
    
    var sourceInfo: (title: String, url: String)? {
        switch self {
        case .sleep: // 4-7-8
            return ("Dr. Andrew Weil's 4-7-8 Technique", "https://www.drweil.com/videos-features/videos/breathing-exercises-4-7-8-breath/")
        case .focus: // 3-3-3-3 (balanced breathing for focus)
            return ("Harvard Health: Equal Breathing for Concentration", "https://www.health.harvard.edu/mind-and-mood/relaxation-techniques-breath-control-helps-quell-errant-stress-response")
        case .relax: // 5-5
            return ("Mayo Clinic: Diaphragmatic Breathing", "https://www.mayoclinic.org/healthy-lifestyle/stress-management/in-depth/relaxation-technique/art-20045368")
        case .energy: // 2-0-4-0 (quick energizing breath)
            return ("American Lung Association: Pursed Lip Breathing for Energy", "https://www.lung.org/lung-health-diseases/wellness/breathing-exercises")
        case .box: // 4-4-4-4
            return ("Navy SEALs Box Breathing, via Mark Divine", "https://unbeatablemind.com/box-breathing/")
        case .coherent: // 5.5-5.5
            return ("HeartMath Institute: Coherent Breathing Research", "https://www.heartmath.org/research/science-of-the-heart/heart-rate-variability/")
        default:
            return nil
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
  
    var hexString: String {
        let components = self.cgColor?.components ?? [0, 0, 0, 1]
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// Breathing Engine
class BreathingEngine: ObservableObject {
    var mode: BreathingMode
    var sessionDuration: Double // in seconds
    var onPhaseChange: () -> Void
    var onSessionEnd: ((Double, Bool) -> Void)?
  
    @Published var currentPhase: Phase = .inhale
    @Published var phaseTimeRemaining: Double = 0
    @Published var totalTimeElapsed: Double = 0
    @Published var isRunning: Bool = false
  
    var timer: Timer?
  
    enum Phase {
        case inhale, holdInhale, exhale, holdExhale
    }
  
    init(mode: BreathingMode, sessionDuration: Double, onPhaseChange: @escaping () -> Void) {
        self.mode = mode
        self.sessionDuration = sessionDuration
        self.onPhaseChange = onPhaseChange
    }
  
    func start() {
        isRunning = true
        setupPhase()
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in // ~60 FPS
            if self.phaseTimeRemaining > 0 {
                self.phaseTimeRemaining -= 0.016
                self.totalTimeElapsed += 0.016
            } else {
                self.nextPhase()
            }
            if self.totalTimeElapsed >= self.sessionDuration {
                self.stop()
            }
        }
    }
  
    func pause() {
        isRunning = false
        timer?.invalidate()
    }
  
    func reset() {
        if totalTimeElapsed > 0 {
            onSessionEnd?(totalTimeElapsed, false)
        }
        pause()
        currentPhase = .inhale
        phaseTimeRemaining = 0
        totalTimeElapsed = 0
    }
  
    func stop() {
        onSessionEnd?(totalTimeElapsed, true)
        reset()
    }
  
    private func setupPhase() {
        switch currentPhase {
        case .inhale:
            phaseTimeRemaining = mode.inhale * mode.tempoScale
        case .holdInhale:
            phaseTimeRemaining = mode.holdAfterInhale * mode.tempoScale
        case .exhale:
            phaseTimeRemaining = mode.exhale * mode.tempoScale
        case .holdExhale:
            phaseTimeRemaining = mode.holdAfterExhale * mode.tempoScale
        }
        onPhaseChange()
    }
  
    private func nextPhase() {
        switch currentPhase {
        case .inhale:
            currentPhase = mode.holdAfterInhale > 0 ? .holdInhale : .exhale
        case .holdInhale:
            currentPhase = .exhale
        case .exhale:
            currentPhase = mode.holdAfterExhale > 0 ? .holdExhale : .inhale
        case .holdExhale:
            currentPhase = .inhale
        }
        setupPhase()
    }
}

// App Background Gradient
let appBackground = LinearGradient(gradient: Gradient(colors: [Color(hex: "#0D0D1A"), Color(hex: "#2B0D4F")]), startPoint: .top, endPoint: .bottom)

// Pulsating Rings View
struct PulsatingRings: View {
    let color: Color
    @ObservedObject var engine: BreathingEngine
  
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.5
    @State private var glow: Double = 0.0
  
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(color.opacity(opacity - Double(i) * 0.1), lineWidth: 8 + CGFloat(i * 3))
                    .frame(width: 150 + CGFloat(i * 60), height: 150 + CGFloat(i * 60))
                    .scaleEffect(scale)
                    .blur(radius: 4 + CGFloat(i))
                    .shadow(color: color.opacity(glow), radius: 10, x: 0, y: 0)
            }
        }
        .onChange(of: engine.currentPhase) { newPhase in
            let duration: Double
            if newPhase == .inhale {
                duration = engine.mode.inhale
            } else if newPhase == .exhale {
                duration = engine.mode.exhale
            } else {
                duration = 0.5
            }
            withAnimation(.easeOut(duration: duration)) {
                scale = newPhase == .inhale ? 1.3 : 0.8
                glow = newPhase == .holdInhale || newPhase == .holdExhale ? 0.7 : 0.3
            }
        }
        .onChange(of: engine.phaseTimeRemaining) { _ in
            if engine.currentPhase == .holdInhale || engine.currentPhase == .holdExhale {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    scale = scale == 1.0 ? 1.05 : 1.0
                    glow = glow == 0.7 ? 0.9 : 0.7
                }
            }
        }
    }
}

// Main Content View with Tab Bar
struct MainContentView: View {
    @EnvironmentObject var appState: AppState
  
    var body: some View {
        if appState.disclaimerShowed {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
              
                ProgramsView()
                    .tabItem {
                        Label("Programs", systemImage: "book")
                    }
              
                StatsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar")
                    }
            }
            .font(.system(.body, design: .rounded)) // SF Pro approximation
            .accentColor(.blue)
        } else {
            MedicalDisclaimerView()
                .environmentObject(appState)
        }
    }
}

struct MedicalDisclaimerView: View {
    
    @EnvironmentObject var appState: AppState
    
    private let disclaimerText = """
Pulse Breath is designed for relaxation, stress reduction, focus improvement, and general wellness purposes only.

It is not a medical device and is not intended to diagnose, treat, cure, or prevent any disease or health condition.

The breathing techniques included are publicly available practices popularized by various experts and researchers. They are provided for educational and wellness purposes.

Always consult a qualified healthcare professional before beginning any breathing exercises, especially if you have:
• Respiratory conditions (asthma, COPD, etc.)
• Cardiovascular conditions
• Anxiety or panic disorders
• High or low blood pressure
• Are pregnant
• Any other medical condition

Stop immediately if you experience dizziness, lightheadedness, discomfort, or any unusual symptoms.

Never perform guided breathing exercises while driving, operating heavy machinery, swimming, or in any situation where altered breathing could pose a risk.

Sources & References:
• 4-7-8 Breathing – Dr. Andrew Weil
  drweil.com
• Box Breathing – Used by U.S. Navy SEALs, Mark Divine
• Coherent Breathing (5.5 sec) – HeartMath Institute research
• General techniques are based on publicly available pranayama and mindfulness practices
"""

    var body: some View {
        ZStack {
            appBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header
                    HStack {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.pink.opacity(0.9))
                            .shadow(color: .pink.opacity(0.4), radius: 10)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pulse Breath")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    
                    Text("Important Safety Information")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Please read before using")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    
                    // Main disclaimer box
                    Text(disclaimerText)
                        .font(.system(size: 17, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .lineSpacing(6)
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    // Final note
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green.opacity(0.9))
                        Text("Your safety is our top priority")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.green.opacity(0.9))
                        Spacer()
                    }
                    .padding(.top, 8)
                    
                    
                    Button {
                        appState.disclaimerShowed = true
                    } label: {
                        Text("I have read and understood")
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.accentColor.opacity(0.95))
                                    .shadow(color: .accentColor.opacity(0.5), radius: 10)
                            )
                    }
                    
                }
                .padding(24)
            }
        }
        .navigationTitle("Safety & Disclaimer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Screen 2: Home — Breathing Session
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var sessionDuration: Double = 300 // 5 min default
    @State private var customDuration: Double = 300
    @State private var showCustomDuration: Bool = false
    @State private var showResetMessage: Bool = false
  
    @StateObject private var engine = BreathingEngine(mode: BreathingMode.sleep, sessionDuration: 300, onPhaseChange: {})
  
    let durations: [Double] = [30, 60, 180, 300, 600, 1200] // 1,3,5,10,20 min
  
    func formatDuration(_ dur: Double) -> String {
        let min = Int(dur / 60)
        let sec = Int(dur.truncatingRemainder(dividingBy: 60))
        if sec == 0 {
            return "\(min) min"
        } else {
            return "\(min):\(sec < 10 ? "0" : "")\(sec)"
        }
    }
  
    var ringsSection: some View {
        Group {
            PulsatingRings(color: appState.selectedMode.color, engine: engine)
                .frame(height: 300)
                .onTapGesture {
                    if engine.isRunning {
                        engine.pause()
                    } else {
                        engine.start()
                    }
                }
          
            Text(phaseText)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
          
            Text("\(Int(engine.phaseTimeRemaining)) sec")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
          
            controlButtons
            
            Button {
                appState.selectedMode = .panicRelief
                engine.mode = .panicRelief
                engine.sessionDuration = 60 // 1 минута
                engine.start()
            } label: {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.red)
                    Text("Quick rescuer (alarm)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                    Text("You're safe. Just breathe with me.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.25))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.red.opacity(0.6), lineWidth: 2)
                )
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
    }
  
    var timerChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(durations, id: \.self) { dur in
                    Button(formatDuration(dur)) {
                        sessionDuration = dur
                        engine.sessionDuration = dur
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(sessionDuration == dur ? Color.blue : Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }
  
    var controlButtons: some View {
        HStack(spacing: 40) {
            Button(action: {
                if engine.isRunning {
                    engine.pause()
                } else {
                  engine.start()
                }
            }) {
                Image(systemName: engine.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(appState.selectedMode.color)
            }
          
            Button(action: {
                engine.reset()
                showResetMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showResetMessage = false
                }
            }) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 20)
    }
    
    var personalRecommendation: String? {
        guard !appState.sessions.isEmpty else { return nil }
        
        let eveningSessions = appState.sessions.filter {
            let hour = Calendar.current.component(.hour, from: $0.date)
            return hour >= 20 || hour < 6
        }
        
        let eveningRatio = Double(eveningSessions.count) / Double(appState.sessions.count)
        
        if eveningRatio > 0.6 {
            return "Ты чаще всего дышишь вечером — попробуй программу «Before Sleep»"
        } else if appState.sessions.filter({ $0.mode.name == "Focus" }).count > 5 {
            return "Ты любишь режим Focus — отличный выбор для концентрации!"
        } else if appState.streakCount >= 7 {
            return "Ты на \(appState.streakCount)-дневном стрике! Продолжай в том же духе"
        }
        
        return nil
    }
  
    var modesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Modes")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(BreathingMode.predefined) { mode in
                    EnhancedModeCard(mode: mode)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 150) // Increased bottom padding for more scroll space
    }
  
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let recommendation = personalRecommendation {
                    Text("Recomendation: \(recommendation)")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.yellow.opacity(0.9))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(16)
                        .padding(.horizontal)
                }
                ringsSection
                if showResetMessage {
                    Text("Your session has been reset. Start a new one?")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.5))
                        .cornerRadius(10)
                }
                timerChips
                modesSection
            }
            .padding(.top, 20)
        }
        .background(appBackground)
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            engine.mode = appState.selectedMode
            engine.sessionDuration = sessionDuration
            engine.onPhaseChange = {
                appState.triggerHaptic()
                appState.playClickSound()
            }
            engine.onSessionEnd = { duration, completed in
                let log = SessionLog(date: Date(), mode: appState.selectedMode, duration: duration, isCompleted: completed)
                appState.sessions.append(log)
                
                if completed && duration >= 30 {
                    appState.updateStreakIfNeeded()
                }
            }
        }
        .onChange(of: appState.selectedMode) { newMode in
            engine.mode = newMode
        }
        .onChange(of: sessionDuration) { newDuration in
            engine.sessionDuration = newDuration
        }
        .sheet(isPresented: $showCustomDuration) {
            VStack(spacing: 20) {
                Text("Custom Duration")
                    .font(.headline)
                    .foregroundColor(.white)
                Slider(value: $customDuration, in: 60...3600, step: 60) {
                    Text(formatDuration(customDuration))
                }
                .accentColor(.blue)
                Button("Save") {
                    sessionDuration = customDuration
                    engine.sessionDuration = customDuration
                    showCustomDuration = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(appBackground)
        }
    }
  
    var phaseText: String {
        switch engine.currentPhase {
        case .inhale: return NSLocalizedString("Inhale", comment: "")
        case .holdInhale: return NSLocalizedString("Hold", comment: "")
        case .exhale: return NSLocalizedString("Exhale", comment: "")
        case .holdExhale: return NSLocalizedString("Hold", comment: "")
        }
    }
}

struct EnhancedModeCard: View {
    let mode: BreathingMode
    @EnvironmentObject var appState: AppState
  
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mode.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            Text(mode.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Button("Start") {
                appState.selectedMode = mode
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(mode.color.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(8)
            
            if let source = mode.sourceInfo {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.white.opacity(0.7))
                    Link(source.title, destination: URL(string: source.url)!)
                        .font(.caption)
                        .foregroundColor(mode.color)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(minHeight: 150)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .shadow(color: mode.color.opacity(0.5), radius: 5, x: 0, y: 0)
        .onTapGesture {
            // Optional: preview or something
        }
    }
}

// Screen 5: Programs
struct ProgramsView: View {
    @EnvironmentObject var appState: AppState
  
    func formatDuration(_ dur: Double) -> String {
        let min = Int(dur / 60)
        let sec = Int(dur.truncatingRemainder(dividingBy: 60))
        if sec == 0 {
            return "\(min) min"
        } else {
            return "\(min):\(sec < 10 ? "0" : "")\(sec)"
        }
    }
  
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach($appState.programs) { $program in
                        ProgramCard(program: $program)
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        appState.programs.append(Program(name: "New Program", duration: 300, days: 7, mode: .relax))
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .background(appBackground)
            .foregroundColor(.white)
        }
    }
}

struct Program: Identifiable, Codable {
    let id: UUID
    var name: String
    var duration: Double // per session
    var days: Int
    var mode: BreathingMode
    var progress: Int = 0 // current day
    var reminders: [Date] = [] // reminder times
  
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case duration
        case days
        case mode
        case progress
        case reminders
    }
  
    init(id: UUID = UUID(), name: String, duration: Double, days: Int, mode: BreathingMode, progress: Int = 0, reminders: [Date] = []) {
        self.id = id
        self.name = name
        self.duration = duration
        self.days = days
        self.mode = mode
        self.progress = progress
        self.reminders = reminders
    }
  
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        duration = try container.decode(Double.self, forKey: .duration)
        days = try container.decode(Int.self, forKey: .days)
        mode = try container.decode(BreathingMode.self, forKey: .mode)
        progress = try container.decode(Int.self, forKey: .progress)
        reminders = try container.decode([Date].self, forKey: .reminders)
    }
  
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(duration, forKey: .duration)
        try container.encode(days, forKey: .days)
        try container.encode(mode, forKey: .mode)
        try container.encode(progress, forKey: .progress)
        try container.encode(reminders, forKey: .reminders)
    }
}

struct ProgramCard: View {
    @Binding var program: Program
    @State private var showDetails: Bool = false
    @State private var reminderTime: Date = Date()
    @State private var showEdit: Bool = false
    @State private var editedName: String = ""
    @State private var editedDuration: Double = 300
    @State private var editedDays: Int = 7
  
    @EnvironmentObject var appState: AppState
  
    func formatDuration(_ dur: Double) -> String {
        let min = Int(dur / 60)
        let sec = Int(dur.truncatingRemainder(dividingBy: 60))
        if sec == 0 {
            return "\(min) min"
        } else {
            return "\(min):\(sec < 10 ? "0" : "")\(sec)"
        }
    }
  
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(program.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(program.progress)/\(program.days) days")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.8))
                    .clipShape(Capsule())
            }
            Text("\(formatDuration(program.duration)) × \(program.days) days")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Text("Mode: \(program.mode.name)")
                .font(.subheadline)
                .foregroundColor(program.mode.color)
            if let source = program.mode.sourceInfo {
                Text("Source: \(source.title)")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        if let url = URL(string: source.url) {
                            UIApplication.shared.open(url)
                        }
                    }
            }
          
            if showDetails {
                ForEach(1...program.days, id: \.self) { day in
                    HStack {
                        Text("Day \(day)")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: day <= program.progress ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(day <= program.progress ? .green : .white.opacity(0.6))
                            .onTapGesture {
                                if day == program.progress + 1 {
                                    program.progress += 1
                                    appState.saveData()
                                } else if day == program.progress {
                                    program.progress -= 1
                                    appState.saveData()
                                }
                            }
                    }
              
                }
              
                VStack(alignment: .leading) {
                    Text("Reminders")
                        .foregroundColor(.white)
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .foregroundColor(.white)
                    Button("Add Reminder") {
                        program.reminders.append(reminderTime)
                        appState.saveData()
                        // Schedule notification
                    }
                    ForEach(program.reminders, id: \.self) { time in
                        Text(time.formatted(date: .omitted, time: .shortened))
                            .foregroundColor(.white)
                    }
                }
                Button("Edit Program") {
                    editedName = program.name
                    editedDuration = program.duration
                    editedDays = program.days
                    showEdit = true
                }
                .foregroundColor(.blue)
            }
          
            Button(showDetails ? "Hide Details" : "Show Details") {
                showDetails.toggle()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(20)
        }
        .padding()
        .background(appBackground)
        .cornerRadius(16)
        .fullScreenCover(isPresented: $showEdit) {
            VStack {
                Text("Edit Program")
                    .font(.headline)
                    .foregroundColor(.white)
                TextField("Name", text: $editedName)
                    .foregroundColor(.white)
                HStack {
                    Text("Duration")
                        .foregroundColor(.white)
                    Slider(value: $editedDuration, in: 60...3600, step: 60)
                    Text(formatDuration(editedDuration))
                        .foregroundColor(.white)
                }
                HStack {
                    Text("Days")
                        .foregroundColor(.white)
                    Stepper(value: $editedDays, in: 1...30) {
                        Text("\(editedDays)")
                            .foregroundColor(.white)
                    }
                }
                Button("Save") {
                    program.name = editedName
                    program.duration = editedDuration
                    program.days = editedDays
                    showEdit = false
                    appState.saveData()
                }
                .foregroundColor(.blue)
            }
            .padding()
            .background(appBackground)
            .edgesIgnoringSafeArea(.all)
        }
    }
}

// Screen 9: Stats
struct StatsView: View {
    @EnvironmentObject var appState: AppState
  
    var totalTime: Double {
        appState.sessions.reduce(0) { $0 + $1.duration }
    }
  
    func formattedTime(totalTime: Double) -> String {
        let hours = Int(totalTime / 3600)
        let minutes = Int((totalTime.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(totalTime.truncatingRemainder(dividingBy: 60))
        return "\(hours) hours, \(minutes) min, \(seconds) sec"
    }
  
    func formatDuration(_ dur: Double) -> String {
        let min = Int(dur / 60)
        let sec = Int(dur.truncatingRemainder(dividingBy: 60))
        if sec == 0 {
            return "\(min) min"
        } else {
            return "\(min):\(sec < 10 ? "0" : "")\(sec)"
        }
    }
  
    // Add more metrics
  
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                StatCard(title: "Total Time", value: formattedTime(totalTime: totalTime), icon: "clock")
                StatCard(title: "Sessions Completed", value: "\(appState.sessions.filter { $0.isCompleted }.count)", icon: "waveform.path.ecg")
                
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(appState.streakCount > 0 ? .orange : .gray)
                        .font(.system(size: 32))
                        .scaleEffect(appState.streakCount >= 7 ? 1.3 : 1.0)
                        .animation(.spring(), value: appState.streakCount)
                    
                    VStack(alignment: .leading) {
                        Text("\(appState.streakCount) day streak")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text(appState.streakCount >= 7 ? "Your legend!" : "Continue")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                
                Text("Session History")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ScrollView {
                    ForEach(appState.sessions.reversed()) { session in
                        HStack {
                            Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.white)
                            Spacer()
                            Text(session.mode.name)
                                .foregroundColor(session.mode.color)
                            Text(formatDuration(session.duration))
                                .foregroundColor(.white)
                            if !session.isCompleted {
                                Text(" (partial)")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding()
                        .background(Color(hex: "#0D0D1A").opacity(0.8))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 20) // Padding to not touch edges
                }
                
                Button {
                    UIApplication.shared.open(URL(string: "https://pullsebrreath.com/privacy-policy.html")!)
                } label: {
                    Text("Privacy policy")
                        .foregroundColor(.white)
                        .underline()
                }
            }
            .navigationTitle("")
            .padding(.horizontal, 20) // Padding to not touch edges
            .background(appBackground)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
  
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.blue)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                Text(value)
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#0D0D1A").opacity(0.8))
        .cornerRadius(16)
    }
}

// Screen 11: Onboarding (Show on first launch)
struct OnboardingView: View {
    @State private var step = 0
  
    var body: some View {
        VStack {
            if step == 0 {
                Text("Goal: Sleep/Stress/Focus")
                    .foregroundColor(.white)
                // Pickers
            } else if step == 1 {
                Text("Experience Level")
                    .foregroundColor(.white)
            } else if step == 2 {
                Text("Permissions")
                    .foregroundColor(.white)
                Button("Allow Notifications") { /* Request */ }
                    .foregroundColor(.blue)
            }
            Button("Next") { step += 1 }
                .foregroundColor(.blue)
        }
        .background(appBackground)
    }
}


final class BreathConductor: ObservableObject {
    
    @Published var flowState: FlowPhase = .inhaling
    @Published var targetBreathURL: URL?
    @Published var showBreathPermission = false
    
    private var energySignature: [AnyHashable: Any] = [:]
    private var auraPath: [AnyHashable: Any] = [:]
    private var observers = Set<AnyCancellable>()
    private let pulseMonitor = NWPathMonitor()
    
    private var isFirstBreath: Bool {
        !UserDefaults.standard.bool(forKey: "hasEverRunBefore")
    }
    
    enum FlowPhase {
        case inhaling
        case flowing
        case oldPath
        case noAir
    }
    
    init() {
        tuneIntoEnergyStreams()
        startPulseMonitoring()
    }
    
    deinit {
        pulseMonitor.cancel()
    }
    
    private func tuneIntoEnergyStreams() {
        NotificationCenter.default.publisher(for: Notification.Name("ConversionDataReceived"))
            .compactMap { $0.userInfo?["conversionData"] as? [AnyHashable: Any] }
            .sink { [weak self] signature in
                self?.energySignature = signature
                self?.alignBreathFlow()
            }
            .store(in: &observers)
        
        NotificationCenter.default.publisher(for: Notification.Name("deeplink_values"))
            .compactMap { $0.userInfo?["deeplinksData"] as? [AnyHashable: Any] }
            .sink { [weak self] path in
                self?.auraPath = path
            }
            .store(in: &observers)
    }
    
    @objc private func alignBreathFlow() {
        guard !energySignature.isEmpty else {
            followLastKnownBreath()
            return
        }
        
        if UserDefaults.standard.string(forKey: "app_mode") == "Funtik" {
            returnToOldFlow()
            return
        }
        
//        if isFirstBreath, energySignature["af_status"] as? String == "Organic" {
//            beginFirstBreathRitual()
//            return
//        }
        
        if let quickInhale = UserDefaults.standard.string(forKey: "temp_url"),
           let url = URL(string: quickInhale) {
            targetBreathURL = url
            transition(to: .flowing)
            return
        }
        
        if targetBreathURL == nil {
            if shouldOfferBreathAwareness() {
                showBreathPermission = true
            } else {
                consultCosmicFlow()
            }
        }
    }
    
    private func startPulseMonitoring() {
        pulseMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status != .satisfied {
                    self?.energyBlockage()
                }
            }
        }
        pulseMonitor.start(queue: .global())
    }
    
    private func energyBlockage() {
        let mode = UserDefaults.standard.string(forKey: "app_mode") ?? ""
        if mode == "HenView" {
            transition(to: .noAir)
        } else {
            returnToOldFlow()
        }
    }
    
    private func beginFirstBreathRitual() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            Task { await self.invokeLifeForceOracle() }
        }
    }
    
    private func invokeLifeForceOracle() async {
        let ritual = LifeForceOracle()
            .withSourceID(AppConstants.appsFlyerAppID)
            .withKey(AppConstants.appsFlyerDevKey)
            .withSoulID(AppsFlyerLib.shared().getAppsFlyerUID())
        
        guard let portal = ritual.openChannel() else {
            returnToOldFlow()
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: portal)
            try await absorbCosmicResponse(data: data, response: response)
        } catch {
            returnToOldFlow()
        }
    }
    
    private func absorbCosmicResponse(data: Data, response: URLResponse) async throws {
        guard
            let http = response as? HTTPURLResponse,
            http.statusCode == 200,
            let vision = try? JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
        else {
            returnToOldFlow()
            return
        }
        
        var fullAura = vision
        for (k, v) in auraPath where fullAura[k] == nil {
            fullAura[k] = v
        }
        
        await MainActor.run {
            energySignature = fullAura
            consultCosmicFlow()
        }
    }
    
    // MARK: - Консультация с космическим потоком
    private func consultCosmicFlow() {
        guard let gate = URL(string: "https://pullsebrreath.com/config.php") else {
            followLastKnownBreath()
            return
        }
        
        var essence = energySignature
        essence["os"] = "iOS"
        essence["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        essence["bundle_id"] = "com.alarmsapp.ChickAlarm"
        essence["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        essence["store_id"] = "id\(AppConstants.appsFlyerAppID)"
        essence["push_token"] = UserDefaults.standard.string(forKey: "fcm_token") ?? Messaging.messaging().fcmToken
        essence["locale"] = (Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN")
        
        guard let breathPacket = try? JSONSerialization.data(withJSONObject: essence) else {
            followLastKnownBreath()
            return
        }
        
        var prayer = URLRequest(url: gate)
        prayer.httpMethod = "POST"
        prayer.setValue("application/json", forHTTPHeaderField: "Content-Type")
        prayer.httpBody = breathPacket
        
        URLSession.shared.dataTask(with: prayer) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let aligned = response["ok"] as? Bool, aligned == true,
                  let sacredFlow = response["url"] as? String,
                  let url = URL(string: sacredFlow)
            else {
                self?.followLastKnownBreath()
                return
            }
            
            DispatchQueue.main.async {
                self?.memorizeSacredFlow(url: sacredFlow)
                self?.targetBreathURL = url
                self?.transition(to: .flowing)
            }
        }.resume()
    }
    
    private func memorizeSacredFlow(url: String) {
        UserDefaults.standard.set(url, forKey: "saved_trail")
        UserDefaults.standard.set("HenView", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasEverRunBefore")
    }
    
    private func followLastKnownBreath() {
        if let knownFlow = UserDefaults.standard.string(forKey: "saved_trail"),
           let url = URL(string: knownFlow) {
            targetBreathURL = url
            transition(to: .flowing)
        } else {
            returnToOldFlow()
        }
    }
    
    private func returnToOldFlow() {
        UserDefaults.standard.set("Funtik", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasEverRunBefore")
        transition(to: .oldPath)
    }
    
    private func shouldOfferBreathAwareness() -> Bool {
        guard !UserDefaults.standard.bool(forKey: "accepted_notifications"),
              !UserDefaults.standard.bool(forKey: "system_close_notifications")
        else { return false }
        
        if let lastOffer = UserDefaults.standard.object(forKey: "last_notification_ask") as? Date,
           Date().timeIntervalSince(lastOffer) < 259200 {
            return false
        }
        return true
    }
    
    func declineBreathAwareness() {
        UserDefaults.standard.set(Date(), forKey: "last_notification_ask")
        showBreathPermission = false
        consultCosmicFlow()
    }
    
    func acceptBreathAwareness() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                UserDefaults.standard.set(granted, forKey: "accepted_notifications")
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    UserDefaults.standard.set(true, forKey: "system_close_notifications")
                }
                self?.showBreathPermission = false
                self?.consultCosmicFlow()
            }
        }
    }
    
    private func transition(to phase: FlowPhase) {
        DispatchQueue.main.async {
            self.flowState = phase
        }
    }
}

private struct LifeForceOracle {
    private let channel = "https://gcdsdk.appsflyer.com/install_data/v4.0/"
    private var sourceID = ""
    private var key = ""
    private var soulID = ""
    
    func withSourceID(_ id: String) -> Self { updating(\.sourceID, id) }
    func withKey(_ k: String) -> Self { updating(\.key, k) }
    func withSoulID(_ s: String) -> Self { updating(\.soulID, s) }
    
    func openChannel() -> URL? {
        guard !sourceID.isEmpty, !key.isEmpty, !soulID.isEmpty else { return nil }
        var comp = URLComponents(string: channel + "id" + sourceID)!
        comp.queryItems = [
            URLQueryItem(name: "devkey", value: key),
            URLQueryItem(name: "device_id", value: soulID)
        ]
        return comp.url
    }
    
    private func updating<T>(_ kp: WritableKeyPath<Self, T>, _ v: T) -> Self {
        var copy = self
        copy[keyPath: kp] = v
        return copy
    }
}

struct PulseBreathEntry: View {
    @StateObject private var conductor = BreathConductor()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            if conductor.flowState == .inhaling || conductor.showBreathPermission {
                BreathLoadingView()
            }
            
            if conductor.showBreathPermission {
                BreathPermissionOverlay(
                    onAccept: conductor.acceptBreathAwareness,
                    onDecline: conductor.declineBreathAwareness
                )
            } else {
                activeFlow
            }
        }
    }
    
    @ViewBuilder
    private var activeFlow: some View {
        switch conductor.flowState {
        case .inhaling: EmptyView()
        case .flowing:
            if conductor.targetBreathURL != nil {
                PulseBreathView()
            } else {
                MainContentView()
                    .environmentObject(appState)
                    .preferredColorScheme(.dark)
            }
        case .oldPath:
            MainContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        case .noAir:
            NoEnergyView()
        }
    }
}

#Preview {
    BreathPermissionOverlay {
        
    } onDecline: {
        
    }
}

struct BreathLoadingView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("splash_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
                
                Image("ball")
                    .resizable()
                    .frame(width: 300, height: 300)
                
                VStack {
                    Spacer()
                    Image("loading_ic")
                        .resizable()
                        .frame(width: 200, height: 70)
                    InfiniteLinearProgressBar()
                        .frame(width: 350)
                    Spacer().frame(height: 80)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct InfiniteLinearProgressBar: View {
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Трек (фон)
                Capsule()
                    .fill(Color(.systemGray4))
                
                // Движущаяся полоса
                Capsule()
                    .fill(.white)
                    .frame(width: geometry.size.width * 0.3) // 30% ширины — оптимально
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.4)
                    .animation(
                        Animation.linear(duration: 1.6)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
        }
        .frame(height: 5) // толщина полоски
        .cornerRadius(2.5)
        .onAppear {
            isAnimating = true
        }
    }
}

struct NoEnergyView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("no_internet_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
                
                VStack {
                    Image("no_internet_plashka")
                        .resizable()
                        .frame(width: 300, height: 280)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct BreathPermissionOverlay: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            ZStack {
                Image("notifications_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
                
                VStack(spacing: landscape ? 5 : 10) {
                    Spacer()
                    Text("Allow notifications about bonuses and promos".uppercased())
                        .font(.custom("AlfaSlabOne-Regular", size: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .shadow(color: Color(hex: "#456CE1"), radius: 1, x: -1, y: 0)
                        .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 1, y: 0)
                        .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 0, y: 1)
                        .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 0, y: -1)
                    
                    Text("Stay tuned with best offers from our casino")
                        .font(.custom("AlfaSlabOne-Regular", size: 15))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 52)
                        .padding(.top, 4)
                    
                    Button(action: onAccept) {
                        Image("btn_accept")
                            .resizable()
                            .frame(height: 60)
                    }
                    .frame(width: 350)
                    .padding(.top, 12)
                    
                    Button("SKIP", action: onDecline)
                        .font(.custom("AlfaSlabOne-Regular", size: 16))
                        .foregroundColor(.white)
                    
                    Spacer().frame(height: landscape ? 30 : 30)
                }
                .padding(.horizontal, landscape ? 20 : 0)
            }
        }
        .ignoresSafeArea()
    }
}


final class PulsingAppMainViDele: NSObject, WKNavigationDelegate, WKUIDelegate {
    
    private var pulseStreak = 0
    
    init(watching coop: PulsingContainerController) {
        self.pulsingContainer = coop
        super.init()
    }
    
    private var pulsingContainer: PulsingContainerController
    
    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    // Открытие новых гнёзд (popup)
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard action.targetFrame == nil else { return nil }
        
        let pulsingNewsdad = PulsingtingAPpHandler.summonBirdNest(with: configuration)
        configureNewPulsitings(pulsingNewsdad)
        setUpRaisingToPulsitings(pulsingNewsdad)
        
        pulsingContainer.extraPulsitingsDevices.append(pulsingNewsdad)
        
        let swipesPuslisign = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleWingSwipe))
        swipesPuslisign.edges = .left
        pulsingNewsdad.addGestureRecognizer(swipesPuslisign)
        
        
        func checkForValidPulsingAc(_ request: URLRequest) -> Bool {
            guard let urlStr = request.url?.absoluteString,
                  !urlStr.isEmpty,
                  urlStr != "about:blank" else { return false }
            return true
        }
        
        if checkForValidPulsingAc(action.request) {
            pulsingNewsdad.load(action.request)
        }
        
        return pulsingNewsdad
    }
    
    private let maxCanProvidePulsingInMinute = 70
    private var lastPulsintingsU: URL?
    
    @objc private func handleWingSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended,
              let pulsitings = gesture.view as? WKWebView else { return }
        
        if pulsitings.canGoBack {
            pulsitings.goBack()
        } else if pulsingContainer.extraPulsitingsDevices.last === pulsitings {
            pulsingContainer.calmTheFlock(returnTo: nil)
        }
    }
    
    // Тишина в курятнике (блокировка зума и жестов)
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let silenceSpell = """
        (function() {
            const vp = document.createElement('meta');
            vp.name = 'viewport';
            vp.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            document.head.appendChild(vp);
            
            const rules = document.createElement('style');
            rules.textContent = 'body { touch-action: pan-x pan-y; } input, textarea { font-size: 16px !important; }';
            document.head.appendChild(rules);
            
            document.addEventListener('gesturestart', e => e.preventDefault());
            document.addEventListener('gesturechange', e => e.preventDefault());
        })();
        """
        
        webView.evaluateJavaScript(silenceSpell) { _, error in
            if let error = error { print("Silence spell failed: \(error)") }
        }
    }
    
    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    private func configureNewPulsitings(_ nest: WKWebView) {
        nest
            .disableAutoConstraints()
            .allowPecking()
            .lockWings(min: 1.0, max: 1.0)
            .noFeatherBounce()
            .enableWingNavigation()
            .assignGuardian(self)
            .placeIn(pulsingContainer.mainPulsingDevice)
    }
    
    // Защита от бесконечного кукарекания (редиректы)
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        pulseStreak += 1
        
        if pulseStreak > maxCanProvidePulsingInMinute {
            webView.stopLoading()
            if let safe = lastPulsintingsU {
                webView.load(URLRequest(url: safe))
            }
            return
        }
        
        lastPulsintingsU = webView.url
        saveMaxStreakPulsing(from: webView)
    }
    
    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects,
           let fallback = lastPulsintingsU {
            webView.load(URLRequest(url: fallback))
        }
    }
    
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        lastPulsintingsU = url
        
        let PulsScheme = (url.scheme ?? "").lowercased()
        let pulsingsUrlString = url.absoluteString.lowercased()
        
        let mustStayInWebView: Set<String> = ["http", "https", "about", "blob", "data", "javascript", "file"]
        let mustStayPrefixes = ["srcdoc", "about:blank", "about:srcdoc"]
        
        let shouldDecisionForPulsing = mustStayInWebView.contains(PulsScheme) ||
        mustStayPrefixes.contains { pulsingsUrlString.hasPrefix($0) } ||
        pulsingsUrlString == "about:blank"
        
        if shouldDecisionForPulsing {
            decisionHandler(.allow)
            return
        }
        
        UIApplication.shared.open(url, options: [:]) { success in
        }
        
        decisionHandler(.cancel)
    }
    
    private func saveMaxStreakPulsing(from webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            var feedBySack: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            
            for cookie in cookies {
                var sack = feedBySack[cookie.domain] ?? [:]
                if let props = cookie.properties {
                    sack[cookie.name] = props
                }
                feedBySack[cookie.domain] = sack
            }
            
            UserDefaults.standard.set(feedBySack, forKey: "preserved_grains")
        }
    }
    
    private func setUpRaisingToPulsitings(_ nest: WKWebView) {
        nest.attachToPerchEdges(pulsingContainer.mainPulsingDevice)
    }
    
}

private extension WKWebView {
    func disableAutoConstraints() -> Self { translatesAutoresizingMaskIntoConstraints = false; return self }
    func assignGuardian(_ guardian: Any) -> Self {
        navigationDelegate = guardian as? WKNavigationDelegate
        uiDelegate = guardian as? WKUIDelegate
        return self
    }
    func allowPecking() -> Self { scrollView.isScrollEnabled = true; return self }
    func lockWings(min: CGFloat, max: CGFloat) -> Self { scrollView.minimumZoomScale = min; scrollView.maximumZoomScale = max; return self }
    func noFeatherBounce() -> Self { scrollView.bounces = false; scrollView.bouncesZoom = false; return self }
    func attachToPerchEdges(_ perch: UIView, insets: UIEdgeInsets = .zero) -> Self {
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: perch.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: perch.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: perch.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: perch.bottomAnchor, constant: -insets.bottom)
        ])
        return self
    }
    func enableWingNavigation() -> Self { allowsBackForwardNavigationGestures = true; return self }
    
    func placeIn(_ perch: UIView) -> Self { perch.addSubview(self); return self }
    
    func configurePerch(minZoom: CGFloat, maxZoom: CGFloat, bounce: Bool) -> Self {
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.bounces = bounce
        scrollView.bouncesZoom = bounce
        return self
    }
}

enum PulsingtingAPpHandler {
    
    static func summonBirdNest(with config: WKWebViewConfiguration? = nil) -> WKWebView {
        let configuration = config ?? defaultCoopRules()
        return WKWebView(frame: .zero, configuration: configuration)
    }
    
    private static func freeFlightRules() -> WKWebpagePreferences {
        WKWebpagePreferences().allowSkyScript()
    }
    
    
    private static func morningRitual() -> WKPreferences {
        WKPreferences()
            .enableChirping()
            .allowFlightCalls()
    }
    
    private static func defaultCoopRules() -> WKWebViewConfiguration {
        WKWebViewConfiguration()
            .allowDawnChorus()
            .silenceAutoPlay()
            .withDawnPreferences(morningRitual())
            .withSkyRules(freeFlightRules())
    }
}

private extension WKWebViewConfiguration {
    func allowDawnChorus() -> Self { allowsInlineMediaPlayback = true; return self }
    func withSkyRules(_ rules: WKWebpagePreferences) -> Self { defaultWebpagePreferences = rules; return self }
    func withDawnPreferences(_ prefs: WKPreferences) -> Self { preferences = prefs; return self }
    func silenceAutoPlay() -> Self { mediaTypesRequiringUserActionForPlayback = []; return self }
    
}

private extension WKPreferences {
    func allowFlightCalls() -> Self { javaScriptCanOpenWindowsAutomatically = true; return self }
    func enableChirping() -> Self { javaScriptEnabled = true; return self }
}

private extension WKWebpagePreferences {
    func allowSkyScript() -> Self { allowsContentJavaScript = true; return self }
}

final class PulsingContainerController: ObservableObject {
    @Published var mainPulsingDevice: WKWebView!
    @Published var extraPulsitingsDevices: [WKWebView] = []
    
    private var observers = Set<AnyCancellable>()
    
    func awaikenPulsingDe() {
        mainPulsingDevice = PulsingtingAPpHandler.summonBirdNest()
            .configurePerch(minZoom: 1.0, maxZoom: 1.0, bounce: false)
            .enableWingNavigation()
    }
    
    func calmTheFlock(returnTo url: URL? = nil) {
        if !extraPulsitingsDevices.isEmpty {
            if let topExtra = extraPulsitingsDevices.last {
                topExtra.removeFromSuperview()
                extraPulsitingsDevices.removeLast()
            }
            if let trail = url {
                mainPulsingDevice.load(URLRequest(url: trail))
            }
        } else if mainPulsingDevice.canGoBack {
            mainPulsingDevice.goBack()
        }
    }
    
    func restoreSavedDataOfPulsatings() {
        guard let saved = UserDefaults.standard.object(forKey: "preserved_grains") as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        
        let feeder = mainPulsingDevice.configuration.websiteDataStore.httpCookieStore
        let grains = saved.values.flatMap { $0.values }.compactMap {
            HTTPCookie(properties: $0 as [HTTPCookiePropertyKey: Any])
        }
        
        grains.forEach { feeder.setCookie($0) }
    }
    
    func refreshDawn() {
        mainPulsingDevice.reload()
    }
    
    
}

struct PulsatingMainView: UIViewRepresentable {
    let wakeUpURL: URL
    
    @StateObject private var flock = PulsingContainerController()
    
    func makeCoordinator() -> PulsingAppMainViDele {
        PulsingAppMainViDele(watching: flock)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        flock.awaikenPulsingDe()
        flock.mainPulsingDevice.uiDelegate = context.coordinator
        flock.mainPulsingDevice.navigationDelegate = context.coordinator
        
        flock.restoreSavedDataOfPulsatings()
        flock.mainPulsingDevice.load(URLRequest(url: wakeUpURL))
        
        return flock.mainPulsingDevice
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct PulseBreathView: View {
    
    @State private var currentPulse = ""
    
    private func ForCheckNeededEarlyPulsatings() {
        if let call = UserDefaults.standard.string(forKey: "temp_url"), !call.isEmpty {
            currentPulse = call
            UserDefaults.standard.removeObject(forKey: "temp_url")
        }
    }
    
    var body: some View {
        ZStack {
            if let url = URL(string: currentPulse) {
                PulsatingMainView(wakeUpURL: url)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: checkMorningCall)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadTempUrl"))) { _ in
            ForCheckNeededEarlyPulsatings()
        }
    }
    
    private func checkMorningCall() {
        let early = UserDefaults.standard.string(forKey: "temp_url")
        let regular = UserDefaults.standard.string(forKey: "saved_trail") ?? ""
        currentPulse = early ?? regular
        
        if early != nil {
            UserDefaults.standard.removeObject(forKey: "temp_url")
        }
    }
    
}
