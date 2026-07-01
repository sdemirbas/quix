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

/// Bekleyen toplu kapatma onayı — hangi uygulamaların kapatılacağını taşır.
struct PendingQuit: Identifiable {
    let id = UUID()
    let title: String
    let apps: [AppInfo]
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
}

@MainActor
@Observable
final class RunningAppsModel {
    private(set) var apps: [AppInfo] = []
    var searchText: String = ""
    var optionHeld: Bool = false
    var category: AppCategory = .all
    var sortOrder: SortOrder = .memory

    /// Popover içi toplu kapatma onayı (dış pencere yok).
    var pendingQuit: PendingQuit?

    // Hızlandırma önerisi eşikleri (Ayarlar'dan seçilir, kalıcı)
    var suggestMemoryMB: Double {
        didSet { UserDefaults.standard.set(suggestMemoryMB, forKey: "suggestMemoryMB") }
    }
    var suggestCPU: Double {
        didSet { UserDefaults.standard.set(suggestCPU, forKey: "suggestCPU") }
    }

    /// Kullanıcının Quix'i açmadan hemen önce kullandığı uygulama — öneri dışı bırakılır.
    private(set) var lastActiveOtherPID: pid_t?

    // Histerezis: bir kez eşiği aşan uygulama, kısa süre "ağır" kalır (flicker önler)
    @ObservationIgnored private var heavyUntil: [pid_t: Date] = [:]
    private let heavyGrace: TimeInterval = 15

    private var statsTimer: Timer?
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var flagsMonitor: Any?
    private var launchObservers: [NSObjectProtocol] = []

    init() {
        let d = UserDefaults.standard
        suggestMemoryMB = d.object(forKey: "suggestMemoryMB") as? Double ?? 780
        suggestCPU = d.object(forKey: "suggestCPU") as? Double ?? 20
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

    /// Şu an eşiği aşıyor mu?
    private func isOverThreshold(_ app: AppInfo) -> Bool {
        Double(app.rssKB) >= suggestMemoryMB * 1024 || app.cpu >= suggestCPU
    }

    /// Eşiği aşan veya kısa süre önce aşmış (histerezisli) aday mı?
    func isHeavy(_ app: AppInfo) -> Bool {
        if isOverThreshold(app) { return true }
        if let until = heavyUntil[app.id], until > Date() { return true }
        return false
    }

    /// "Ağır" durumları güncelle — eşiği aşanların süresini uzat, ölenleri temizle.
    private func updateHeavyTracking() {
        let now = Date()
        for app in apps where isOverThreshold(app) {
            heavyUntil[app.id] = now.addingTimeInterval(heavyGrace)
        }
        let live = Set(apps.map { $0.id })
        heavyUntil = heavyUntil.filter { live.contains($0.key) }
    }

    /// Çok kaynak tüketen ve az önce kullanılmayan uygulamalar (RAM'e göre azalan).
    var suggestions: [AppInfo] {
        apps.filter { isHeavy($0) && $0.id != lastActiveOtherPID }
            .sorted { $0.rssKB > $1.rssKB }
    }

    func isSuggested(_ app: AppInfo) -> Bool {
        isHeavy(app) && app.id != lastActiveOtherPID
    }

    func isActive(_ app: AppInfo) -> Bool {
        app.id == lastActiveOtherPID
    }

    /// Görünen listedeki toplam RAM.
    var totalMemoryText: String {
        let bytes = Double(filteredApps.reduce(0) { $0 + $1.rssKB }) * 1024.0
        let f = ByteCountFormatter()
        f.allowedUnits = [.useMB, .useGB]
        f.countStyle = .memory
        return f.string(fromByteCount: Int64(bytes))
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
        updateHeavyTracking()
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
        updateHeavyTracking()
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

    // MARK: - Satır aksiyonları (sağ tık)

    func revealInFinder(_ app: AppInfo) {
        if let url = app.runningApp.bundleURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func toggleHide(_ app: AppInfo) {
        if app.runningApp.isHidden {
            app.runningApp.unhide()
        } else {
            app.runningApp.hide()
        }
    }

    func requestQuitOthers(_ app: AppInfo) {
        let others = filteredApps.filter { $0.id != app.id }
        requestQuit(others, title: "Diğerlerini Kapat")
    }

    // MARK: - Toplu kapatma onayı (popover içi)

    /// "Hepsini Kapat" → görünen listeyi onaya sun.
    func requestQuitAll() {
        requestQuit(filteredApps,
                    title: optionHeld ? "Hepsini Zorla Kapat" : "Hepsini Kapat")
    }

    /// Öneri banner'ı → önerilenleri onaya sun.
    func requestQuitSuggested() {
        requestQuit(suggestions, title: "Önerilenleri Kapat")
    }

    private func requestQuit(_ apps: [AppInfo], title: String) {
        guard !apps.isEmpty else { return }
        pendingQuit = PendingQuit(title: title, apps: apps)
    }

    func confirmPendingQuit() {
        if let pending = pendingQuit {
            quit(pending.apps, force: optionHeld)
        }
        pendingQuit = nil
    }

    func cancelPendingQuit() {
        pendingQuit = nil
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
