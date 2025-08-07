//
//  SSHConnection.swift
//  DundeeTerm
//
//  Created by Dundee Zhang on 2025-08-07.
//

import Foundation
import Network

class SSHConnection {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "ssh-connection")
    weak var delegate: SSHConnectionDelegate?
    
    private var isAuthenticated = false
    private var host: String = ""
    private var username: String = ""
    
    func connect(host: String, username: String, password: String, port: Int) async -> Bool {
        self.host = host
        self.username = username
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        let parameters = NWParameters.tcp
        
        connection = NWConnection(to: endpoint, using: parameters)
        
        return await withCheckedContinuation { continuation in
            connection?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.delegate?.connectionDidConnect()
                    self?.performSSHHandshake(username: username, password: password) { success in
                        continuation.resume(returning: success)
                    }
                case .failed(let error):
                    self?.delegate?.connectionDidFail(error: error)
                    continuation.resume(returning: false)
                case .cancelled:
                    self?.delegate?.connectionDidDisconnect()
                    continuation.resume(returning: false)
                default:
                    break
                }
            }
            
            connection?.start(queue: queue)
        }
    }
    
    private func performSSHHandshake(username: String, password: String, completion: @escaping (Bool) -> Void) {
        // This is a simplified SSH implementation
        // In a real app, you'd use a proper SSH library like NMSSH or implement the full SSH protocol
        
        // For demo purposes, we'll simulate a successful connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isAuthenticated = true
            self.delegate?.authenticationDidSucceed()
            completion(true)
        }
    }
    
    func sendCommand(_ command: String) async {
        guard isAuthenticated else { return }
        
        // Simulate command execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Simulate some common command responses
            let response = self.simulateCommandResponse(command)
            self.delegate?.didReceiveOutput(response)
        }
    }
    
    private func simulateCommandResponse(_ command: String) -> String {
        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        
        switch trimmedCommand.lowercased() {
        case "ls", "ls -la":
            return """
            total 24
            drwxr-xr-x  5 \(username) users  160 Aug  7 10:30 .
            drwxr-xr-x  3 root     root   120 Aug  1 09:15 ..
            -rw-r--r--  1 \(username) users  220 Aug  1 09:15 .bash_logout
            -rw-r--r--  1 \(username) users 3526 Aug  1 09:15 .bashrc
            -rw-r--r--  1 \(username) users  807 Aug  1 09:15 .profile
            drwxr-xr-x  2 \(username) users   80 Aug  7 10:30 Documents
            drwxr-xr-x  2 \(username) users   80 Aug  7 10:30 Downloads
            """
        case "pwd":
            return "/home/\(username)"
        case "whoami":
            return username
        case "uname -a":
            return "Linux \(host) 5.15.0-generic #72-Ubuntu SMP Fri Aug 4 10:30:00 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux"
        case let cmd where cmd.hasPrefix("cd "):
            return "" // cd usually doesn't output anything on success
        case "date":
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE MMM dd HH:mm:ss UTC yyyy"
            return formatter.string(from: Date())
        case let cmd where cmd.hasPrefix("echo "):
            let message = String(cmd.dropFirst(5))
            return message
        case "help":
            return """
            Available commands:
            ls, pwd, whoami, uname, date, echo, cat, mkdir, rmdir, rm, cp, mv
            Note: This is a simulated SSH session for demo purposes.
            """
        default:
            return "bash: \(trimmedCommand): command not found"
        }
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        isAuthenticated = false
        delegate?.connectionDidDisconnect()
    }
}

protocol SSHConnectionDelegate: AnyObject {
    func connectionDidConnect()
    func connectionDidDisconnect()
    func connectionDidFail(error: Error)
    func authenticationDidSucceed()
    func authenticationDidFail(error: Error)
    func didReceiveOutput(_ output: String)
}
