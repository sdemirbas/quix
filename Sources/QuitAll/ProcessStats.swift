import Foundation

/// Tüm süreçlerin RAM (RSS) ve CPU% değerlerini tek bir `ps` çağrısıyla toplar.
/// `task_for_pid` gerektirmediği için imzalama/entitlement istemez.
enum ProcessStats {
    struct Sample {
        let rssKB: Int
        let cpu: Double
    }

    static func sample() -> [pid_t: Sample] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-A", "-o", "pid=,rss=,pcpu="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return [:]
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        var result: [pid_t: Sample] = [:]
        for line in output.split(separator: "\n") {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                .filter { !$0.isEmpty }
            guard fields.count >= 3,
                  let pid = Int32(fields[0]),
                  let rss = Int(fields[1]),
                  let cpu = Double(fields[2]) else { continue }
            result[pid] = Sample(rssKB: rss, cpu: cpu)
        }
        return result
    }
}
