import Foundation
import AVFoundation

enum AmbientSoundType: String, CaseIterable, Identifiable {
    case none = "Off"
    case rain = "Rain"
    case ocean = "Ocean"
    case forest = "Forest"
    case pinkNoise = "Pink Noise"
    case focus40Hz = "40Hz Focus"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .none: return "speaker.slash.fill"
        case .rain: return "cloud.rain.fill"
        case .ocean: return "water.waves"
        case .forest: return "leaf.fill"
        case .pinkNoise: return "waveform.path"
        case .focus40Hz: return "brain.head.profile"
        }
    }
}

@MainActor
final class AmbientSoundManager: ObservableObject {
    static let shared = AmbientSoundManager()
    
    @Published var activeSound: AmbientSoundType = .none
    @Published var volume: Float = 0.5 {
        didSet {
            engine.mainMixerNode.outputVolume = volume
            UserDefaults.standard.set(volume, forKey: "frogdrop.ambientVolume")
        }
    }
    
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var isEngineRunning = false
    
    // Synthesis state variables
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
    private var lfoPhase: Float = 0
    private var tonePhaseL: Float = 0
    private var tonePhaseR: Float = 0
    
    private init() {
        let savedVol = UserDefaults.standard.float(forKey: "frogdrop.ambientVolume")
        if savedVol > 0 {
            self.volume = savedVol
        } else {
            self.volume = 0.5
        }
    }
    
    func selectSound(_ sound: AmbientSoundType) {
        if activeSound == sound {
            stop()
        } else {
            play(sound: sound)
        }
    }
    
    func play(sound: AmbientSoundType) {
        stop()
        guard sound != .none else { return }
        
        activeSound = sound
        setupSourceNode(for: sound)
        
        do {
            if !engine.isRunning {
                try engine.start()
                isEngineRunning = true
            }
            engine.mainMixerNode.outputVolume = volume
        } catch {
            print("[AmbientSoundManager] Failed to start audio engine: \(error)")
        }
    }
    
    func stop() {
        if let node = sourceNode {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
            sourceNode = nil
        }
        if engine.isRunning {
            engine.pause()
            isEngineRunning = false
        }
        activeSound = .none
    }
    
    private func setupSourceNode(for sound: AmbientSoundType) {
        let format = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate > 0 ? format.sampleRate : 44100)
        
        // Reset synthesis filter state
        b0 = 0; b1 = 0; b2 = 0; b3 = 0; b4 = 0; b5 = 0; b6 = 0
        lfoPhase = 0; tonePhaseL = 0; tonePhaseR = 0
        
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for frame in 0..<Int(frameCount) {
                let (sampleL, sampleR) = self.generateSample(for: sound, sampleRate: sampleRate)
                
                for (bufferIndex, buffer) in ablPointer.enumerated() {
                    guard let channelData = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    if bufferIndex == 0 {
                        channelData[frame] = sampleL
                    } else {
                        channelData[frame] = sampleR
                    }
                }
            }
            return noErr
        }
        
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }
    
    private func generateSample(for sound: AmbientSoundType, sampleRate: Float) -> (Float, Float) {
        switch sound {
        case .pinkNoise:
            // Paul Kellet's refined Pink Noise generation algorithm
            let white = (Float.random(in: -1.0...1.0)) * 0.15
            b0 = 0.99886 * b0 + white * 0.0555179
            b1 = 0.99332 * b1 + white * 0.0750759
            b2 = 0.96900 * b2 + white * 0.1538520
            b3 = 0.86650 * b3 + white * 0.3104856
            b4 = 0.55000 * b4 + white * 0.5329522
            b5 = -0.7616 * b5 - white * 0.0168980
            let pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
            b6 = white * 0.115926
            let out = pink * 0.18
            return (out, out)
            
        case .rain:
            // Pink noise with modulated gentle rainfall droplets
            let white = (Float.random(in: -1.0...1.0)) * 0.15
            b0 = 0.995 * b0 + white * 0.05
            b1 = 0.98 * b1 + white * 0.1
            b2 = 0.95 * b2 + white * 0.2
            let rain = (b0 + b1 + b2) * 0.22
            // Random soft droplets
            let droplet = Float.random(in: 0...100) > 99.7 ? Float.random(in: -0.15...0.15) : 0.0
            let left = rain + droplet
            let right = rain - droplet
            return (left, right)
            
        case .ocean:
            // Deep brown noise modulated by rolling 0.12Hz surf LFO
            lfoPhase += 0.12 / sampleRate * 2.0 * .pi
            if lfoPhase > 2.0 * .pi { lfoPhase -= 2.0 * .pi }
            let lfo = (sin(lfoPhase) + 1.0) * 0.5 * 0.8 + 0.2
            
            let white = (Float.random(in: -1.0...1.0)) * 0.25
            b0 = (b0 + (0.02 * white)) / 1.02
            let surf = b0 * 1.8 * lfo
            return (surf, surf * 0.95)
            
        case .forest:
            // Soft breeze filter (brown noise + high freq rustling)
            let white = (Float.random(in: -1.0...1.0)) * 0.12
            b0 = (b0 + (0.04 * white)) / 1.04
            let breeze = b0 * 1.2
            let rustle = (Float.random(in: -1.0...1.0)) * 0.02
            return (breeze + rustle, breeze - rustle)
            
        case .focus40Hz:
            // Binaural Beat: 200 Hz (Left) vs 240 Hz (Right) = 40 Hz Gamma Focus Resonance
            let freqL: Float = 200.0
            let freqR: Float = 240.0
            
            tonePhaseL += freqL / sampleRate * 2.0 * .pi
            if tonePhaseL > 2.0 * .pi { tonePhaseL -= 2.0 * .pi }
            
            tonePhaseR += freqR / sampleRate * 2.0 * .pi
            if tonePhaseR > 2.0 * .pi { tonePhaseR -= 2.0 * .pi }
            
            // Soft sine wave with pink noise backing
            let sineL = sin(tonePhaseL) * 0.08
            let sineR = sin(tonePhaseR) * 0.08
            
            let white = (Float.random(in: -1.0...1.0)) * 0.03
            b0 = (b0 + (0.05 * white)) / 1.05
            
            return (sineL + b0 * 0.2, sineR + b0 * 0.2)
            
        case .none:
            return (0.0, 0.0)
        }
    }
}
