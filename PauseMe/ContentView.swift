import SwiftUI
import Combine
import UIKit

private enum PausePalette {
    static let slate = Color(red: 31/255, green: 51/255, blue: 64/255)
    static let teal = Color(red: 79/255, green: 140/255, blue: 138/255)
    static let deep = Color(red: 10/255, green: 54/255, blue: 59/255)
    static let soft = Color(red: 143/255, green: 199/255, blue: 193/255)
    static let paper = Color(red: 247/255, green: 246/255, blue: 243/255)
    static let mist = Color(red: 234/255, green: 242/255, blue: 241/255)
}

private enum PauseTab: Hashable { case home, support, progress, settings }

struct ContentView: View {
    @ObservedObject var session: PauseSession
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("pauseme.preferredMinutes") private var preferredMinutes = 30
    @State private var tab = PauseTab.home
    @State private var confirmRelease = false
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $tab) {
            home.tabItem { Label("Home", systemImage: "house") }.tag(PauseTab.home)
            SupportView().tabItem { Label("Support", systemImage: "leaf") }.tag(PauseTab.support)
            ProgressView(session: session, now: now).tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }.tag(PauseTab.progress)
            SettingsView(session: session, minutes: $preferredMinutes)
                .tabItem { Label("Settings", systemImage: "gearshape") }.tag(PauseTab.settings)
        }
        .tint(PausePalette.teal)
        .preferredColorScheme(.light)
        .onReceive(tick) { now = $0; session.refresh(now: $0) }
        .onChange(of: scenePhase) { phase in
            if phase == .active { now = Date(); session.refresh() }
        }
        .confirmationDialog("End your web pause now?", isPresented: $confirmRelease, titleVisibility: .visible) {
            Button("End pause", role: .destructive) { session.release() }
            Button("Keep pausing", role: .cancel) { }
        }
        .alert("PauseMe", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK") { session.errorMessage = nil }
        } message: { Text(session.errorMessage ?? "") }
    }

    private var home: some View {
        ScrollView {
            VStack(spacing: 26) {
                BrandHeader(light: session.endDate != nil)
                    .padding(.top, 30)
                if let end = session.endDate {
                    activePause(end: end)
                } else if session.checkIn != nil {
                    CheckInView(session: session) { tab = .support }
                } else {
                    readyPause
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 32)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background {
            if session.endDate != nil {
                LinearGradient(colors: [PausePalette.slate, PausePalette.deep], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea(edges: .top)
            } else {
                PausePalette.paper.ignoresSafeArea(edges: .top)
            }
        }
    }

    private var readyPause: some View {
        VStack(spacing: 22) {
            Text("Give yourself\nsome space.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-1).foregroundStyle(PausePalette.slate)
                .multilineTextAlignment(.center)
            Text("When temptation hits,\npress pause.")
                .font(.body).foregroundStyle(PausePalette.slate)
                .multilineTextAlignment(.center)

            if session.authorized {
                Button { session.start(minutes: preferredMinutes) } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "pause.fill").font(.system(size: 46, weight: .bold))
                        Text("PAUSE ME").font(.title2.bold()).tracking(1)
                        Text("\(preferredMinutes) MINUTES").font(.caption.weight(.medium)).tracking(1)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 230, height: 230)
                    .background(LinearGradient(colors: [PausePalette.teal, PausePalette.deep], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: PausePalette.deep.opacity(0.18), radius: 18, y: 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pause websites for \(preferredMinutes) minutes")
                .accessibilityHint("Starts a voluntary Screen Time web restriction")
            } else {
                Image(systemName: "hand.raised.circle")
                    .font(.system(size: 70, weight: .light)).foregroundStyle(PausePalette.teal)
                    .accessibilityHidden(true)
                Text("Allow Screen Time access to start your first pause.")
                    .multilineTextAlignment(.center).foregroundStyle(PausePalette.slate)
                Button(session.requestingPermission ? "Requesting access…" : "Allow Screen Time access") {
                    Task { await session.requestPermission() }
                }
                .buttonStyle(PauseButtonStyle())
                .disabled(session.requestingPermission)
            }

            Picker("Pause duration", selection: $preferredMinutes) {
                ForEach([15, 30, 60], id: \.self) { Text("\($0) min").tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)
            Text("Pause the urge. Protect the moment.")
                .font(.subheadline.weight(.medium)).foregroundStyle(PausePalette.teal)
            Text("A voluntary pause for websites. Coverage depends on the browser and iOS; other app traffic may continue.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Daily check-in") { tab = .progress }
                .font(.subheadline.weight(.semibold))
            Button("Explore your support options") { tab = .support }
                .font(.subheadline.weight(.semibold))
        }
    }

    private func activePause(end: Date) -> some View {
        let remaining = max(0, end.timeIntervalSince(now))
        let total = max(1, end.timeIntervalSince(session.startedAt ?? end.addingTimeInterval(-1800)))
        return VStack(spacing: 24) {
            Text("Your pause is active").font(.title3.weight(.medium)).foregroundStyle(.white)
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 10)
                Circle().trim(from: 0, to: CGFloat(min(1, remaining / total)))
                    .stroke(AngularGradient(colors: [PausePalette.soft, PausePalette.teal, PausePalette.soft], center: .center), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 8) {
                    Text(String(format: "%02d:%02d", Int(ceil(remaining)) / 60, Int(ceil(remaining)) % 60))
                        .font(.system(size: 52, weight: .semibold, design: .rounded)).monospacedDigit()
                        .minimumScaleFactor(0.7).lineLimit(1)
                    Text("Time remaining").font(.subheadline)
                }
                .foregroundStyle(.white)
            }
            .frame(width: 240, height: 240).padding(.vertical, 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Time remaining")
            .accessibilityValue("\(Int(ceil(remaining / 60))) minutes")

            Label("Your web pause is on.", systemImage: "lock.fill")
                .font(.subheadline.weight(.medium)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(18)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
            Text("Until \(end.formatted(date: .omitted, time: .shortened)) · Take this moment for yourself.")
                .font(.caption).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
            VStack(spacing: 12) {
                Button("Extend pause · 15 min", action: session.extend)
                    .buttonStyle(PauseButtonStyle(secondary: true, onDark: true))
                Button("While you pause") { tab = .support }
                    .buttonStyle(PauseButtonStyle(onDark: true))
                Button("End early") { confirmRelease = true }
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8)).padding(.top, 4)
            }
            Text("If access does not return after the pause, reopen PauseMe. You can end your pause here at any time.")
                .font(.caption).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
        }
    }
}

private struct BrandHeader: View {
    var light = false
    var body: some View {
        HStack(spacing: 8) {
            Image("BrandMark").resizable().scaledToFit().frame(width: 36, height: 36)
            Text("pause").foregroundColor(light ? .white : PausePalette.slate)
            + Text("me").foregroundColor(light ? PausePalette.soft : PausePalette.teal)
        }
        .font(.system(size: 27, weight: .bold, design: .rounded))
        .accessibilityElement(children: .ignore).accessibilityLabel("PauseMe")
    }
}

private struct PauseButtonStyle: ButtonStyle {
    var secondary = false
    var onDark = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 15).padding(.horizontal, 18)
            .foregroundStyle(secondary ? (onDark ? .white : PausePalette.teal) : .white)
            .background(secondary ? Color.clear : (onDark ? PausePalette.teal.opacity(0.65) : PausePalette.teal), in: Capsule())
            .overlay(Capsule().strokeBorder(secondary ? (onDark ? .white.opacity(0.6) : PausePalette.teal) : .clear, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private enum SupportOption: String, CaseIterable, Identifiable {
    case breathe, active, thought, connection, triggers
    var id: String { rawValue }
    var title: String {
        switch self {
        case .breathe: return "Take a breath"
        case .active: return "Do something active"
        case .thought: return "Work through it"
        case .connection: return "Talk to someone"
        case .triggers: return "Money & triggers"
        }
    }
    var subtitle: String {
        switch self {
        case .breathe: return "A moment to slow down"
        case .active: return "Shift your focus"
        case .thought: return "Notice what you are feeling"
        case .connection: return "Reach out for support"
        case .triggers: return "Make a little room to reflect"
        }
    }
    var symbol: String {
        switch self {
        case .breathe: return "leaf"
        case .active: return "figure.walk"
        case .thought: return "brain.head.profile"
        case .connection: return "bubble.left.and.bubble.right"
        case .triggers: return "creditcard"
        }
    }
    var guidance: String {
        switch self {
        case .breathe: return "Let your breathing settle at a pace that feels comfortable. Relax your shoulders, feel your feet on the floor, and take your time. There is no target to reach."
        case .active: return "If it feels right for you, stand up, stretch gently, get a glass of water, or move to a different room. Choose one small change of scene."
        case .thought: return "What happened just before the urge? Name what you noticed, without judging yourself. What is one thing you would like to do with the next few minutes?"
        case .connection: return "Think of someone you trust. You could send: ‘I am taking a pause. Could you keep me company for a few minutes?’ Choose whether and how you want to reach out."
        case .triggers: return "You do not need to make a money decision right now. Notice the situation that brought on the urge. Choose one small boundary for this pause, such as stepping away from a payment screen or closing a tempting message."
        }
    }
}

private struct SupportView: View {
    @State private var selected: SupportOption?
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                BrandHeader().padding(.top, 30)
                VStack(spacing: 8) {
                    Text("While you pause").font(.title.bold())
                    Text("Use this time to reset, refocus\nand take care of yourself.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                VStack(spacing: 12) {
                    ForEach(SupportOption.allCases) { option in
                        Button { selected = option } label: {
                            SupportRow(symbol: option.symbol, title: option.title, subtitle: option.subtitle)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Take what helps. There is no right way to spend this moment.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24).padding(.bottom, 30)
            .frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .background(PausePalette.paper)
        .sheet(item: $selected) { option in SupportDetail(option: option) }
    }
}

private struct SupportRow: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: symbol).font(.system(size: 26, weight: .regular))
                .foregroundStyle(PausePalette.teal).frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(PausePalette.slate)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(PausePalette.teal)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(PausePalette.mist, lineWidth: 1))
        .shadow(color: PausePalette.slate.opacity(0.04), radius: 5, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct SupportDetail: View {
    let option: SupportOption
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    ZStack {
                        Circle().fill(PausePalette.mist).frame(width: 150, height: 150)
                            .scaleEffect(expanded ? 1.08 : 0.92)
                            .animation(reduceMotion || option != .breathe ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true), value: expanded)
                        Image(systemName: option.symbol).font(.system(size: 52, weight: .light)).foregroundStyle(PausePalette.teal)
                    }
                    .padding(.top, 28).accessibilityHidden(true)
                    Text(option.title).font(.title.bold())
                    Text(option.guidance).font(.title3).lineSpacing(7).multilineTextAlignment(.center)
                    Button("Back to my pause") { dismiss() }.buttonStyle(PauseButtonStyle())
                }
                .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .background(PausePalette.paper)
            .foregroundStyle(PausePalette.slate)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(PausePalette.teal)
        .onAppear { expanded = true }
    }
}

private struct CheckInView: View {
    @ObservedObject var session: PauseSession
    let showSupport: () -> Void
    @State private var reflection = ""
    @State private var reflecting = false
    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundStyle(PausePalette.teal)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Your pause has ended").font(.title2.bold())
                Text("You created space. That is a positive step.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Text("How are you feeling now?").font(.headline)
            HStack(spacing: 10) {
                ForEach(["Better", "The same", "Worse"], id: \.self) { feeling in
                    Button { session.saveCheckIn(feeling: feeling) } label: {
                        VStack(spacing: 8) {
                            Image(systemName: feeling == "Better" ? "face.smiling" : (feeling == "The same" ? "equal.circle" : "cloud")).font(.title2)
                            Text(feeling).font(.caption.weight(.medium))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .foregroundStyle(session.checkIn?.feeling == feeling ? .white : PausePalette.teal)
                        .background(session.checkIn?.feeling == feeling ? PausePalette.teal : PausePalette.mist, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(session.checkIn?.feeling == feeling ? [.isSelected] : [])
                }
            }
            Text("What would help next?").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 12) {
                Button { session.checkIn = nil } label: { SupportRow(symbol: "pause.circle", title: "Another pause") }.buttonStyle(.plain)
                Button {
                    reflection = session.checkIn?.reflection ?? ""
                    reflecting = true
                } label: { SupportRow(symbol: "square.and.pencil", title: "Reflect on the trigger") }.buttonStyle(.plain)
                Button { showSupport() } label: { SupportRow(symbol: "person.2", title: "See your support options") }.buttonStyle(.plain)
            }
            Button("Back to home") { session.checkIn = nil }.font(.subheadline.weight(.medium))
        }
        .foregroundStyle(PausePalette.slate)
        .sheet(isPresented: $reflecting) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 18) {
                    Text("What brought on the urge? What helped you make space?").font(.headline)
                    TextEditor(text: $reflection).padding(10).background(PausePalette.mist, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel("Your reflection")
                    Text("Optional. Saved with this pause on your phone.").font(.footnote).foregroundStyle(.secondary)
                }
                .padding(24).navigationTitle("A moment to reflect")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { reflecting = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { session.saveCheckIn(reflection: String(reflection.prefix(2000))); reflecting = false }
                    }
                }
            }
            .tint(PausePalette.teal)
        }
    }
}


private struct GamblingLog: Codable {
    enum Answer: String, Codable { case yes, no, skipped }
    var setUp = false
    var startingDay: String?
    var answers: [String: Answer] = [:]

    var lastReportedDay: String? {
        (answers.keys.filter { answers[$0] == .yes } + [startingDay].compactMap { $0 }).max()
    }

    func freeDays(monthOf today: String) -> Int {
        answers.filter { $0.value == .no && $0.key.prefix(7) == today.prefix(7) && $0.key <= today && $0.key != startingDay }.count
    }
}

private struct GamblingCheckIn: View {
    @AppStorage("pauseme.gamblingLog.v1") private var data = Data()
    @State private var selectedDate: Date?
    @State private var startingDate: Date?
    @State private var editingStart = false
    @State private var confirmClear = false

    let now: Date

    private var log: GamblingLog {
        (try? JSONDecoder().decode(GamblingLog.self, from: data)) ?? GamblingLog()
    }

    var body: some View {
        let today = dayKey(now)
        let selectedDay = dayKey(min(selectedDate ?? now, now))
        let currentAnswer = log.answers[selectedDay]

        VStack(alignment: .leading, spacing: 16) {
            Text("Gambling check-in").font(.title2.bold())
            Text("Optional. Your answers are saved locally in PauseMe.")
                .font(.footnote).foregroundStyle(.secondary)
            LabeledContent("Last reported gambling date", value: log.lastReportedDay.map(displayDay) ?? "Not recorded")
            LabeledContent("Gambling-free days logged this month", value: String(log.freeDays(monthOf: today)))

            if !log.setUp || editingStart {
                Divider()
                Text("When did you last gamble?").font(.headline)
                DatePicker("Last gambling date", selection: Binding(
                    get: { min(startingDate ?? now, now) },
                    set: { startingDate = $0 }
                ), in: ...now, displayedComponents: .date)
                Button("Save date") { saveStart(dayKey(min(startingDate ?? now, now))) }
                    .buttonStyle(.borderedProminent)
                HStack {
                    Button("I’m not sure") { saveStart(nil) }
                    Spacer()
                    Button("Skip") {
                        if editingStart {
                            editingStart = false
                        } else {
                            saveStart(nil)
                        }
                    }
                }
            } else {
                Button("Edit starting date") {
                    startingDate = log.startingDay.flatMap(dateFromKey)
                    editingStart = true
                }
                .font(.subheadline)
            }

            Divider()
            DatePicker("Check-in date", selection: Binding(
                get: { min(selectedDate ?? now, now) },
                set: { selectedDate = dayKey($0) == today ? nil : $0 }
            ), in: ...now, displayedComponents: .date)
            Text(selectedDay == today ? "Did you gamble today?" : "Did you gamble that day?")
                .font(.headline)
            HStack {
                answerButton("Yes", answer: .yes, selected: currentAnswer, day: selectedDay)
                answerButton("No", answer: .no, selected: currentAnswer, day: selectedDay)
                answerButton("Skip", answer: .skipped, selected: currentAnswer, day: selectedDay)
            }

            if log.setUp || !log.answers.isEmpty {
                Button("Clear gambling check-ins", role: .destructive) { confirmClear = true }
                    .font(.footnote)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .confirmationDialog("Clear your gambling check-ins?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear check-ins", role: .destructive) {
                data = Data()
                selectedDate = nil
                startingDate = nil
                editingStart = false
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func answerButton(_ title: String, answer: GamblingLog.Answer, selected: GamblingLog.Answer?, day: String) -> some View {
        Button {
            var updated = log
            updated.answers[day] = answer
            save(updated)
        } label: {
            Label(title, systemImage: selected == answer ? "checkmark.circle.fill" : "circle")
        }
        .buttonStyle(.bordered)
        .accessibilityAddTraits(selected == answer ? .isSelected : [])
    }

    private func saveStart(_ day: String?) {
        var updated = log
        updated.setUp = true
        updated.startingDay = day
        save(updated)
        editingStart = false
    }

    private func save(_ updated: GamblingLog) {
        if let encoded = try? JSONEncoder().encode(updated) {
            data = encoded
        }
    }

    // Save calendar days so travel does not move existing check-ins to another date.
    private func dayKey(_ date: Date) -> String {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func dateFromKey(_ key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private func displayDay(_ key: String) -> String {
        dateFromKey(key)?.formatted(date: .abbreviated, time: .omitted) ?? key
    }
}

private struct ProgressView: View {
    @ObservedObject var session: PauseSession
    let now: Date

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BrandHeader().frame(maxWidth: .infinity).padding(.top, 30)
                GamblingCheckIn(now: now)
                Text("Space you have made").font(.title.bold())
                Text("Every pause is a moment to choose what happens next.").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    statistic("\(session.records.count)", label: "Pauses taken")
                    statistic("\(session.records.reduce(0) { $0 + $1.minutes })", label: "Minutes of space")
                }
                if session.records.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "leaf").font(.largeTitle).foregroundStyle(PausePalette.teal)
                        Text("Your first pause starts a new story.").font(.headline)
                        Text("Your finished pauses will appear here.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    Text("Recent pauses").font(.headline)
                    ForEach(session.records.prefix(30)) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: record.completed ? "checkmark.circle" : "pause.circle").foregroundStyle(PausePalette.teal)
                                Text(record.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(record.minutes) min").font(.caption)
                            }
                            Text(record.completed ? "Pause completed" : "Pause ended early").font(.caption).foregroundStyle(.secondary)
                            if let feeling = record.feeling { Text("Afterward: \(feeling)").font(.caption).foregroundStyle(PausePalette.teal) }
                            if let reflection = record.reflection, !reflection.isEmpty { Text(reflection).font(.subheadline) }
                        }
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 30).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .foregroundStyle(PausePalette.slate).background(PausePalette.paper)
    }

    private func statistic(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(PausePalette.teal)
            Text(label).font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        .background(PausePalette.mist, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct SettingsView: View {
    @ObservedObject var session: PauseSession
    @Binding var minutes: Int
    @Environment(\.openURL) private var openURL
    @State private var confirmClear = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Your pause") {
                    Picker("Default duration", selection: $minutes) {
                        ForEach([15, 30, 60], id: \.self) { Text("\($0) minutes").tag($0) }
                    }
                    LabeledContent("Screen Time", value: session.authorized ? "Access allowed" : "Access needed")
                    if !session.authorized {
                        Button("Allow Screen Time access") { Task { await session.requestPermission() } }
                            .disabled(session.requestingPermission)
                    }
                    Button("Open iPhone settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
                Section("Your progress") {
                    Text("Pauses and optional check-ins are saved locally. PauseMe does not need an account.")
                    Button("Delete pause history", role: .destructive) { confirmClear = true }.disabled(session.records.isEmpty)
                }
                Section("About the pause") {
                    Text("PauseMe requests a voluntary Screen Time web filter. Browsers and web views may respect it differently. Native app traffic can continue.")
                    Text("iOS schedules the release. If access has not returned when expected, reopen PauseMe or end the pause early. You can revoke access in iPhone Screen Time settings.")
                    Text("PauseMe creates space for a choice. It does not replace professional support.")
                }
            }
            .scrollContentBackground(.hidden).background(PausePalette.paper)
            .navigationTitle("Settings")
            .confirmationDialog("Delete your saved pause history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete history", role: .destructive) { session.clearHistory() }
                Button("Cancel", role: .cancel) { }
            } message: { Text("This removes pauses and check-ins from this phone. Your active pause is not affected.") }
        }
    }
}
