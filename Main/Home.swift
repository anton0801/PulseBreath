
import SwiftUI
import AVFoundation
import UserNotifications
import Combine

// Global App State
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
  
    // Audio Player
    var audioPlayer: AVAudioPlayer?
  
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "sessions"
    private let programsKey = "programs"
    private let remindersKey = "reminders"
    private let selectedModeKey = "selectedMode"
  
    init() {
        loadData()
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
  
    static var predefined: [BreathingMode] = [.sleep, .focus, .relax, .energy, .box, .coherent]
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

// Previews
#Preview {
    MainContentView()
        .environmentObject(AppState())
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}

#Preview {
    ProgramsView()
        .environmentObject(AppState())
}

#Preview {
    StatsView()
        .environmentObject(AppState())
}

#Preview {
    OnboardingView()
}
