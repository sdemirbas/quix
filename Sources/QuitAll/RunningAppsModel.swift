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
}

@MainActor
@Observable
final class RunningAppsModel {
    private(set) var apps: [AppInfo] = []
    var searchText: String = ""
    var optionHeld: Bool = false
    var category: AppCategory = .all

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
        guard !query.isEmpty else { return list }
        return list.filter { $0.name.lowercased().contains(query) }
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
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

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
        let targets = filteredApps
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
            let obs = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
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
