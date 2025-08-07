//
//  TerminalView.swift
//  DundeeTerm
//
//  Created by Dundee Zhang on 2025-08-07.
//

import SwiftUI
import Network

struct TerminalView: View {
    @StateObject private var terminalManager = TerminalManager()
    @State private var commandInput = ""
    @State private var showingConnectionSheet = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(terminalManager.isConnected ? "Connected: \(terminalManager.currentHost)" : "Local Terminal")
                    .font(.headline)
                    .foregroundColor(terminalManager.isConnected ? .green : .primary)
                
                Spacer()
                
                Button(action: {
                    showingConnectionSheet = true
                }) {
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(terminalManager.outputLines.indices, id: \.self) { index in
                            Text(terminalManager.outputLines[index])
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding()
                }
                .onChange(of: terminalManager.outputLines.count) { oldValue, newValue in
                    withAnimation {
                        proxy.scrollTo(terminalManager.outputLines.count - 1, anchor: .bottom)
                    }
                }
            }
            
            // command input
            HStack {
                Text(terminalManager.currentPrompt)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                
                TextField("Enter command", text: $commandInput)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit {
                        executeCommand()
                    }
                
                Button("Send") {
                    executeCommand()
                }
                .disabled(commandInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .background(Color.black)
        .foregroundColor(.green)
        .onAppear {
            isInputFocused = true
            terminalManager.initializeLocalTerminal()
        }
        .sheet(isPresented: $showingConnectionSheet) {
            SSHConnectionView(terminalManager: terminalManager)
        }
    }
    
    private func executeCommand() {
        let command = commandInput.trimmingCharacters(in: .whitespaces)
        guard !command.isEmpty else { return }
        
        terminalManager.executeCommand(command)
        commandInput = ""
    }
}

struct SSHConnectionView: View {
    @ObservedObject var terminalManager: TerminalManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var hostname = ""
    @State private var username = ""
    @State private var password = ""
    @State private var port = "22"
    
    var body: some View {
        NavigationView {
            Form {
                Section("SSH Connection") {
                    TextField("Hostname", text: $hostname)
                        .textContentType(.URL)
                    
                    TextField("Username", text: $username)
                        .textContentType(.username)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                    
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    Button("Connect") {
                        connectSSH()
                    }
                    .disabled(hostname.isEmpty || username.isEmpty)
                    
                    if terminalManager.isConnected {
                        Button("Disconnect") {
                            terminalManager.disconnect()
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("SSH Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func connectSSH() {
        Task {
            await terminalManager.connectSSH(
                host: hostname,
                username: username,
                password: password,
                port: Int(port) ?? 22
            )
            dismiss()
        }
    }
}

#Preview {
    TerminalView()
}
