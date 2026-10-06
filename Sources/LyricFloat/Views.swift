import SwiftUI
import AppKit
import LyricCore

private let mint = Color(red: 0.67, green: 0.94, blue: 0.78)
private let canvasColor = Color(red: 0.075, green: 0.086, blue: 0.095)

struct PlayerView: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        VStack(spacing: 0) {
            if model.isCompact {
                compactLyrics
            } else {
                header.fixedSize(horizontal: false, vertical: true)
                Divider().overlay(.white.opacity(0.06))
                trackInfo.fixedSize(horizontal: false, vertical: true)
                lyrics.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                footer.fixedSize(horizontal: false, vertical: true)
            }
        }
        .background {
            if model.isCompact {
                GlassBackground()
                    .overlay(Color.black.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.16), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .ignoresSafeArea()
            } else {
                canvasColor.ignoresSafeArea()
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .tint(mint)
        .frame(minWidth: model.isCompact ? 320 : 380, minHeight: model.isCompact ? 180 : 380)
        .sheet(isPresented: $model.showSetup) { SetupView(model: model) }
        .sheet(isPresented: $model.showSearch) { SearchView(model: model) }
        .alert("Something needs attention", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
    private var compactLyrics: some View {
        VStack(spacing: 10) {
            if model.advertisement {
                Text("Lyrics resume after this ad").foregroundStyle(.white.opacity(0.45))
            } else if !model.lines.isEmpty {
                let index = model.currentIndex
                let previous = index.flatMap { $0 > 0 ? model.lines[$0 - 1].text : nil }
                let current = index.map { model.lines[$0].text }
                let nextIndex = index.map { $0 + 1 } ?? 0
                let next = model.lines.indices.contains(nextIndex) ? model.lines[nextIndex].text : nil
                Text(previous?.isEmpty == false ? previous! : " ")
                    .font(.system(size: max(13, model.fontSize - 9), weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.24)).lineLimit(1)
                Text(current.map { $0.isEmpty ? "♪" : $0 } ?? "♪")
                    .font(.system(size: min(32, model.fontSize), weight: .bold, design: .rounded))
                    .foregroundStyle(mint).lineLimit(3).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                Text(next?.isEmpty == false ? next! : " ")
                    .font(.system(size: max(13, model.fontSize - 9), weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.24)).lineLimit(1)
            } else {
                Text(model.searching ? "Finding lyrics…" : (model.plainLyrics != nil ? "Click to view untimed lyrics" : "Click to find lyrics"))
                    .font(.system(size: 18, weight: .medium, design: .rounded)).foregroundStyle(mint)
            }
        }.multilineTextAlignment(.center)
            .padding(.horizontal, 22).padding(.top, 26).padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .help("Drag to position · click to expand lyrics and controls")
    }
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform").foregroundStyle(mint)
            Text("lyricfloat").font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
            Menu {
                ForEach(Source.allCases) { source in Button { model.source = source } label: { Label(source.rawValue, systemImage: source.symbol) } }
            } label: {
                HStack(spacing: 6) { Image(systemName: model.source.symbol); Text(model.source.rawValue); Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }
                .font(.system(size: 11, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 6).background(.white.opacity(0.06), in: Capsule())
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            Button { model.pinned.toggle() } label: { Image(systemName: model.pinned ? "pin.fill" : "pin").foregroundStyle(model.pinned ? mint : .gray) }.help("Keep above other windows").accessibilityLabel("Keep above other windows")
            Menu {
                Button("Connect browser…") { model.showSetup = true }
                Button("Find lyrics…") { model.showSearch = true }
                Button("Import LRC lyrics…") { model.importLyrics() }
                Button("Open local audio…") { model.openAudio() }
                Divider()
                Button("Larger lyrics") { model.fontSize = min(42, model.fontSize + 2) }
                Button("Smaller lyrics") { model.fontSize = max(18, model.fontSize - 2) }
                Divider()
                Button("Try silent demo") { model.source = .demo }
                Button("Quit LyricFloat") { NSApp.terminate(nil) }
            } label: { Image(systemName: "ellipsis").frame(width: 20, height: 24) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Options")
        }
        .buttonStyle(.plain).padding(.horizontal, 22).padding(.vertical, 14)
    }
    private var trackInfo: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(mint.opacity(0.10))
                Image(systemName: model.source.symbol).font(.system(size: 20)).foregroundStyle(mint)
            }.frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 5) {
                Text(model.title).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                Text(model.artist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                HStack(spacing: 5) {
                    Circle().fill(model.connected ? mint : .orange).frame(width: 4, height: 4)
                    Text(model.status).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)
    }
    @ViewBuilder private var lyrics: some View {
        if model.advertisement {
            emptyState(symbol: "pause.circle", title: "A quick intermission", detail: "Lyrics will resume after the advertisement.")
        } else if !model.lines.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(model.lines.enumerated()), id: \.element.id) { index, line in
                            let active = index == model.currentIndex
                            Button { model.seek(line.time + model.offset) } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 14) {
                                    Text(PlayerModel.time(line.time)).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(active ? mint.opacity(0.7) : .white.opacity(0.2)).frame(width: 34, alignment: .leading)
                                    Text(line.text.isEmpty ? "♪" : line.text)
                                        .font(.system(size: model.fontSize, weight: active ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(active ? mint : .white.opacity(0.28))
                                        .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                                }.padding(.vertical, 4).contentShape(Rectangle())
                            }.buttonStyle(.plain).id(index).help("Jump to this line")
                        }
                    }.padding(.horizontal, 25).padding(.vertical, 65)
                }
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.10), .init(color: .black, location: 0.90), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                .onChange(of: model.currentIndex) { index in
                    // Resolve the current collection at layout time; never animate toward an old track's row.
                    if let index, model.lines.indices.contains(index) { proxy.scrollTo(index, anchor: .center) }
                    else if !model.lines.isEmpty { proxy.scrollTo(0, anchor: .top) }
                }
                .onAppear {
                    if let index = model.currentIndex, model.lines.indices.contains(index) { proxy.scrollTo(index, anchor: .center) }
                    else if !model.lines.isEmpty { proxy.scrollTo(0, anchor: .top) }
                }
            }.id(model.lyricRevision)
        } else if let plain = model.plainLyrics {
            ScrollView { VStack(alignment: .leading, spacing: 12) { Text("Lyrics without timestamps").font(.caption).foregroundStyle(mint); Text(plain).font(.system(size: model.fontSize, design: .rounded)).foregroundStyle(.white.opacity(0.7)) }.padding(25) }
        } else {
            VStack(spacing: 18) {
                emptyState(symbol: "text.quote", title: model.searching ? "Finding the words…" : "A little room to sing", detail: model.connected ? "Find matching lyrics, or bring your own LRC file." : "Your lyrics, in time with your music.\nFloating wherever you work.")
                if model.source == .youtube && !model.connected {
                    Button("Connect YouTube") { model.showSetup = true }.buttonStyle(PrimaryButtonStyle())
                } else if model.source == .local && !model.connected {
                    Button("Open audio") { model.openAudio() }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Button(model.searching ? "View lyric search" : "Find lyrics") { model.showSearch = true }.buttonStyle(PrimaryButtonStyle())
                }
                Button("Import LRC file") { model.importLyrics() }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
            }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.bottom, 20)
        }
    }
    private func emptyState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 32, weight: .light)).foregroundStyle(mint.opacity(0.65)).padding(.bottom, 4)
            Text(title).font(.system(size: 21, weight: .semibold, design: .rounded))
            Text(detail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center).lineSpacing(4)
        }.padding(.horizontal, 25)
    }
    private var footer: some View {
        VStack(spacing: 13) {
            HStack(spacing: 12) {
                Text(PlayerModel.time(model.position)).foregroundStyle(mint)
                Slider(value: Binding(get: { model.position }, set: { model.seek($0) }), in: 0...max(1, model.duration)).disabled(!model.connected || model.advertisement)
                Text(PlayerModel.time(model.duration)).foregroundStyle(.white.opacity(0.35))
            }.font(.system(size: 10, weight: .medium, design: .monospaced))
            HStack {
                HStack(spacing: 9) {
                    Button { model.offset = max(-120, model.offset - 0.5) } label: { Image(systemName: "minus") }.help("Show lyrics 0.5 seconds earlier")
                    Text(String(format: "%+.1fs", model.offset)).font(.system(size: 10, design: .monospaced)).frame(width: 45)
                    Button { model.offset = min(120, model.offset + 0.5) } label: { Image(systemName: "plus") }.help("Show lyrics 0.5 seconds later")
                }.foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button { model.seek(model.position - 5) } label: { Image(systemName: "gobackward.5") }.help("Back five seconds")
                Button { model.togglePlayback() } label: { Image(systemName: model.playing ? "pause.fill" : "play.fill").font(.system(size: 14)).frame(width: 36, height: 36).background(mint, in: Circle()).foregroundStyle(canvasColor) }.help("Play or pause").keyboardShortcut(.space, modifiers: [])
                Button { model.seek(model.position + 5) } label: { Image(systemName: "goforward.5") }.help("Forward five seconds")
                Spacer()
                Button { model.showSearch = true } label: { Image(systemName: "magnifyingglass") }.help("Find another lyric version")
            }.buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
            Text(model.lyricCredit.isEmpty ? "SING ALONG, STAY IN FLOW" : model.lyricCredit).font(.system(size: 9, weight: .medium)).tracking(model.lyricCredit.isEmpty ? 2 : 0).foregroundStyle(.white.opacity(0.25)).lineLimit(1)
        }.padding(.horizontal, 24).padding(.top, 15).padding(.bottom, 18).background(.white.opacity(0.025))
    }
}

struct SetupView: View {
    @ObservedObject var model: PlayerModel
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Connect your browser").font(.title2.bold()); Spacer(); Button("Done") { dismiss() } }
            Text("YouTube & YouTube Music").foregroundStyle(mint).font(.headline)
            Text("Use the included extension in Chrome, Edge, Brave, or another Chromium browser.").foregroundStyle(.secondary)
            Text("1. Open your browser’s Extensions page and turn on Developer mode.\n\n2. Choose Load unpacked and select the BrowserExtension folder included with LyricFloat.\n\n3. Open the extension, paste the pairing code below, and save. Reload your YouTube tab, then play a video.").font(.system(size: 13)).lineSpacing(3)
            HStack { Text(model.token).font(.system(size: 11, design: .monospaced)).textSelection(.enabled); Spacer(); Button("Copy code") { model.copyToken() } }.padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            Button("Show browser extension folder") { model.revealExtension() }
            Label(model.bridgeStatus, systemImage: "network").font(.caption).foregroundStyle(.secondary)
            Text("The browser sends playback timing only to this Mac. Lyrics search sends the song title to LRCLIB. Safari support is not included in this version.").font(.caption).foregroundStyle(.secondary)
        }.padding(26).frame(width: 510).background(canvasColor).preferredColorScheme(.dark).tint(mint)
    }
}

struct SearchView: View {
    @ObservedObject var model: PlayerModel
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Find the words").font(.title2.bold()); Spacer(); Button("Done") { dismiss() } }
            HStack { TextField("Song title and artist", text: $model.query).textFieldStyle(.roundedBorder).onSubmit { model.search() }; Button("Search") { model.search() }.buttonStyle(.borderedProminent).disabled(model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            HStack { if model.searching { ProgressView().controlSize(.small) }; Text(model.searchMessage).font(.caption).foregroundStyle(.secondary) }
            if model.duration > 0 {
                Text("Playback duration: \(PlayerModel.time(model.duration)) · closest timed versions first")
                    .font(.caption).foregroundStyle(mint)
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.results) { record in
                        Button { model.use(record) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(record.trackName).font(.headline)
                                    Text(record.artistName + (record.albumName.map { " · " + $0 } ?? "")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 5) {
                                    Text(record.syncedLyrics != nil ? "TIMED" : (record.instrumental == true ? "INSTRUMENTAL" : "PLAIN")).font(.system(size: 9, weight: .bold)).foregroundStyle(record.syncedLyrics != nil ? mint : Color.gray)
                                    Text(record.duration.map { PlayerModel.time($0) } ?? "Duration unknown").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    if let length = record.duration, length.isFinite, length > 0, model.duration > 0 {
                                        let difference = length - model.duration
                                        Text(abs(difference) < 0.5 ? "Same duration" : String(format: "%+.0fs", difference))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(abs(difference) <= LyricMatcher.maximumDurationDifference ? mint : Color.orange)
                                    }
                                }
                            }.padding(14).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10)).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
            }
            HStack { Text("Lyrics from LRCLIB").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Import LRC instead") { model.importLyrics(); dismiss() } }
        }.padding(24).frame(width: 530, height: 480).background(canvasColor).preferredColorScheme(.dark).tint(mint)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .foregroundStyle(canvasColor).padding(.horizontal, 18).padding(.vertical, 10)
            .background(mint.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Translucent, blurred desktop backdrop, without reducing lyric opacity.
struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .vibrantDark)
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
