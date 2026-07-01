import AppKit
import Observation

/// Liste kategorileri.
enum AppCategory: String, CaseIterable, Identifiable {
    case all
    case apps
    case menuBar

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Tümü"
        case .apps: return "Uygulamalar"
        case .menuBar: return "Menü Çubuğu"
        }
    }
}

/// Sıralama ölçütü.
enum SortOrder: String, CaseIterable, Identifiable {
    case name
    case memory
    case cpu

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "İsim"
        case .memory: return "RAM"
        case .cpu: return "CPU"
        }
    }
}

/// Tek bir çalışan uygulamanın gösterim modeli.
struct AppInfo: Identifiable {
    let id: pid_t          // process identifier
    let bundleId: String?
    let name: String
    let icon: NSImage?
    let runningApp: NSRunningApplication
    let isMenuBarApp: Bool  // .accessory (Dock'ta yok, menü çubuğunda yaşar)
    var rssKB: Int
    var cpu: Double

    var memoryText: String {
        let bytes = Double(rssKB) * 1024.0
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    var cpuText: String {
        String(format: "%.0f%%", cpu)
    }

    /// Batarya menüsündeki "önemli enerji kullananlar" mantığı: sadece aykırıları işaretle.
    var isHighUsage: Bool {
        cpu >= 25.0
    }

    // Hızlandırma önerisi eşikleri
    static let heavyMemoryKB = 800_000   // ~780 MB
    static let heavyCPU = 20.0

    /// Yüksek kaynak tüketen (kapatınca sistemi rahatlatabilecek) aday.
    var isHeavyConsumer: Bool {
        rssKB >= AppInfo.heavyMemoryKB || cpu >= AppInfo.heavyCPU
    }
}

@MainActor
@Observable
final class RunningAppsModel {
    private(set) var apps: [AppInfo] = []
    var searchText: String = ""
    var optionHeld: Bool = false
    var category: AppCategory = .all
    var sortOrder: SortOrder = .memory

    /// Kullanıcının Quix'i açmadan hemen önce kullandığı uygulama — öneri dışı bırakılır.
    private(set) var lastActiveOtherPID: pid_t?

    private var statsTimer: Timer?
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var flagsMonitor: Any?
    private var launchObservers: [NSObjectProtocol] = []

    init() {
        observeWorkspace()
        observeOptionKey()
        refresh()
    }

    // MARK: - Filtreli liste

    var filteredApps: [AppInfo] {
        var list = apps
        switch category {
        case .all: break
        case .apps: list = list.filter { !$0.isMenuBarApp }
        case .menuBar: list = list.filter { $0.isMenuBarApp }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            list = list.filter { $0.name.lowercased().contains(query) }
        }
        return sorted(list)
    }

    private func sorted(_ list: [AppInfo]) -> [AppInfo] {
        switch sortOrder {
        case .name:
            return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .memory:
            return list.sorted { $0.rssKB > $1.rssKB }
        case .cpu:
            return list.sorted { $0.cpu > $1.cpu }
        }
    }

    // MARK: - Hızlandırma önerileri

    /// Çok kaynak tüketen ve az önce kullanılmayan uygulamalar (RAM'e göre azalan).
    var suggestions: [AppInfo] {
        apps.filter { $0.isHeavyConsumer && $0.id != lastActiveOtherPID }
            .sorted { $0.rssKB > $1.rssKB }
    }

    func isSuggested(_ app: AppInfo) -> Bool {
        app.isHeavyConsumer && app.id != lastActiveOtherPID
    }

    /// Önerilenleri kapatınca boşalacak tahmini RAM.
    var reclaimableText: String {
        let bytes = Double(suggestions.reduce(0) { $0 + $1.rssKB }) * 1024.0
        let f = ByteCountFormatter()
        f.allowedUnits = [.useMB, .useGB]
        f.countStyle = .memory
        return f.string(fromByteCount: Int64(bytes))
    }

    /// Bir kategorideki uygulama sayısı (arama hariç).
    func count(for category: AppCategory) -> Int {
        switch category {
        case .all: return apps.count
        case .apps: return apps.filter { !$0.isMenuBarApp }.count
        case .menuBar: return apps.filter { $0.isMenuBarApp }.count
        }
    }

    // MARK: - Yenileme

    func refresh() {
        // .regular = Dock uygulamaları, .accessory = menü çubuğu (agent) uygulamaları
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular || $0.activationPolicy == .accessory }
            .filter { $0.processIdentifier != ownPID }

        let stats = ProcessStats.sample()

        let updated: [AppInfo] = running.compactMap { app in
            let pid = app.processIdentifier
            let sample = stats[pid]
            return AppInfo(
                id: pid,
                bundleId: app.bundleIdentifier,
                name: app.localizedName ?? app.bundleIdentifier ?? "Bilinmeyen",
                icon: app.icon,
                runningApp: app,
                isMenuBarApp: app.activationPolicy == .accessory,
                rssKB: sample?.rssKB ?? 0,
                cpu: sample?.cpu ?? 0
            )
        }

        apps = updated
    }

    private func updateStats() {
        let stats = ProcessStats.sample()
        var next = apps
        for i in next.indices {
            if let s = stats[next[i].id] {
                next[i].rssKB = s.rssKB
                next[i].cpu = s.cpu
            }
        }
        apps = next
    }

    // MARK: - Timer

    func startStatsTimer() {
        stopStatsTimer()
        let timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
        RunLoop.main.add(timer, forMode: .common)
        statsTimer = timer
    }

    func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    // MARK: - Aksiyonlar

    func quit(_ app: AppInfo) {
        if optionHeld {
            app.runningApp.forceTerminate()
        } else {
            app.runningApp.terminate()
        }
        removeOptimistically([app.id])
    }

    func forceQuit(_ app: AppInfo) {
        app.runningApp.forceTerminate()
        removeOptimistically([app.id])
    }

    func quitAll(force: Bool) {
        quit(filteredApps, force: force)
    }

    /// Hızlandırma önerilerini kapat.
    func quitSuggested(force: Bool) {
        quit(suggestions, force: force)
    }

    private func quit(_ targets: [AppInfo], force: Bool) {
        for app in targets {
            if force {
                app.runningApp.forceTerminate()
            } else {
                app.runningApp.terminate()
            }
        }
        removeOptimistically(Set(targets.map { $0.id }))
    }

    /// Kapatma isteği gönderilince listeden hemen çıkar (anlık geri bildirim),
    /// sonra gerçek durumla eşitle (uygulama kapanmayı reddederse geri gelir).
    private func removeOptimistically(_ ids: Set<pid_t>) {
        apps.removeAll { ids.contains($0.id) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.refresh()
        }
    }

    // MARK: - Gözlemciler

    private func observeWorkspace() {
        let nc = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification
        ]
        for name in names {
            let obs = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self else { return }
                // Öne gelen (Quix hariç) son uygulamayı hatırla → öneri dışı bırak
                if name == NSWorkspace.didActivateApplicationNotification,
                   let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   app.processIdentifier != self.ownPID {
                    self.lastActiveOtherPID = app.processIdentifier
                }
                self.refresh()
            }
            launchObservers.append(obs)
        }
    }

    private func observeOptionKey() {
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.optionHeld = event.modifierFlags.contains(.option)
            return event
        }
    }
}
