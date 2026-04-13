import Foundation
import AVFoundation
import AppKit

/// 音效播放器
/// 用于播放提示音，如录音开始/结束的音效
class SoundPlayer {
    static let shared = SoundPlayer()
    
    private var startSound: AVAudioPlayer?
    private var stopSound: AVAudioPlayer?
    
    private init() {
        loadSounds()
    }
    
    /// 加载音效文件
    private func loadSounds() {
        // 加载开始录音音效
        loadSound(named: "rec_start") { [weak self] player in
            self?.startSound = player
        }
        
        // 加载结束录音音效
        loadSound(named: "rec_stop") { [weak self] player in
            self?.stopSound = player
        }
    }
    
    /// 从 Assets.xcassets 加载音效
    private func loadSound(named name: String, completion: @escaping (AVAudioPlayer?) -> Void) {
        // 尝试从 Assets.xcassets 加载
        if let url = getSoundURL(for: name) {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                print("[SoundPlayer] 音效加载成功: \(name)")
                completion(player)
                return
            } catch {
                print("[SoundPlayer] 音效加载失败 (\(name)): \(error.localizedDescription)")
            }
        } else {
            print("[SoundPlayer] 未找到音效文件: \(name)")
        }
        completion(nil)
    }
    
    /// 获取音效文件的 URL
    private func getSoundURL(for name: String) -> URL? {
        // 方法1: 直接从 bundle 资源路径访问
        if let bundlePath = Bundle.main.path(forResource: name, ofType: "wav", inDirectory: "sounds") {
            return URL(fileURLWithPath: bundlePath)
        }
        
        // 方法2: 从 Assets.xcassets 中的 .dataset 文件夹访问
        let assetPath = Bundle.main.path(forResource: name, ofType: "wav", inDirectory: "Assets.xcassets/sounds/\(name).dataset") 
        if let assetPath = assetPath {
            return URL(fileURLWithPath: assetPath)
        }
        
        // 方法3: 使用 NSDataAsset (macOS 10.15+)
        if #available(macOS 10.15, *) {
            if let dataAsset = NSDataAsset(name: "sounds/\(name)") {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).wav")
                do {
                    try dataAsset.data.write(to: tempURL)
                    return tempURL
                } catch {
                    print("[SoundPlayer] NSDataAsset 写入失败: \(error.localizedDescription)")
                }
            }
        }
        
        // 方法4: 尝试直接在 bundle 根目录查找
        if let directPath = Bundle.main.path(forResource: name, ofType: "wav") {
            return URL(fileURLWithPath: directPath)
        }
        
        return nil
    }
    
    /// 播放开始录音音效
    func playStartSound() {
        guard SettingsStore.shared.isSoundEnabled else {
            print("[SoundPlayer] 音效反馈已关闭，不播放开始音效")
            return
        }
        
        if let sound = startSound {
            sound.currentTime = 0
            sound.play()
            print("[SoundPlayer] 播放开始音效")
        } else {
            print("[SoundPlayer] 开始音效未加载")
        }
    }
    
    /// 播放结束录音音效
    func playStopSound() {
        guard SettingsStore.shared.isSoundEnabled else {
            print("[SoundPlayer] 音效反馈已关闭，不播放结束音效")
            return
        }
        
        if let sound = stopSound {
            sound.currentTime = 0
            sound.play()
            print("[SoundPlayer] 播放结束音效")
        } else {
            print("[SoundPlayer] 结束音效未加载")
        }
    }
    
    /// 重新加载音效（当设置改变时调用）
    func reloadSounds() {
        startSound = nil
        stopSound = nil
        loadSounds()
    }
}
