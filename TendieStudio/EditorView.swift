import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Project model

struct WallpaperLayer: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var imageData: Data
    var x: Double = 0
    var y: Double = 0
    var scale: Double = 1
    var rotation: Double = 0
    var opacity: Double = 1
    var isHidden: Bool = false
    var isLocked: Bool = false
    var fillsFrame: Bool = false
}

struct ProjectDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Editor

struct EditorView: View {
    @State private var layers: [WallpaperLayer] = []
    @State private var selectedID: UUID?
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument: ProjectDocument?
    @State private var status = "Importiere ein Bild, um dein Design zu beginnen."
    @State private var undoStack: [[WallpaperLayer]] = []
    @State private var redoStack: [[WallpaperLayer]] = []

    // Gesture origins prevent cumulative drift while SwiftUI sends repeated updates.
    @State private var dragOrigins: [UUID: CGPoint] = [:]
    @State private var scaleOrigins: [UUID: Double] = [:]
    @State private var rotationOrigins: [UUID: Double] = [:]

    private var selectedIndex: Int? {
        layers.firstIndex(where: { $0.id == selectedID })
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    editorHeader
                    canvas
                    layerPanel
                    inspector
                    projectFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .background(Color(red: 0.035, green: 0.045, blue: 0.075).ignoresSafeArea())
            .navigationTitle("Tendie Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.035, green: 0.045, blue: 0.075), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button { undo() } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(undoStack.isEmpty)
                    .accessibilityLabel("Rückgängig")

                    Button { redo() } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(redoStack.isEmpty)
                    .accessibilityLabel("Wiederholen")
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showingImporter = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Bild hinzufügen")

                    Button { exportProject() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(layers.isEmpty)
                    .accessibilityLabel("Projekt sichern")
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.image],
                allowsMultipleSelection: true,
                onCompletion: importFiles
            )
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "Tendie-Studio-Projekt.json",
                onCompletion: { result in
                    switch result {
                    case .success:
                        status = "Projekt-Backup als JSON gespeichert."
                    case .failure(let error):
                        status = "Export fehlgeschlagen: \(error.localizedDescription)"
                    }
                }
            )
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var editorHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("STUDIO / CANVAS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.cyan)
                Text("Dein Wallpaper. Deine Bühne.")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("\(layers.count) LAYER")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.07), in: Capsule())
        }
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.12, green: 0.17, blue: 0.28), .black, Color(red: 0.06, green: 0.10, blue: 0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Subtle canvas guides.
                VStack(spacing: 0) {
                    Rectangle().fill(.white.opacity(0.045)).frame(height: 1)
                    Spacer()
                    Rectangle().fill(.white.opacity(0.045)).frame(height: 1)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)

                VStack(spacing: 3) {
                    Text(Date.now, format: .dateTime.hour().minute())
                        .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                        .tracking(-2)
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.94))
                .padding(.top, 46)
                .allowsHitTesting(false)

                ForEach(layers) { layer in
                    if !layer.isHidden, let image = UIImage(data: layer.imageData) {
                        canvasLayer(layer, image: image, canvasSize: geo.size)
                    }
                }

                if layers.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 34, weight: .light))
                        Text("Dein Canvas ist noch leer")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text("Tippe oben auf + und füge ein Bild hinzu.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }

                VStack {
                    Spacer()
                    HStack {
                        Label("LOCKSCREEN-VORSCHAU", systemImage: "lock.fill")
                        Spacer()
                        Text("9:19")
                    }
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
        }
        .aspectRatio(9.0 / 18.5, contentMode: .fit)
        .shadow(color: .black.opacity(0.3), radius: 22, y: 12)
    }

    private func canvasLayer(_ layer: WallpaperLayer, image: UIImage, canvasSize: CGSize) -> some View {
        let selected = layer.id == selectedID

        return Group {
            if layer.fillsFrame {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: canvasSize.width * 0.76, height: canvasSize.height * 0.43)
        .clipped()
        .scaleEffect(layer.scale)
        .rotationEffect(.degrees(layer.rotation))
        .opacity(layer.opacity)
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .overlay(alignment: .topLeading) {
                        handleDot
                            .offset(x: -5, y: -5)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        handleDot
                            .offset(x: 5, y: 5)
                    }
            }
        }
        .position(
            x: canvasSize.width / 2 + layer.x,
            y: canvasSize.height / 2 + layer.y
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedID = layer.id }
        .simultaneousGesture(dragGesture(for: layer))
        .simultaneousGesture(magnificationGesture(for: layer))
        .simultaneousGesture(rotationGesture(for: layer))
    }

    private var handleDot: some View {
        Circle()
            .fill(Color.cyan)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(.black.opacity(0.7), lineWidth: 1))
    }

    // MARK: Layer gestures

    private func dragGesture(for layer: WallpaperLayer) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !layer.isLocked else { return }
                if dragOrigins[layer.id] == nil {
                    checkpoint()
                    dragOrigins[layer.id] = CGPoint(x: layer.x, y: layer.y)
                    selectedID = layer.id
                }
                guard let origin = dragOrigins[layer.id] else { return }
                updateLayer(layer.id) {
                    $0.x = origin.x + value.translation.width
                    $0.y = origin.y + value.translation.height
                }
            }
            .onEnded { _ in dragOrigins[layer.id] = nil }
    }

    private func magnificationGesture(for layer: WallpaperLayer) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard !layer.isLocked else { return }
                if scaleOrigins[layer.id] == nil {
                    checkpoint()
                    scaleOrigins[layer.id] = layer.scale
                    selectedID = layer.id
                }
                guard let origin = scaleOrigins[layer.id] else { return }
                updateLayer(layer.id) { $0.scale = min(4, max(0.15, origin * value)) }
            }
            .onEnded { _ in scaleOrigins[layer.id] = nil }
    }

    private func rotationGesture(for layer: WallpaperLayer) -> some Gesture {
        RotationGesture()
            .onChanged { value in
                guard !layer.isLocked else { return }
                if rotationOrigins[layer.id] == nil {
                    checkpoint()
                    rotationOrigins[layer.id] = layer.rotation
                    selectedID = layer.id
                }
                guard let origin = rotationOrigins[layer.id] else { return }
                updateLayer(layer.id) { $0.rotation = origin + value.degrees }
            }
            .onEnded { _ in rotationOrigins[layer.id] = nil }
    }

    // MARK: Layers panel

    private var layerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("EBENEN", detail: "Reihenfolge & Sichtbarkeit")

            if layers.isEmpty {
                Text("Deine importierten Elemente erscheinen hier.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 7) {
                    ForEach(layers.reversed()) { layer in
                        layerRow(layer)
                    }
                }
            }
        }
        .studioPanel()
    }

    private func layerRow(_ layer: WallpaperLayer) -> some View {
        let selected = layer.id == selectedID

        return HStack(spacing: 10) {
            if let image = UIImage(data: layer.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            } else {
                RoundedRectangle(cornerRadius: 9)
                    .fill(.white.opacity(0.08))
                    .frame(width: 42, height: 42)
                    .overlay(Image(systemName: "photo").foregroundStyle(.white.opacity(0.5)))
            }

            Button {
                selectedID = layer.id
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(layer.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(layer.isHidden ? 0.4 : 0.95))
                    Text(layer.isLocked ? "GESPERRT" : (layer.isHidden ? "AUSGEBLENDET" : "BILD-LAYER"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                checkpoint()
                updateLayer(layer.id) { $0.isHidden.toggle() }
            } label: {
                Image(systemName: layer.isHidden ? "eye.slash" : "eye")
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layer.isHidden ? "Ebene einblenden" : "Ebene ausblenden")

            Button {
                checkpoint()
                updateLayer(layer.id) { $0.isLocked.toggle() }
            } label: {
                Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
                    .foregroundStyle(layer.isLocked ? .cyan : .white.opacity(0.65))
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layer.isLocked ? "Ebene entsperren" : "Ebene sperren")
        }
        .padding(8)
        .background(selected ? Color.cyan.opacity(0.13) : .white.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(selected ? Color.cyan.opacity(0.55) : .white.opacity(0.045), lineWidth: 1)
        }
        .contextMenu {
            Button("Duplizieren", systemImage: "plus.square.on.square") { duplicateLayer(layer) }
            Button("Nach oben", systemImage: "arrow.up") { moveLayer(layer.id, offset: 1) }
            Button("Nach unten", systemImage: "arrow.down") { moveLayer(layer.id, offset: -1) }
            Button("Löschen", systemImage: "trash", role: .destructive) { deleteLayer(layer.id) }
        }
    }

    // MARK: Inspector

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeading("TRANSFORM", detail: selectedLayer?.name ?? "Keine Ebene ausgewählt")

            if let index = selectedIndex {
                let layer = layers[index]
                HStack(spacing: 8) {
                    metricCard("X", value: String(format: "%.0f", layer.x))
                    metricCard("Y", value: String(format: "%.0f", layer.y))
                    metricCard("SCALE", value: String(format: "%.2f×", layer.scale))
                    metricCard("ROT", value: String(format: "%.0f°", layer.rotation))
                }

                editorSlider("Größe", value: layerBinding(index, \.scale), range: 0.15...4, valueText: String(format: "%.2f×", layer.scale))
                editorSlider("Drehung", value: layerBinding(index, \.rotation), range: -180...180, valueText: String(format: "%.0f°", layer.rotation))
                editorSlider("Deckkraft", value: layerBinding(index, \.opacity), range: 0...1, valueText: "\(Int(layer.opacity * 100))%")

                HStack(spacing: 8) {
                    actionButton("Einpassen", icon: "arrow.down.right.and.arrow.up.left") {
                        checkpoint()
                        updateLayer(layer.id) { $0.fillsFrame = false }
                    }
                    actionButton("Füllen", icon: "arrow.up.left.and.arrow.down.right") {
                        checkpoint()
                        updateLayer(layer.id) { $0.fillsFrame = true }
                    }
                }

                HStack(spacing: 8) {
                    actionButton("Ebene duplizieren", icon: "plus.square.on.square") {
                        duplicateLayer(layer)
                    }
                    actionButton("Löschen", icon: "trash", destructive: true) {
                        deleteLayer(layer.id)
                    }
                }

                HStack(spacing: 8) {
                    actionButton("Nach oben", icon: "arrow.up") { moveLayer(layer.id, offset: 1) }
                    actionButton("Nach unten", icon: "arrow.down") { moveLayer(layer.id, offset: -1) }
                }
            } else {
                Text("Wähle eine Ebene im Canvas oder in der Ebenenliste aus.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.48))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            }
        }
        .studioPanel()
    }

    private var selectedLayer: WallpaperLayer? {
        guard let index = selectedIndex else { return nil }
        return layers[index]
    }

    private func metricCard(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
    }

    private func editorSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, valueText: String) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(valueText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            Slider(value: value, in: range, onEditingChanged: { editing in
                if editing { checkpoint() }
            })
            .tint(.cyan)
        }
    }

    private func actionButton(_ title: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(destructive ? Color.red.opacity(0.12) : .white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(destructive ? Color.red.opacity(0.9) : .white.opacity(0.82))
        }
        .buttonStyle(.plain)
    }

    // MARK: Footer

    private var projectFooter: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 3) {
                Text(status)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                Text("Projekt-Backup ist JSON. Kein bestätigter PosterBoard-/.tendies-Export.")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.38))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.7)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Text(detail)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
        }
    }

    // MARK: Editing operations and history

    private func checkpoint() {
        undoStack.append(layers)
        if undoStack.count > 40 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(layers)
        layers = previous
        if let selectedID, !layers.contains(where: { $0.id == selectedID }) {
            self.selectedID = layers.last?.id
        }
        status = "Letzte Änderung rückgängig gemacht."
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(layers)
        layers = next
        status = "Änderung wiederhergestellt."
    }

    private func updateLayer(_ id: UUID, _ change: (inout WallpaperLayer) -> Void) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        change(&layers[index])
    }

    private func layerBinding(_ index: Int, _ keyPath: WritableKeyPath<WallpaperLayer, Double>) -> Binding<Double> {
        Binding(
            get: { guard layers.indices.contains(index) else { return 0 }; return layers[index][keyPath: keyPath] },
            set: { newValue in guard layers.indices.contains(index) else { return }; layers[index][keyPath: keyPath] = newValue }
        )
    }

    private func duplicateLayer(_ layer: WallpaperLayer) {
        checkpoint()
        var copy = layer
        copy.id = UUID()
        copy.name += " Kopie"
        copy.x += 18
        copy.y += 18
        copy.isLocked = false
        layers.append(copy)
        selectedID = copy.id
        status = "Ebene dupliziert."
    }

    private func deleteLayer(_ id: UUID) {
        checkpoint()
        layers.removeAll { $0.id == id }
        if selectedID == id { selectedID = layers.last?.id }
        status = "Ebene gelöscht."
    }

    private func moveLayer(_ id: UUID, offset: Int) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard layers.indices.contains(destination) else { return }
        checkpoint()
        layers.swapAt(index, destination)
        status = offset > 0 ? "Ebene nach vorne verschoben." : "Ebene nach hinten verschoben."
    }

    // MARK: Import and project backup

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            status = "Import fehlgeschlagen: \(error.localizedDescription)"
        case .success(let urls):
            var imported = 0
            for url in urls {
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url), UIImage(data: data) != nil else { continue }
                if imported == 0 { checkpoint() }
                let layer = WallpaperLayer(name: url.deletingPathExtension().lastPathComponent, imageData: data)
                layers.append(layer)
                selectedID = layer.id
                imported += 1
            }
            status = imported == 0 ? "Keine unterstützten Bilddateien importiert." : "\(imported) Bild(er) zum Canvas hinzugefügt."
        }
    }

    private func exportProject() {
        do {
            let data = try JSONEncoder.studio.encode(layers)
            exportDocument = ProjectDocument(data: data)
            showingExporter = true
            status = "JSON-Projektbackup wird vorbereitet."
        } catch {
            status = "Backup konnte nicht erstellt werden: \(error.localizedDescription)"
        }
    }
}

// MARK: - Styling helpers

private extension View {
    func studioPanel() -> some View {
        self
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.075), Color.white.opacity(0.035)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            }
    }
}

private extension JSONEncoder {
    static var studio: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
