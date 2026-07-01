import Testing

@testable import DictationPipeline

@Suite("Audio level")
struct AudioLevelTests {
    @Test("Silence and empty input read as zero")
    func silenceIsZero() {
        #expect(DictationController.level(of: []) == 0)
        #expect(DictationController.level(of: [0, 0, 0, 0]) == 0)
    }

    @Test("A full-scale signal reads as one")
    func fullScaleIsOne() {
        #expect(DictationController.level(of: [1, -1, 1, -1]) == 1)
    }

    @Test("Louder speech reads higher than quieter speech")
    func louderIsHigher() {
        let quiet = DictationController.level(of: [0.01, -0.01, 0.01, -0.01])
        let loud = DictationController.level(of: [0.1, -0.1, 0.1, -0.1])
        #expect(loud > quiet)
    }

    @Test("The level always stays within 0...1")
    func staysNormalized() {
        for amplitude in [Float(0), 0.001, 0.05, 0.5, 1, 2] {
            let level = DictationController.level(of: [amplitude, -amplitude])
            #expect(level >= 0 && level <= 1)
        }
    }
}
