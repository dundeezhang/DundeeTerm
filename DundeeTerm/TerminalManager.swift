//
//  TerminalManager.swift
//  DundeeTerm
//
//  Created by Dundee Zhang on 2025-08-07.
//

import Foundation
import Network
import Combine

@MainActor
class TerminalManager: ObservableObject {
    @Published var outputLines: [String] = []
    @Published var isConnected = false
    @Published var currentHost = ""
    @Published var currentPrompt = "$ "
    @Published var currentDirectory = ""
    
    private var sshConnection: SSHConnection?
    private let fileManager = FileManager.default
    private var localDirectory: URL
    
    init() {
        // Start in the app's documents directory
        localDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        currentDirectory = localDirectory.path
    }
    
    func initializeLocalTerminal() {
        outputLines.append("DundeeTerm v1.0 - iOS SSH Client")
        outputLines.append("Type 'help' for available commands")
        outputLines.append("Use 'ssh user@host' to connect to remote servers")
        outputLines.append("")
        updatePrompt()
    }
    
    func executeCommand(_ command: String) {
        outputLines.append("\(currentPrompt)\(command)")
        
        let components = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let firstComponent = components.first else { return }
        
        if isConnected {
            // Send command to SSH connection
            Task {
                await sshConnection?.sendCommand(command)
            }
        } else {
            // Handle local commands
            handleLocalCommand(components)
        }
    }
    
    private func handleLocalCommand(_ components: [String]) {
        let command = components[0].lowercased()
        
        switch command {
        case "help":
            showHelp()
        case "ls", "dir":
            listDirectory(components.dropFirst().first)
        case "cd":
            changeDirectory(components.dropFirst().first ?? "")
        case "pwd":
            outputLines.append(currentDirectory)
        case "mkdir":
            if components.count > 1 {
                createDirectory(components[1])
            } else {
                outputLines.append("Usage: mkdir <directory_name>")
            }
        case "touch":
            if components.count > 1 {
                createFile(components[1])
            } else {
                outputLines.append("Usage: touch <file_name>")
            }
        case "cat":
            if components.count > 1 {
                readFile(components[1])
            } else {
                outputLines.append("Usage: cat <file_name>")
            }
        case "rm":
            if components.count > 1 {
                removeItem(components[1])
            } else {
                outputLines.append("Usage: rm <file_or_directory>")
            }
        case "ssh":
            if components.count > 1 {
                parseSSHCommand(components.dropFirst().joined(separator: " "))
            } else {
                outputLines.append("Usage: ssh user@hostname [-p port]")
            }
        case "clear":
            outputLines.removeAll()
        case "whoami":
            outputLines.append("ios_user")
        case "date":
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .medium
            outputLines.append(formatter.string(from: Date()))
        case "echo":
            let message = components.dropFirst().joined(separator: " ")
            outputLines.append(message)
        default:
            outputLines.append("Command not found: \(command)")
            outputLines.append("Type 'help' for available commands")
        }
        
        updatePrompt()
    }
    
    private func showHelp() {
        let helpText = """
        Available Commands:
        
        File System:
        ls, dir          - List directory contents
        cd <path>        - Change directory
        pwd              - Print working directory
        mkdir <name>     - Create directory
        touch <name>     - Create empty file
        cat <file>       - Display file contents
        rm <item>        - Remove file or directory
        
        Network:
        ssh user@host    - Connect to SSH server
        
        System:
        clear            - Clear terminal
        whoami           - Display current user
        date             - Display current date/time
        echo <text>      - Display text
        help             - Show this help message
        """
        
        helpText.components(separatedBy: .newlines).forEach { line in
            outputLines.append(line)
        }
    }
    
    private func listDirectory(_ path: String?) {
        let targetDirectory: URL
        
        if let path = path {
            if path.hasPrefix("/") {
                // absolute
                targetDirectory = URL(fileURLWithPath: localDirectory.path + path)
            } else if path == ".." {
                targetDirectory = localDirectory.deletingLastPathComponent()
            } else {
                // relative path
                targetDirectory = localDirectory.appendingPathComponent(path)
            }
        } else {
            targetDirectory = localDirectory
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: targetDirectory, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [])
            
            for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                let isDirectory = resourceValues.isDirectory ?? false
                let size = resourceValues.fileSize ?? 0
                
                let sizeString = isDirectory ? "<DIR>" : "\(size) bytes"
                let name = item.lastPathComponent
                let prefix = isDirectory ? "📁 " : "📄 "
                
                outputLines.append("\(prefix)\(name.padding(toLength: 30, withPad: " ", startingAt: 0)) \(sizeString)")
            }
            
            if contents.isEmpty {
                outputLines.append("Directory is empty")
            }
        } catch {
            outputLines.append("Error listing directory: \(error.localizedDescription)")
        }
    }
    
    private func changeDirectory(_ path: String) {
        let newDirectory: URL
        
        if path.isEmpty || path == "~" {
            newDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        } else if path == ".." {
            newDirectory = localDirectory.deletingLastPathComponent()
        } else if path.hasPrefix("/") {
            // Absolute path (within app sandbox)
            newDirectory = URL(fileURLWithPath: localDirectory.path + path)
        } else {
            // Relative path
            newDirectory = localDirectory.appendingPathComponent(path)
        }
        
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: newDirectory.path, isDirectory: &isDirectory) && isDirectory.boolValue {
            localDirectory = newDirectory
            currentDirectory = newDirectory.path
            outputLines.append("Changed to: \(currentDirectory)")
        } else {
            outputLines.append("Directory not found: \(path)")
        }
    }
    
    private func createDirectory(_ name: String) {
        let newDirectory = localDirectory.appendingPathComponent(name)
        
        do {
            try fileManager.createDirectory(at: newDirectory, withIntermediateDirectories: false)
            outputLines.append("Created directory: \(name)")
        } catch {
            outputLines.append("Error creating directory: \(error.localizedDescription)")
        }
    }
    
    private func createFile(_ name: String) {
        let newFile = localDirectory.appendingPathComponent(name)
        
        if fileManager.createFile(atPath: newFile.path, contents: Data(), attributes: nil) {
            outputLines.append("Created file: \(name)")
        } else {
            outputLines.append("Error creating file: \(name)")
        }
    }
    
    private func readFile(_ name: String) {
        let file = localDirectory.appendingPathComponent(name)
        
        do {
            let content = try String(contentsOf: file)
            if content.isEmpty {
                outputLines.append("File is empty")
            } else {
                content.components(separatedBy: .newlines).forEach { line in
                    outputLines.append(line)
                }
            }
        } catch {
            outputLines.append("Error reading file: \(error.localizedDescription)")
        }
    }
    
    private func removeItem(_ name: String) {
        let item = localDirectory.appendingPathComponent(name)
        
        do {
            try fileManager.removeItem(at: item)
            outputLines.append("Removed: \(name)")
        } catch {
            outputLines.append("Error removing item: \(error.localizedDescription)")
        }
    }
    
    private func parseSSHCommand(_ sshString: String) {
        // Basic SSH parsing: ssh user@host [-p port]
        let components = sshString.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard let userHost = components.first else {
            outputLines.append("Invalid SSH command")
            return
        }
        
        let parts = userHost.components(separatedBy: "@")
        guard parts.count == 2 else {
            outputLines.append("Invalid format. Use: ssh user@hostname")
            return
        }
        
        let username = parts[0]
        let hostname = parts[1]
        var port = 22
        
        // Check for port parameter
        if let portIndex = components.firstIndex(of: "-p"), portIndex + 1 < components.count {
            port = Int(components[portIndex + 1]) ?? 22
        }
        
        outputLines.append("Connecting to \(hostname) as \(username) on port \(port)...")
        outputLines.append("Note: Use the SSH connection dialog for full authentication")
    }
    
    func connectSSH(host: String, username: String, password: String, port: Int) async {
        sshConnection = SSHConnection()
        let success = await sshConnection?.connect(host: host, username: username, password: password, port: port)
        
        if success == true {
            isConnected = true
            currentHost = "\(username)@\(host)"
            currentPrompt = "\(username)@\(host):~$ "
            outputLines.append("Successfully connected to \(host)")
        } else {
            outputLines.append("Failed to connect to \(host)")
            sshConnection = nil
        }
    }
    
    func disconnect() {
        sshConnection?.disconnect()
        sshConnection = nil
        isConnected = false
        currentHost = ""
        updatePrompt()
        outputLines.append("Disconnected from remote host")
    }
    
    private func updatePrompt() {
        if isConnected {
            currentPrompt = "\(currentHost):~$ "
        } else {
            let dirName = URL(fileURLWithPath: currentDirectory).lastPathComponent
            currentPrompt = "📱 \(dirName) $ "
        }
    }
    
    func addOutput(_ text: String) {
        outputLines.append(text)
    }
}
