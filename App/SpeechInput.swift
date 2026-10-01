import AVFoundation
import Speech
import SwiftUI

@MainActor final class SpeechInput: ObservableObject {
    @Published var recording = false
    @Published var busy = false
    @Published var error: String?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var hasTap = false
    private var token = UUID()
    func start(onText: @escaping (String) -> Void) async {
        guard !busy && !recording else { return }
        busy = true
        let sessionToken = UUID(); token = sessionToken
        defer { busy = false }
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speechAllowed else { error = "設定で「気分ログ」の音声認識を許可してください。"; return }
        let micAllowed = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard micAllowed else { error = "設定で「気分ログ」のマイクを許可してください。"; return }
        guard token == sessionToken else { return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP")), recognizer.isAvailable else {
            error = "音声入力を利用できません。キーボードでも入力できます。"; return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Prefer on-device transcription; Apple's recognition service is the fallback.
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            self.request = request
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 && format.channelCount > 0 else { throw SpeechFailure.noInput }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            hasTap = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, failure in
                Task { @MainActor in
                    guard let self, self.token == sessionToken else { return }
                    if let result { onText(result.bestTranscription.formattedString) }
                    if failure != nil || result?.isFinal == true {
                        if failure != nil && result == nil { self.error = "音声入力が終了しました。入力済みの文字は残っています。" }
                        self.stop()
                    }
                }
            }
            engine.prepare(); try engine.start(); recording = true
        } catch { stop(); self.error = "マイクを開始できませんでした。もう一度お試しください。" }
    }
    // End audio first so the recognizer can deliver its final words.
    func finish() {
        guard recording else { return }
        let finishingToken = token
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio()
        recording = false; busy = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            if token == finishingToken { stop() }
        }
    }
    func stop() {
        token = UUID()
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio(); task?.cancel(); task = nil; request = nil
        recording = false; busy = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    enum SpeechFailure: Error { case noInput }
}
