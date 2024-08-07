import SwiftUI

struct ContentView: View {
    @State private var alias: String = ""
    @State private var command: String = ""
    @State private var aliases: [Alias] = []
    @State private var tempAliases: [Alias] = []
    @State private var editingAlias: Alias? = nil
    @State private var showingDeleteConfirmation = false
    @State private var aliasToDelete: Alias? = nil
    @State private var showCollisionWarning = false
    @State private var sortOrder: SortOrder = .none
    @State private var searchText: String = ""
    @State private var isFormVisible: Bool = false
    @FocusState private var focusedField: Field? // Add focus state

    private let aliasesFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".bash_aliases").path

    enum SortOrder {
        case none, ascending, descending
    }

    enum Field {
        case alias
    }

    struct Alias: Identifiable, Equatable {
        let id = UUID()
        var alias: String
        var command: String
    }

    var body: some View {
        VStack {
            HStack {
                Button(action: toggleSortOrder) {
                    HStack {
                        Text("Sort by Alias")
                            .font(.headline)
                        Image(systemName: sortOrder == .none ? "arrow.up.arrow.down" : (sortOrder == .ascending ? "arrow.up" : "arrow.down"))
                            .font(.body)
                    }
                }
                Spacer()
                Button(action: {
                    self.isFormVisible = true
                    self.editingAlias = nil
                    self.alias = ""
                    self.command = ""
                    focusedField = .alias // Set focus to alias field
                }) {
                    Text("Add Alias")
                }
            }
            .padding([.leading, .trailing])

            Divider()

            if isFormVisible {
                HStack {
                    TextField("Alias", text: $alias)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($focusedField, equals: .alias) // Apply focus
                    TextField("Command", text: $command)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: {
                        if let editingAlias = editingAlias {
                            updateAlias(editingAlias)
                        } else {
                            addAlias()
                        }
                        checkUnsavedChanges() // Check unsaved changes after add/update
                        isFormVisible = false // Hide the form after adding/updating
                        focusedField = nil // Remove focus
                    }) {
                        Text(editingAlias == nil ? "Add Alias" : "Update Alias")
                    }
                    .padding(.trailing)

                    Button(action: {
                        self.isFormVisible = false
                        self.alias = ""
                        self.command = ""
                        self.editingAlias = nil
                        focusedField = nil // Remove focus
                        checkUnsavedChanges() // Optionally check unsaved changes if needed
                    }) {
                        Text("Cancel")
                    }
                }
                .padding()
            } else {
                TextField("Search Aliases", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
            }

            Divider()

            List {
                ForEach(filteredAliases) { alias in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(alias.alias)
                            Text(alias.command)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: {
                            self.editingAlias = alias
                            self.alias = alias.alias
                            self.command = alias.command
                            checkUnsavedChanges() // Check unsaved changes after edit
                            isFormVisible = true // Show the form when editing
                            focusedField = .alias // Set focus to alias field
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                        Button(action: {
                            self.aliasToDelete = alias
                            self.showingDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("Confirm Deletion"),
                    message: Text("Are you sure you want to delete the alias '\(aliasToDelete?.alias ?? "")'?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let aliasToDelete = aliasToDelete {
                            deleteAlias(aliasToDelete)
                            checkUnsavedChanges() // Check unsaved changes after delete
                        }
                    },
                    secondaryButton: .cancel()
                )
            }

            if hasUnsavedChanges {
                HStack {
                    // Save Button
                    Button(action: applyChanges) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                                .padding() // Space between icon and text
                            Text("Save Changes")
                                .font(.system(size: 16))
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .center) // Center text horizontally
                        }
                    }
                    .disabled(!hasUnsavedChanges) // Disable button if no unsaved changes
                    .padding()

                    // Cancel Button
                    Button(action: cancelChanges) {
                        HStack {
                            Image(systemName: "xmark")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                                .padding() // Space between icon and text
                            Text("Cancel Changes")
                                .font(.system(size: 16))
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .center) // Center text horizontally
                        }
                    }
                    .disabled(!hasUnsavedChanges) // Disable button if no unsaved changes
                    .padding()
                }
            }
        }
        .padding()
        .onAppear(perform: loadAliases)
    }

    private var filteredAliases: [Alias] {
        if searchText.isEmpty {
            return tempAliases
        } else {
            return tempAliases.filter {
                $0.alias.lowercased().contains(searchText.lowercased()) ||
                $0.command.lowercased().contains(searchText.lowercased())
            }
        }
    }

    private func toggleSortOrder() {
        switch sortOrder {
        case .none:
            sortOrder = .ascending
        case .ascending:
            sortOrder = .descending
        case .descending:
            sortOrder = .none
        }
        sortAliases()
        checkUnsavedChanges() // Check unsaved changes after sort
    }

    private func sortAliases() {
        switch sortOrder {
        case .none:
            tempAliases = aliases
        case .ascending:
            tempAliases = aliases.sorted { $0.alias < $1.alias }
        case .descending:
            tempAliases = aliases.sorted { $0.alias > $1.alias }
        }
    }

    private var hasUnsavedChanges: Bool {
        return tempAliases != aliases
    }

    private func checkUnsavedChanges() {
        DispatchQueue.main.async {
            // Ensure the UI is updated
        }
    }

    private func loadAliases() {
        print("Loading aliases from file: \(aliasesFile)")
        if FileManager.default.fileExists(atPath: aliasesFile) {
            do {
                let contents = try String(contentsOfFile: aliasesFile)
                print("File contents:\n\(contents)")
                aliases = contents.split(separator: "\n").map { parseAlias(String($0)) }.compactMap { $0 }
                tempAliases = aliases
                print("Parsed aliases: \(aliases)")
            } catch {
                print("Failed to load aliases: \(error)")
            }
        } else {
            print("Aliases file does not exist, creating new file.")
            FileManager.default.createFile(atPath: aliasesFile, contents: nil)
        }
    }

    private func parseAlias(_ line: String) -> Alias? {
        let components = line.split(separator: "=")
        guard components.count == 2,
              components[0].starts(with: "alias ") else { return nil }
        let alias = components[0].replacingOccurrences(of: "alias ", with: "").trimmingCharacters(in: .whitespaces)
        let command = components[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return Alias(alias: alias, command: command)
    }

    private func addAlias() {
        guard !alias.isEmpty, !command.isEmpty else {
            print("Alias or command is empty, skipping addition.")
            return
        }

        if tempAliases.contains(where: { $0.alias == alias }) {
            showCollisionWarning = true
            return
        }

        tempAliases.append(Alias(alias: alias, command: command))
        alias = ""
        command = ""
        checkUnsavedChanges() // Check unsaved changes after addition
    }

    private func updateAlias(_ oldAlias: Alias) {
        guard !alias.isEmpty, !command.isEmpty else {
            print("Alias or command is empty, skipping update.")
            return
        }

        if tempAliases.contains(where: { $0.alias == alias && $0.id != oldAlias.id }) {
            showCollisionWarning = true
            return
        }

        if let index = tempAliases.firstIndex(where: { $0.id == oldAlias.id }) {
            tempAliases[index] = Alias(alias: alias, command: command)
            alias = ""
            command = ""
            checkUnsavedChanges() // Check unsaved changes after update
        }
    }

    private func deleteAlias(_ alias: Alias) {
        if let index = tempAliases.firstIndex(where: { $0.id == alias.id }) {
            tempAliases.remove(at: index)
            aliasToDelete = nil
            checkUnsavedChanges() // Check unsaved changes after delete
        }
    }

    private func applyChanges() {
        aliases = tempAliases
        saveAliases()
        checkUnsavedChanges() // Check unsaved changes after apply
    }

    private func cancelChanges() {
        tempAliases = aliases
        alias = ""
        command = ""
        editingAlias = nil
        isFormVisible = false // Hide the form when canceling changes
        focusedField = nil // Remove focus
        checkUnsavedChanges() // Check unsaved changes after cancel
    }

    private func saveAliases() {
        print("Saving aliases to file: \(aliasesFile)")
        let content = aliases.map { "alias \($0.alias)='\($0.command)'" }.joined(separator: "\n")
        do {
            try content.write(toFile: aliasesFile, atomically: true, encoding: .utf8)
            print("Aliases saved successfully.")
        } catch {
            print("Failed to save aliases: \(error)")
        }
    }
}
