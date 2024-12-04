//
//  AppDelegate.swift
//  xorg
//
//  Created by Ryan Smetana on 11/29/24.
//

import AppKit
import Cocoa
import SQLite3

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var timer: Timer?
    var db: OpaquePointer?
    var previousApp: String?
    var usageStartTime: Date?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.action = #selector(showMenu)
            button.title = ""
            button.image = NSImage(systemSymbolName: "timelapse", accessibilityDescription: "App Usage Tracker")
        }
        
        initializeDatabase()
        trackActiveApp()
    }
    
    @objc func showMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Add note...", action: #selector(promptForReflection), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Most Used Apps Report", action: #selector(generateMostUsedAppsReport), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "Reflections Report", action: #selector(generateReflectionCountReport), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Today's Usage Report", action: #selector(generateTodaysUsageReport), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit xorg", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }


//    @objc func showMenu() {
//        let menu = NSMenu()
//        menu.addItem(NSMenuItem(title: "Add note...", action: #selector(promptForReflection), keyEquivalent: "n"))
//        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
//        statusItem?.menu = menu
//        statusItem?.button?.performClick(nil)
//    }

    @objc func promptForReflection() {
        let alert = NSAlert()
        alert.messageText = "What's new?"
        alert.informativeText = "What have you been working on?"
        alert.alertStyle = .informational

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = input

        alert.addButton(withTitle: "Submit")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let text = input.stringValue
            if !text.isEmpty {
                logReflection(note: text)
            }
        }
    }
    
    func trackActiveApp() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName {
                if activeApp == "loginwindow" { return }
                
                guard let previousApp else {
                    previousApp = activeApp
                    return
                }
                
                if activeApp != previousApp {
                    let currentTime = Date()
                    if let startTime = self.usageStartTime {
                        self.logAppUsage(appName: previousApp, startTime: startTime, endTime: currentTime)
                    }

                    self.previousApp = activeApp
                    self.usageStartTime = currentTime
                }
            }
        }
    }
    
    // MARK: - Database Functions
    func logReflection(note: String) {
        guard let db = db else { return }
        let insertQuery = "INSERT INTO REFLECTIONS (timestamp, note) VALUES (?, ?);"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            
            sqlite3_bind_text(statement, 1, (timestamp as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (note as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) == SQLITE_DONE {
                print("Reflection saved: \(note)")
            } else {
                print("Error saving reflection")
            }
        }

        sqlite3_finalize(statement)
    }

    
    func logAppUsage(appName: String, startTime: Date, endTime: Date) {
        guard let db = db else { return }
        let insertQuery = "INSERT INTO AppUsage (appName, startTime, endTime) VALUES (?, ?, ?);"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK {
            let start = ISO8601DateFormatter().string(from: startTime)
            let end = ISO8601DateFormatter().string(from: endTime)
            let seconds = startTime.distance(to: endTime).rounded()
            
            sqlite3_bind_text(statement, 1, (appName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (start as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (end as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                debugPrint("App usage logged: \(appName) from \(startTime) to \(endTime)")
            } else {
                debugPrint("Error logging app usage")
            }
        }

        sqlite3_finalize(statement)
    }

    func initializeDatabase() {
        let fileManager = FileManager.default
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let xorgDir = appSupportDir.appendingPathComponent("xorg")
        let dbURL = xorgDir.appendingPathComponent("AppUsage.sqlite")

        // Ensure the xorg directory exists
        if !fileManager.fileExists(atPath: xorgDir.path) {
            do {
                try fileManager.createDirectory(at: xorgDir, withIntermediateDirectories: true, attributes: nil)
                print("Created xorg directory at \(xorgDir.path)")
            } catch {
                print("Error creating xorg directory: \(error.localizedDescription)")
                return
            }
        }

        // Open or create the database
        if sqlite3_open(dbURL.path, &db) == SQLITE_OK {
            print("Database opened at \(dbURL.path)")

            let createAppUsageTableQuery = """
            CREATE TABLE IF NOT EXISTS AppUsage (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                appName TEXT NOT NULL,
                startTime TEXT NOT NULL,
                endTime TEXT NOT NULL
            );
            """

            let createReflectionsTableQuery = """
            CREATE TABLE IF NOT EXISTS Reflections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                note TEXT NOT NULL
            );
            """

            if sqlite3_exec(db, createAppUsageTableQuery, nil, nil, nil) == SQLITE_OK {
                print("AppUsage table created or already exists")
            } else {
                print("Error creating AppUsage table")
            }

            if sqlite3_exec(db, createReflectionsTableQuery, nil, nil, nil) == SQLITE_OK {
                print("Reflections table created or already exists")
            } else {
                print("Error creating Reflections table")
            }
        } else {
            print("Error opening database")
        }
    }
    
    // MARK: - Reporting
    func saveCSVAndOpen(csvContent: String, filename: String) {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(filename)
        
        do {
            // Write CSV content to the file
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Report saved at \(fileURL.path)")
            
            // Open the file in the default application (e.g., Numbers)
            NSWorkspace.shared.open(fileURL)
        } catch {
            print("Error writing CSV: \(error.localizedDescription)")
        }
    }

    
    @objc func generateMostUsedAppsReport() {
        guard let db = db else { return }
        
        let query = """
        SELECT appName, SUM((julianday(endTime) - julianday(startTime)) * 86400) AS totalTime
        FROM AppUsage
        GROUP BY appName
        ORDER BY totalTime DESC
        LIMIT 5;
        """
        
        var statement: OpaquePointer?
        var csvContent = "App Name,Total Time (seconds)\n"
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let appName = String(cString: sqlite3_column_text(statement, 0))
                let totalTime = sqlite3_column_double(statement, 1)
                csvContent += "\(appName),\(Int(totalTime))\n"
            }
        }
        
        sqlite3_finalize(statement)
        
        // Write to CSV and open in Numbers
        saveCSVAndOpen(csvContent: csvContent, filename: "Most_Used_Apps_Report.csv")
    }

    @objc func generateReflectionCountReport() {
        guard let db = db else { return }
        let query = "SELECT timestamp, note FROM Reflections;"
        
        var statement: OpaquePointer?
        var csvContent = "Timestamp,Note\n"
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let timestamp = String(cString: sqlite3_column_text(statement, 0))
                let note = String(cString: sqlite3_column_text(statement, 1))
                csvContent += "\"\(timestamp)\",\"\(note)\"\n" // Quote strings for CSV compatibility
            }
        }
        
        sqlite3_finalize(statement)
        
        // Write to CSV and open in Numbers
        saveCSVAndOpen(csvContent: csvContent, filename: "Reflections_Report.csv")
    }
    
    @objc func generateTodaysUsageReport() {
        guard let db = db else { return }
        let currentDate = ISO8601DateFormatter().string(from: Date()).prefix(10) // YYYY-MM-DD
        let query = """
        SELECT appName, SUM((julianday(endTime) - julianday(startTime)) * 86400) AS totalTime
        FROM AppUsage
        WHERE DATE(startTime) = ?
        GROUP BY appName
        ORDER BY totalTime DESC;
        """
        
        var statement: OpaquePointer?
        var csvContent = "App Name,Total Time (seconds)\n"
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (currentDate as NSString).utf8String, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let appName = String(cString: sqlite3_column_text(statement, 0))
                let totalTime = sqlite3_column_double(statement, 1)
                csvContent += "\(appName),\(Int(totalTime))\n"
            }
        }
        
        sqlite3_finalize(statement)
        
        // Write to CSV and open in Numbers
        saveCSVAndOpen(csvContent: csvContent, filename: "Todays_Usage_Report.csv")
    }


    
    // MARK: - App Termination
    func stopTimers() {
        timer?.invalidate()
    }

    func closeDatabase() {
        if sqlite3_close(db) == SQLITE_OK {
            print("Database closed successfully")
        } else {
            print("Error closing database")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        stopTimers()
        closeDatabase()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}


// MARK: - MAIN
//
//  main.swift
//  xorg
//
//  Created by Ryan Smetana on 11/29/24.
//

let app = NSApplication.shared
app.delegate = AppDelegate()
app.setActivationPolicy(.accessory)
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
