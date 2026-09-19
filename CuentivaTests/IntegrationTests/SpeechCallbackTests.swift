import Foundation
import Testing
@testable import Cuentiva

import AVFoundation
import Speech

@Suite struct SpeechCallbackTests {
    @Test @MainActor func recognitionCallbackCanArriveOffMainActor() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let handler = AppleLessonAudio.makeRecognitionHandler { text, finished, error in
                MainActor.assertIsolated()
                #expect(text == nil)
                #expect(!finished)
                #expect(error == "Recognition interrupted")
                continuation.resume()
            }
            Task.detached {
                handler(nil, NSError(domain: "SpeechCallbackTest", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Recognition interrupted"]))
            }
        }
    }

    @Test func audioTapAcceptsBackgroundBuffersAndIgnoresEmptyFrames() async throws {
        try await Task.detached {
            let request = SFSpeechAudioBufferRecognitionRequest()
            let callback = AppleLessonAudio.makeAudioTap(request: request)
            let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 128))
            let time = AVAudioTime(sampleTime: 0, atRate: 16_000)
            buffer.frameLength = 0
            callback(buffer, time)
            buffer.frameLength = 128
            let channels = try #require(buffer.floatChannelData)
            channels[0].initialize(repeating: 0, count: 128)
            callback(buffer, time)
            request.endAudio()
        }.value
    }
}
