//
//  ViewController.swift
//  AR_emergency
//
//  Created by 鎌田啓路 on 2018/12/04.
//  Copyright © 2018年 鎌田啓路. All rights reserved.
//

import UIKit
import CoreML
import SceneKit
import ARKit
import CoreImage

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet weak var windowView: UIView!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var sampleImageView: UIImageView!
    @IBOutlet weak var sampleLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    
    @IBAction func tapButton(_ sender: Any) {
        let uiImage = sceneView.snapshot()
        let cropedUIImage = uiImage.cropImage(w: Int(self.windowView.bounds.width*2), h: Int(self.windowView.bounds.height*2))
        self.coreMLRequest(image: cropedUIImage)
        
        self.button.isHidden = true
        self.windowView.isHidden = true
    }
    
    private let device = MTLCreateSystemDefaultDevice()!
    private var fadingNode: SCNNode?
    
    //モデル読み込み
    let skechModel = SketchResModel()
    let classDic: [Int : String] = [0: "butterfly", 1: "chair", 2: "dog", 3: "dragon", 4: "elephant", 5: "horse", 6: "pizza", 7: "race_car", 8: "ship", 9: "toilet"]
    public var classLabel: Int = -1 //表示するオブジェクトの番号
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.showsStatistics = true
    }
    
    override func viewDidLayoutSubviews() {
        windowView.layer.borderColor = UIColor.red.cgColor
        windowView.layer.borderWidth = 10
        sampleLabel.numberOfLines = 0
        button.backgroundColor = UIColor.gray
        button.layer.cornerRadius = 20.0
        button.layer.masksToBounds = true
        button.tintColor = UIColor.black
        button.titleLabel?.text = "RECOGNITION"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        //let configuration = ARImageTrackingConfiguration()
        
        guard let trackedImages = ARReferenceImage.referenceImages(inGroupNamed: "Photos", bundle: Bundle.main) else {
            print("No available images")
            return
        }
        configuration.detectionImages = trackedImages
        //configuration.trackingImages = trackedImages
        configuration.maximumNumberOfTrackedImages = 1
        
        configuration.planeDetection = [.horizontal]

        
        
        sceneView.session.run(configuration)
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 1秒ごとに更新
        //Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.timerUpdate), userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        print("renderer")
        DispatchQueue.main.async {
            if let imageAnchor = anchor as? ARImageAnchor {
                print("AA")
                print(self.classLabel)
                if self.classLabel != -2 {
                    print("yeah!!!!")
                    let plane = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height)
                    plane.firstMaterial?.diffuse.contents = UIColor(white: 1.0, alpha: 0)
                    
                    let planeNode = SCNNode(geometry: plane)
                    planeNode.eulerAngles.x = -.pi/2.0
                    //planeNode.name = "planeNode"
                    
                    let shipScene = SCNScene(named: "art.scnassets/ship.scn")!
                    let shipNode = shipScene.rootNode.childNodes.first!
                    shipNode.name = "targetObject"
                    
                    planeNode.addChildNode(shipNode)
                    node.addChildNode(planeNode)
                }
            }
            
            if let planeAnchor = anchor as? ARPlaneAnchor {
                let planeGeometry = ARSCNPlaneGeometry(device: self.device)!
                planeGeometry.update(from: planeAnchor.geometry)
                
                let color = UIColor.green
                planeAnchor.addPlaneNode(on: node, geometry: planeGeometry, contents: color.withAlphaComponent(0.3))
                /*
                if #available(iOS 11.3, *) {
                    let planeGeometry = ARSCNPlaneGeometry(device: self.device)!
                    planeGeometry.update(from: planeAnchor.geometry)
                    planeGeometry.firstMaterial?.diffuse.contents =  UIImage(named: "camera_surface_2.png")
                    planeGeometry.firstMaterial?.diffuse.contentsTransform = SCNMatrix4MakeScale(2, 2, 0)
                    planeGeometry.firstMaterial?.diffuse.wrapS = .repeat
                    planeGeometry.firstMaterial?.diffuse.wrapT = .repeat
                    let planeNode = SCNNode(geometry: planeGeometry)
                    planeNode.castsShadow = false
                    planeNode.position.y = planeNode.position.y + 0.001 // ちょっと浮かす
                    planeNode.opacity = 0.0
                    planeNode.renderingOrder = -2
                    node.addChildNode(planeNode)
                }
                let extent = planeAnchor.extent
                let plane = SCNPlane(width: CGFloat(extent.x), height: CGFloat(extent.z))
                
                let planeNode = SCNNode(geometry: plane)
                planeNode.eulerAngles.x = -.pi/2
                planeNode.renderingOrder = -1
                
                switch planeAnchor.alignment {
                case .horizontal:
                    planeNode.name = "horizontalPlane"
                case .vertical:
                    planeNode.name = "veriticalPlane"
                }
                node.addChildNode(planeNode)
 */
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let planeAnchor = anchor as? ARPlaneAnchor{
            if let planeGeometry = planeAnchor.findShapedPlaneNode(on: node)?.geometry as? ARSCNPlaneGeometry {
                planeGeometry.update(from: planeAnchor.geometry)
            }
            
            /*
            let extent = planeAnchor.extent
            
            // アニメーション用のPlaneNode
            if #available(iOS 11.3, *), let planeNode = findShapedPlaneNode(on: node),
                let geometry = planeNode.geometry as? ARSCNPlaneGeometry {
                geometry.update(from: planeAnchor.geometry)
                fadeNode(node: planeNode)
            }
            
            if let planeNode = node.childNode(withName: "horizontalPlane", recursively: false) {
                let plane = SCNPlane(width: CGFloat(extent.x),
                                     height: CGFloat(extent.z))
                plane.firstMaterial?.colorBufferWriteMask = []
                planeNode.geometry = plane
                planeNode.castsShadow = false
                
                let center = planeAnchor.center
                planeNode.position = SCNVector3Make(center.x, 0, center.z)
            }
            
            if let vrticalPlaneNode = node.childNode(withName: "veriticalPlane", recursively: false) {
                let plane = SCNPlane(width: CGFloat(extent.x),
                                     height: CGFloat(extent.z))
                plane.firstMaterial?.colorBufferWriteMask = []
                vrticalPlaneNode.geometry = plane
                vrticalPlaneNode.castsShadow = false
                
                let center = planeAnchor.center
                vrticalPlaneNode.position = SCNVector3Make(center.x, center.y, center.z)
            }
            */
        }
    }
    @available(iOS 11.3, *)
    private func findShapedPlaneNode(on node: SCNNode) -> SCNNode? {
        for childNode in node.childNodes {
            if childNode.geometry as? ARSCNPlaneGeometry != nil {
                return childNode
            }
        }
        return nil
    }
    
    private func fadeNode(node: SCNNode){
        if node == fadingNode {
            return
        }
        let fadeIn = SCNAction.fadeOpacity(to: 0.3, duration: 1)
        let fadeOut = SCNAction.fadeOut(duration: 4)
        let group = SCNAction.sequence([fadeIn, fadeOut])
        node.runAction(group, completionHandler: {
            node.removeFromParentNode()
            self.fadingNode = nil
        })
        fadingNode = node
    }
    
    /*
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        // DispatchQueue 内で処理をかく
        DispatchQueue.main.async {
            
            // ARPlaneAnchor からアンカーを取得したり平面のノードを調べる
            if let planeAnchor = anchor as? ARPlaneAnchor {
                // Metal のデフォルトデバイスを設定する
                let device: MTLDevice = MTLCreateSystemDefaultDevice()!
                // ARSCNPlaneGeometry でジオメトリを初期化
                let plane = ARSCNPlaneGeometry.init(device: device)
                // アンカーから認識した領域のジオメトリ情報を取得し ARSCNPlaneGeometry の update に処理を渡す
                plane?.update(from: planeAnchor.geometry)
                
                // 60% 半透明の赤でマテリアルを着色
                plane?.firstMaterial?.diffuse.contents = UIColor.init(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.6)
                
                // 設置しているノードへ処理したジオメトリを渡し描画する
                node.geometry = plane
            }
            
        }
    }*/
    /*
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
        
        print("renderer")
        
        if let imageAnchor = anchor as? ARImageAnchor{
            if classLabel != -1 {
                print("yeah!!!!")
                let plane = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height)
                plane.firstMaterial?.diffuse.contents = UIColor(white: 1.0, alpha: 0.5)
                
                let planeNode = SCNNode(geometry: plane)
                planeNode.eulerAngles.x = -.pi/2.0
                
                let shipScene = SCNScene(named: "art.scnassets/ship.scn")!
                let shipNode = shipScene.rootNode.childNodes.first!
                
                
                planeNode.addChildNode(shipNode)
                node.addChildNode(planeNode)
                //sceneView.scene.rootNode.addChildNode(node)
            }
        }
        return node
    }
 */
    
    @objc func timerUpdate() {
        //赤い枠の中の画像をcropしてそれをcoreMLRequestに渡す
        let uiImage = sceneView.snapshot()
        let cropedUIImage = uiImage.cropImage(w: Int(self.windowView.bounds.width*2), h: Int(self.windowView.bounds.height*2))
        self.coreMLRequest(image: cropedUIImage)
    }

    
    func coreMLRequest(image: UIImage){
        //self.sampleImageView.image = image //デモ用
        let imgSize: Int = 225
        let imageShape: CGSize = CGSize(width: imgSize, height: imgSize)
        //(255, 255)にリサイズ
        let imagePixel = image.resize(to: imageShape).getPixelBuffer()
        //(1, 255, 255)のMLMultiArrayを生成
        let mlarray = try! MLMultiArray(shape: [1, NSNumber(value: imgSize), NSNumber(value: imgSize)], dataType: MLMultiArrayDataType.float32 )
        for i in 0..<imgSize*imgSize {
            mlarray[i] = imagePixel[i] as NSNumber
        }
        
        //sketchModelのpredictionにmlarrayを入れてそ予測
        if let prediction = try? self.skechModel.prediction(_0: mlarray) {
            //outputは_126という変数に格納されていることがSketchResModel.mlmodelに自動生成されたコードからわかる
            if let first = (prediction._126.sorted{ $0.value > $1.value }).first {
                self.sampleLabel.text = "\(String(describing: classDic[Int(first.key)]!)) \n \(round(first.value*100)/100.0)"
                self.classLabel = Int(first.key)
                
            }
        }
    }
}

extension UIImage {
    func resize(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: newSize.width, height: newSize.height), true, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    // 二値化してpixelBUfferに変換
    func getPixelBuffer() -> [Float]
    {
        guard let cgImage = self.cgImage else {
            return []
        }
        let bytesPerRow = cgImage.bytesPerRow
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let pixelData = cgImage.dataProvider!.data! as Data
        var buf : [Float] = []
        let thresh: Float = 0.5 //閾値
        
        for j in 0..<height {
            for i in 0..<width {
                let pixelInfo = bytesPerRow * j + i * bytesPerPixel
                let r = CGFloat(pixelData[pixelInfo])
                let g = CGFloat(pixelData[pixelInfo+1])
                let b = CGFloat(pixelData[pixelInfo+2])
                
                var v: Float = 0
                if floor(Float(r + g + b)/3.0)/255.0 < thresh {
                    v = 0
                } else {
                    v = 1
                }
                buf.append(v)
            }
        }
        return buf
    }
    
    // 画像中心からcrop
    func cropImage(w: Int, h: Int) -> UIImage {
        let origRef    = self.cgImage
        let origWidth  = Int(origRef!.width)
        let origHeight = Int(origRef!.height)
        let cropRect  = CGRect.init(x: CGFloat((origWidth - w) / 2), y: CGFloat((origHeight - h) / 2), width: CGFloat(w), height: CGFloat(h))
        let cropRef   = self.cgImage!.cropping(to: cropRect)
        let cropImage = UIImage(cgImage: cropRef!)
        
        return cropImage
    }
}


extension ARPlaneAnchor {
    
    @discardableResult
    func addPlaneNode(on node: SCNNode, geometry: SCNGeometry, contents: Any) -> SCNNode {
        guard let material = geometry.materials.first else { fatalError() }
        
        if let program = contents as? SCNProgram {
            material.program = program
        } else {
            material.diffuse.contents = contents
        }
        
        let planeNode = SCNNode(geometry: geometry)
        planeNode.name = "Plane"
        
        DispatchQueue.main.async(execute: {
            node.addChildNode(planeNode)
        })
        
        return planeNode
    }
    
    func addPlaneNode(on node: SCNNode, contents: Any) {
        let geometry = SCNPlane(width: CGFloat(extent.x), height: CGFloat(extent.z))
        let planeNode = addPlaneNode(on: node, geometry: geometry, contents: contents)
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
    }
    
    func findPlaneNode(on node: SCNNode) -> SCNNode? {
        for childNode in node.childNodes {
            if childNode.geometry as? SCNPlane != nil {
                return childNode
            }
        }
        return nil
    }
    
    func findShapedPlaneNode(on node: SCNNode) -> SCNNode? {
        for childNode in node.childNodes {
            if childNode.geometry as? ARSCNPlaneGeometry != nil {
                return childNode
            }
        }
        return nil
    }
    
    @available(iOS 11.3, *)
    func findPlaneGeometryNode(on node: SCNNode) -> SCNNode? {
        for childNode in node.childNodes {
            if childNode.geometry as? ARSCNPlaneGeometry != nil {
                return childNode
            }
        }
        return nil
    }
    
    @available(iOS 11.3, *)
    func updatePlaneGeometryNode(on node: SCNNode) {
        DispatchQueue.main.async(execute: {
            guard let planeGeometry = self.findPlaneGeometryNode(on: node)?.geometry as? ARSCNPlaneGeometry else { return }
            planeGeometry.update(from: self.geometry)
        })
    }
    
    func updatePlaneNode(on node: SCNNode) {
        DispatchQueue.main.async(execute: {
            guard let plane = self.findPlaneNode(on: node)?.geometry as? SCNPlane else { return }
            guard !PlaneSizeEqualToExtent(plane: plane, extent: self.extent) else { return }
            
            plane.width = CGFloat(self.extent.x)
            plane.height = CGFloat(self.extent.z)
        })
    }
}

fileprivate func PlaneSizeEqualToExtent(plane: SCNPlane, extent: vector_float3) -> Bool {
    if plane.width != CGFloat(extent.x) || plane.height != CGFloat(extent.z) {
        return false
    } else {
        return true
    }
}
