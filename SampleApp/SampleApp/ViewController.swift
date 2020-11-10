//
//  ViewController.swift
//  SampleApp
//
//  Created by Rohan on 09/11/20.
//

import UIKit
import AVFoundation
import GameMain

class ViewController: UIViewController {
  
  @IBOutlet weak var containerView: UIView!
  
  lazy var korgeVC: KorgeViewController = {
    let vc = storyboard!.instantiateViewController(identifier: "korgeVC") as! KorgeViewController
    return vc
  }()
  
  let asset = AVAsset(url: Bundle.main.url(forResource: "football", withExtension: "mp4")!)
  lazy var playerItem = AVPlayerItem(asset: asset)
  lazy var player = AVPlayer(playerItem: playerItem)
  
  let pixelBufferAttributes: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferOpenGLESCompatibilityKey as String: true,
  ]
  
  lazy var playerItemOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttributes)
  
  let context = GLContext.shared
  var textureCache: CVOpenGLESTextureCache?
  
  var currentPixelBuffer: CVPixelBuffer?
  
  lazy var displayLink: CADisplayLink = {
    let link = CADisplayLink(target: self, selector: #selector(displayLinkTrigger(_:)))
    link.add(to: .main, forMode: .common)
    return link
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupKorgeVCChild()
    
    playerItem.add(playerItemOutput)
    
    let err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, context, nil, &textureCache)
    if err != noErr { fatalError("Error - \(err)") }
    
    displayLink.isPaused = true
  }
  
  func setupKorgeVCChild() {
    containerView.addSubview(korgeVC.view)
    
    korgeVC.view.translatesAutoresizingMaskIntoConstraints = false
    korgeVC.view.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
    korgeVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
    korgeVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
    korgeVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
    
    addChild(korgeVC)
    korgeVC.didMove(toParent: self)
  }

  @IBAction func buttonTapped(_ sender: UIButton) {
//    MainKt.mayank = getNativeImage
//    player.play()

    displayLink.isPaused = false
    player.play()
  }
  
  func getNativeImage() -> RSNativeImage? {
    guard let pixelBuffer = checkAndGetPixelBuffer(time: CACurrentMediaTime()) else { return nil }
    guard let texture = generateTextureAndGetInfo(from: pixelBuffer) else { return nil }
    
    let rsNativeImage = RSNativeImage(width: Int32(texture.width),
                                      height: Int32(texture.height),
                                      name2: texture.id,
                                      target2: KotlinInt(int: Int32(texture.target)))
    
    return rsNativeImage
  }
  
  var counter = 0
  @objc func displayLinkTrigger(_ sender: CADisplayLink) {
//    if counter % 2 == 0 {
      let nextOutputTime = sender.timestamp + sender.duration
      guard let pixelBuffer = checkAndGetPixelBuffer(time: nextOutputTime) else { return }
      guard let texture = generateTextureAndGetInfo(from: pixelBuffer) else { return }
      MainKt.updateTexture(name: texture.id,
                           width: Int32(texture.width),
                           height: Int32(texture.height),
                           target: KotlinInt(int: Int32(texture.target)))
//    }
    counter += 1
  }
  
  func getRGBATexture(for pixelBuffer: CVPixelBuffer) -> CVOpenGLESTexture? {
    var texture: CVOpenGLESTexture?
    
    guard let textureCache = textureCache else { return nil }
    
    CVOpenGLESTextureCacheFlush(textureCache, 0)
    
    let err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           textureCache,
                                                           pixelBuffer,
                                                           nil,
                                                           GLenum(GL_TEXTURE_2D),
                                                           GLint(GL_RGBA),
                                                           Int32(CVPixelBufferGetWidth(pixelBuffer)),
                                                           Int32(CVPixelBufferGetHeight(pixelBuffer)),
                                                           GLenum(GL_BGRA),
                                                           GLenum(GL_UNSIGNED_BYTE),
                                                           0,
                                                           &texture)
    
    if texture == nil || err != noErr {
      print("Error at creating RGBA texture - \(err.description)")
    }
    
    return texture
  }
  
  func checkAndGetPixelBuffer(time: CFTimeInterval) -> CVPixelBuffer? {
    let nextHostTime = time + 0.0166666666666667
    let nextOutputTime = playerItemOutput.itemTime(forHostTime: nextHostTime)
    let hasPixelBuffer = playerItemOutput.hasNewPixelBuffer(forItemTime: nextOutputTime)
    guard hasPixelBuffer,
          let pixelBuffer = playerItemOutput.copyPixelBuffer(forItemTime: nextOutputTime, itemTimeForDisplay: nil) else {
      return nil
    }
    
    return pixelBuffer
  }
  
  func generateTextureAndGetInfo(from pixelBuffer: CVPixelBuffer) -> (id: GLuint, target: GLenum, width: Int, height: Int)? {
    guard let texture = getRGBATexture(for: pixelBuffer) else {
      debugPrint("Failed to create texture")
      return nil
    }
    let idName = CVOpenGLESTextureGetName(texture)
    let target = CVOpenGLESTextureGetTarget(texture)
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    
    return (idName, target, width, height)
  }
  
}

