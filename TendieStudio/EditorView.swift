import SwiftUI
import UniformTypeIdentifiers
import CoreMotion
import AVFoundation
import UIKit

struct WallpaperLayer: Identifiable, Codable {
    var id = UUID()
    var name: String
    var imageData: Data
    var x: Double = 0
    var y: Double = 0
    var scale: Double = 1
    var rotation: Double = 0
    var opacity: Double = 1
    var depth: Double = 0.5
    var gyroX: Double = 30
    var gyroY: Double = 30
    var keyframes: [Keyframe] = []
}

struct Keyframe: Identifiable, Codable {
    var id = UUID()
    var time: Double
    var x: Double
    var y: Double
    var scale: Double
    var rotation: Double
    var opacity: Double
}

struct ProjectDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .tendiesDraft] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

final class MotionModel: ObservableObject {
    private let manager = CMMotionManager()
    @Published var roll: Double = 0
    @Published var pitch: Double = 0
    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let m = motion else { return }
            self?.roll = m.attitude.roll
            self?.pitch = m.attitude.pitch
        }
    }
    func stop() { manager.stopDeviceMotionUpdates() }
    deinit { stop() }
}

struct EditorView: View {
    @State private var layers: [WallpaperLayer] = []
    @State private var selectedID: UUID?
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument: ProjectDocument?
    @State private var playhead: Double = 0
    @State private var gyroEnabled = false
    @State private var proMode = false
    @State private var status = "Bereit – importiere ein Bild oder GIF."
    @StateObject private var motion = MotionModel()

    private var selectedIndex: Int? { layers.firstIndex { $0.id == selectedID } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                header
                preview
                    .frame(maxHeight: .infinity)
                layerStrip
                inspector
                timeline
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Tendie Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingImporter = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportProject() } label: { Image(systemName: "square.and.arrow.up") }
                        .disabled(layers.isEmpty)
                }
            }
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.image],
                          allowsMultipleSelection: true,
                          onCompletion: importFiles)
            .fileExporter(isPresented: $showingExporter,
                          document: exportDocument,
                          contentType: .tendiesDraft,
                          defaultFilename: "Mein-Wallpaper.tendies",
                          onCompletion: { result in
                              switch result { case .success: status = "Projekt exportiert."; case .failure: status = "Export abgebrochen." }
                          })
            .onAppear { motion.start() }
            .onDisappear { motion.stop() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label("POSTERBOARD STUDIO", systemImage: "sparkles")
                .font(.caption.weight(.bold))
                .tracking(1.1)
            Spacer()
            Button(proMode ? "Pro-Modus" : "Einfach") { proMode.toggle() }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
        }
        .padding(.top, 6)
    }

    private var preview: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(colors: [Color(red: 0.08, green: 0.10, blue: 0.18), .black],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack {
                    Text(Date.now, format: .dateTime.hour().minute())
                        .font(.system(size: 54, weight: .light, design: .rounded))
                        .foregroundStyle(.white.opacity(0.94))
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
                .padding(.top, 52)
                ForEach(layers) { layer in
                    if let image = UIImage(data: layer.imageData) {
                        let active = layer.id == selectedID
                        let gyroX = gyroEnabled ? motion.roll * layer.gyroX * layer.depth : 0
                        let gyroY = gyroEnabled ? motion.pitch * layer.gyroY * layer.depth : 0
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: geo.size.width * 0.78, maxHeight: geo.size.height * 0.55)
                            .scaleEffect(layer.scale)
                            .rotationEffect(.degrees(layer.rotation))
                            .opacity(layer.opacity)
                            .offset(x: layer.x + gyroX, y: layer.y + gyroY)
                            .overlay {
                                if active {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.cyan, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                        .padding(geo.size.width * 0.11)
                                }
                            }
                            .contentShape(Rectangle())
                            .gesture(DragGesture().onChanged { value in
                                updateLayer(layer.id) {
                                    $0.x = layer.x + value.translation.width
                                    $0.y = layer.y + value.translation.height
                                }
                            })
                            .onTapGesture { selectedID = layer.id }
                    }
                }
                VStack {
                    Spacer()
                    HStack {
                        Label("Live-Vorschau", systemImage: "lock.fill")
                        Spacer()
                        if gyroEnabled { Label("GYRO", systemImage: "gyroscope").foregroundStyle(.cyan) }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(14)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))
        }
        .aspectRatio(0.57, contentMode: .fit)
    }

    private var layerStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EBENEN").font(.caption.weight(.bold)).tracking(1)
                Spacer()
                Text("\(layers.count) Elemente").font(.caption).foregroundStyle(.secondary)
            }
            if layers.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up").font(.title2)
                    Text("Tippe oben auf + und importiere ein Bild oder GIF.")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).frame(height: 76)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(layers) { layer in
                            Button { selectedID = layer.id } label: {
                                HStack(spacing: 7) {
                                    if let ui = UIImage(data: layer.imageData) {
                                        Image(uiImage: ui).resizable().scaledToFill()
                                            .frame(width: 32, height: 32).clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    Text(layer.name).lineLimit(1).font(.caption.weight(.medium))
                                }
                                .padding(7)
                                .background(selectedID == layer.id ? Color.cyan.opacity(0.2) : Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedID == layer.id ? Color.cyan : .clear))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Ebene löschen", role: .destructive) { layers.removeAll { $0.id == layer.id } }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var inspector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BEWEGUNG & EFFEKTE").font(.caption.weight(.bold)).tracking(1)
                Spacer()
                Toggle("Gyro", isOn: $gyroEnabled).labelsHidden().scaleEffect(0.8)
                Text("Gyro").font(.caption)
            }
            if let index = selectedIndex {
                Group {
                    sliderRow("Größe", value: binding(index, \.scale), range: 0.2...3, suffix: "×")
                    sliderRow("Drehung", value: binding(index, \.rotation), range: -180...180, suffix: "°")
                    sliderRow("Deckkraft", value: binding(index, \.opacity), range: 0...1, suffix: "%")
                    if proMode {
                        sliderRow("Tiefe", value: binding(index, \.depth), range: 0...1, suffix: "")
                        sliderRow("Gyro X", value: binding(index, \.gyroX), range: 0...100, suffix: "")
                        sliderRow("Gyro Y", value: binding(index, \.gyroY), range: 0...100, suffix: "")
                    }
                }
            } else {
                Text("Wähle eine Ebene aus, um ihre Eigenschaften anzupassen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(proMode ? "PRO-TIMELINE" : "ANIMATION")
                    .font(.caption.weight(.bold)).tracking(1)
                Spacer()
                Text(String(format: "%.1f s", playhead)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Button {
                    guard let index = selectedIndex else { return }
                    let l = layers[index]
                    layers[index].keyframes.append(Keyframe(time: playhead, x: l.x, y: l.y,
                                                             scale: l.scale, rotation: l.rotation, opacity: l.opacity))
                    status = "Keyframe bei \(String(format: "%.1f", playhead)) s gesetzt."
                } label: { Label("Keyframe", systemImage: "diamond.fill").font(.caption.weight(.semibold)) }
                    .disabled(selectedID == nil)
            }
            Slider(value: $playhead, in: 0...12, step: 0.1)
            HStack {
                Text("0:00")
                Spacer()
                Text("12:00")
            }.font(.caption2).foregroundStyle(.tertiary)
            Text(status).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.caption).frame(width: 70, alignment: .leading)
            Slider(value: value, in: range)
            Text(suffix == "%" ? "\(Int(value.wrappedValue * 100))%" : String(format: "%.1f%@", value.wrappedValue, suffix))
                .font(.caption.monospacedDigit()).frame(width: 48, alignment: .trailing)
        }
    }

    private func binding(_ index: Int, _ keyPath: WritableKeyPath<WallpaperLayer, Double>) -> Binding<Double> {
        Binding(get: { layers[index][keyPath: keyPath] },
                set: { layers[index][keyPath: keyPath] = $0 })
    }

    private func updateLayer(_ id: UUID, _ change: (inout WallpaperLayer) -> Void) {
        guard let i = layers.firstIndex(where: { $0.id == id }) else { return }
        change(&layers[i])
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): status = "Import fehlgeschlagen: \(error.localizedDescription)"
        case .success(let urls):
            for url in urls {
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else { continue }
                let name = url.deletingPathExtension().lastPathComponent
                layers.append(WallpaperLayer(name: name, imageData: data))
                selectedID = layers.last?.id
            }
            status = "\(urls.count) Datei(en) importiert."
        }
    }

    private func exportProject() {
        do {
            let data = try JSONEncoder.pretty.encode(layers)
            exportDocument = ProjectDocument(data: data)
            showingExporter = true
            status = "Export wird vorbereitet."
        } catch { status = "Exportfehler: \(error.localizedDescription)" }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}


private extension UTType {
    static var tendiesDraft: UTType { UTType(filenameExtension: "tendies") ?? .json }
}
