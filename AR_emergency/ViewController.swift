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
import CoreMotion

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet weak var windowView: UIView!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var sampleImageView: UIImageView!
    @IBOutlet weak var sampleLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var controllerView: UIView!
    @IBOutlet weak var toggleView: UIView!
    
    @IBAction func tapButton(_ sender: Any) {
        self.timer?.invalidate()
        self.button.isHidden = true
        self.windowView.isHidden = true
        
        attitude()
        
        self.controllerView.isHidden = false
        self.toggleView.isHidden = false
        self.sampleLabel.isHidden = true
        self.isObjectOnPlane = true
        
        if let planeNode = self.sceneView.scene.rootNode.childNode(withName: "Plane", recursively: true) {
            let name = "art.scnassets/\(String(describing: classDic[self.classLabel]!)).scn"
            let ObjScene = SCNScene(named: name)!
            let objNode = ObjScene.rootNode.childNodes.first!
            
            self.initialRotateMat(node: objNode, label: self.classLabel)
            objNode.eulerAngles = SCNVector3Zero
            objNode.position = SCNVector3(x: 0, y: 0.05, z: 0)
            objNode.name = "objectNode"
            planeNode.addChildNode(objNode)
        }
    }
    
    
    private let device = MTLCreateSystemDefaultDevice()!
    let skechModel = SketchResModel()
    var motionManager: CMMotionManager?
    var timer: Timer?
    
    let classDic: [Int : String] = [0: "butterfly", 1: "chair", 2: "dog", 3: "dragon", 4: "elephant", 5: "horse", 6: "pizza", 7: "car", 8: "ship", 9: "toilet"]
    public var classLabel: Int = -1 //表示するオブジェクトの番号
    var pitch = 0.0
    var cViewWidth :CGFloat = 0
    var tViewWidth :CGFloat = 0
    var cViewCenter :CGPoint = CGPoint(x: 0, y: 0)
    private var isObjectOnPlane = false
    var isFirstUpdate = true
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.showsStatistics = true
        
        motionManager = CMMotionManager()
        motionManager?.deviceMotionUpdateInterval = 0.5
        
        
    }
    
    override func viewDidLayoutSubviews() {
        windowView.layer.borderColor = UIColor.red.cgColor
        windowView.layer.borderWidth = 10
        sampleLabel.numberOfLines = 0
        button.layer.cornerRadius = 20.0
        button.layer.masksToBounds = true
        button.titleLabel?.text = "決定"
        
        controllerView.layer.borderColor = UIColor.gray.cgColor
        controllerView.layer.borderWidth = 20
        controllerView.layer.cornerRadius = controllerView.bounds.width/2.0
        controllerView.layer.masksToBounds = true
        cViewWidth = controllerView.bounds.width
        
        cViewCenter = CGPoint(x: cViewWidth/2, y: self.view.bounds.height - cViewWidth/2)
        
        tViewWidth = toggleView.bounds.width
        toggleView.layer.cornerRadius = tViewWidth/2
        toggleView.layer.masksToBounds = true
        
        toggleView.center = cViewCenter
        
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        controllerView.isHidden = true
        toggleView.isHidden = true
        windowView.isHidden = true
        button.isHidden = true
        sampleLabel.isHidden = true
        
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
        
        //sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        sceneView.session.run(configuration)
    }

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //self.timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.timerUpdate), userInfo: nil, repeats: true)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isObjectOnPlane{
            let touch = touches.first!
            let location = touch.location(in: self.view)
            let distance: CGFloat = sqrt(pow(location.x - cViewCenter.x, 2) + pow(location.y - cViewCenter.y, 2))
            if distance < cViewWidth/2 {
                toggleView.center = location
            } else {
                let px: CGFloat = (cViewWidth/(distance*2)) * location.x + ((distance - cViewWidth/2)/distance) * cViewCenter.x
                let py: CGFloat = (cViewWidth/(distance*2)) * location.y + ((distance - cViewWidth/2)/distance) * cViewCenter.y
                toggleView.center = CGPoint(x: px, y: py)
            }
            if let objNode = self.sceneView.scene.rootNode.childNode(withName: "objectNode", recursively: true) {
                // 画面上での速度ベクトル
                let diff = SCNVector3(toggleView.center.x - cViewCenter.x, cViewCenter.y - toggleView.center.y, 0)
                // 画面上の座標を回転させて水平にする
                let rotateMat = SCNMatrix4MakeRotation(Float(-self.pitch), 1, 0, 0)
                let x = rotateMat.m11*diff.x + rotateMat.m21*diff.y + rotateMat.m31*diff.z
                let y = rotateMat.m12*diff.x + rotateMat.m22*diff.y + rotateMat.m32*diff.z
                let z = rotateMat.m13*diff.x + rotateMat.m23*diff.y + rotateMat.m33*diff.z
                let diffHorizontal = SCNVector3(x, y, z)
                // カメラ座標系をワールド座標系に変換（平面の座標系の変換行列(3*3)はワールド座標系と同じ）
                guard let cameraNode = sceneView.pointOfView else { return }
                let diffWorld = cameraNode.convertVector(diffHorizontal, to: nil)
                objNode.position.x += diffWorld.x*5e-5
                objNode.position.z += diffWorld.z*5e-5
                
                // objNodeははじめz方向, thetaはz方向からの回転角
                let theta = Float(atan2(diffWorld.x, diffWorld.z))
                objNode.eulerAngles.y = theta
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        toggleView.center = cViewCenter
    }
    
    override var canBecomeFirstResponder: Bool { get { return true } }

    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if event?.type == UIEvent.EventType.motion && event?.subtype == UIEvent.EventSubtype.motionShake {
            let alert: UIAlertController = UIAlertController(title: "alert", message: "最初からやり直す", preferredStyle:  UIAlertController.Style.alert)
            let defaultAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler:{
                (action: UIAlertAction!) -> Void in
                if let objNode = self.sceneView.scene.rootNode.childNode(withName: "objectNode", recursively: true) {
                    objNode.removeFromParentNode()
                }
                //self.sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
                //    node.removeFromParentNode()
                //}
                self.isObjectOnPlane = false
                self.controllerView.isHidden = true
                self.toggleView.isHidden = true
                
                self.windowView.isHidden = false
                self.button.isHidden = false
                self.sampleLabel.isHidden = false
                self.timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.timerUpdate), userInfo: nil, repeats: true)
            })
            let cancelAction: UIAlertAction = UIAlertAction(title: "キャンセル", style: UIAlertAction.Style.cancel, handler: nil)
            alert.addAction(cancelAction)
            alert.addAction(defaultAction)
            
            present(alert, animated: true, completion: nil)

        }
    }
    
    
    
    @objc func timerUpdate() {
        let uiImage = sceneView.snapshot()
        let cropedUIImage = uiImage.cropImage(w: Int(self.windowView.bounds.width*2), h: Int(self.windowView.bounds.height*2))
        self.coreMLRequest(image: cropedUIImage)
    }
    
    // 姿勢(pitch)測定
    func attitude() {
        guard let _ = motionManager?.isDeviceMotionAvailable,
            let operationQueue = OperationQueue.current
            else {
                return
        }
        motionManager?.startDeviceMotionUpdates(to: operationQueue, withHandler: { motion, _ in
            if let attitude = motion?.attitude {
                self.pitch = attitude.pitch
            }
        })
    }
    /*
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        print("didAdd")
        if let imageAnchor = anchor as? ARImageAnchor {
            let dummyPlane = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height)
            dummyPlane.firstMaterial?.diffuse.contents = UIColor(white: 1.0, alpha: 0)
            
            let dummyPlaneNode = SCNNode(geometry: dummyPlane)
            dummyPlaneNode.eulerAngles.x = -.pi/2.0
            dummyPlaneNode.name = "dummyPlaneNode"
            
            let ObjScene = SCNScene(named: "art.scnassets/dragon.scn")!
            let objectNode = ObjScene.rootNode.childNodes.first!
            self.initialRotateMat(node: objectNode, label: 3)
            objectNode.eulerAngles.x = .pi/2
            objectNode.name = "objectNode"
            
            dummyPlaneNode.addChildNode(objectNode)
            node.addChildNode(dummyPlaneNode)
        }
    }
    */
    // didUpdate
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            
            // ARPlaneAnchor
            if let planeAnchor = anchor as? ARPlaneAnchor{
                if self.isFirstUpdate {
                    self.windowView.isHidden = false
                    self.button.isHidden = false
                    self.sampleLabel.isHidden = false
                    self.timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.timerUpdate), userInfo: nil, repeats: true)
                    self.isFirstUpdate = false
                }
                if let planeGeometry = planeAnchor.findShapedPlaneNode(on: node)?.geometry as? ARSCNPlaneGeometry {
                    planeGeometry.update(from: planeAnchor.geometry)
                } else {
                    let planeGeo = ARSCNPlaneGeometry(device: self.device)!
                    planeGeo.update(from: planeAnchor.geometry)
                    
                    let color = UIColor.white
                    planeAnchor.addPlaneNode(on: node, geometry: planeGeo, contents: color.withAlphaComponent(0.3))
                }
            }
                
                /*
                
                if let planeNode = self.sceneView.scene.rootNode.childNode(withName: "Plane", recursively: true) {
                    if let objNode = self.sceneView.scene.rootNode.childNode(withName: "objectNode", recursively: true) {
                        // planeとobjectがどちらも存在しているとき
                        
                        if planeNode.childNodes.count > 0{
                            // 4. PlaneNodeにobjNodeが追加されているときの最初
                            if !self.isObjectOnPlane {
                                // コントローラーを表示
                                self.controllerView.isHidden = false
                                self.toggleView.isHidden = false
                                self.isObjectOnPlane = true
                            }
                        } else {
                            // 2. objNodeが存在している時
                            
                            let distance = sqrt(pow(objNode.worldPosition.y - planeNode.worldPosition.y, 2.0))
                            
                            if distance < 0.1 {
                                // 3. 画像と平面が近くなったとき
                                objNode.removeFromParentNode()
                                self.initialRotateMat(node: objNode, label: 5)
                                objNode.eulerAngles = SCNVector3Zero
                                objNode.position = SCNVector3(x: 0, y: 0.05, z: 0)
                                
                                planeNode.addChildNode(objNode)
                            }
                        }
                    }
 }
            }*/
        }
    }
 
    
    func initialRotateMat(node: SCNNode, label: Int) {
        let mat = SCNMatrix4Identity
        /*
         [0: "butterfly", 1: "chair", 2: "dog", 3: "dragon", 4: "elephant", 5: "horse", 6: "pizza", 7: "race_car", 8: "ship", 9: "toilet"]
         */
        
        switch label {
        case 0: //butterfly
            let mult = SCNMatrix4Rotate(mat, .pi/2, 0, 1, 0)
            node.pivot = mult
            node.scale = SCNVector3(x: 0.001, y: 0.001, z: 0.001)
        case 1: //chair
            let mult = SCNMatrix4Rotate(mat, .pi/2, 1, 0, 0)
            node.pivot = mult
            let scale: Float = 0.0008
            node.scale = SCNVector3(x: scale, y: scale, z: scale)
        case 2: //dog
            let mult = SCNMatrix4Rotate(mat, .pi/2, 1, 0, 0)
            node.pivot = mult
            let scale: Float = 0.0020
            node.scale = SCNVector3(x: scale, y: scale, z: scale)
        case 3: //dragon
            let scale: Float = 0.07
            node.scale = SCNVector3(x: scale, y: scale, z: scale)
        case 4: //elephant
            let mult = SCNMatrix4Rotate(mat, -.pi/2, 0, 1, 0)
            node.pivot = mult
            let scale: Float = 0.018
            node.scale = SCNVector3(x: scale, y: scale, z: scale)
        case 5: //horse
            let mult = SCNMatrix4Rotate(mat, .pi/2, 1, 0, 0)
            node.pivot = mult
            node.scale = SCNVector3(x: 0.00005, y: 0.00005, z: 0.00005)
        case 6: //pizza
            let mult = SCNMatrix4Rotate(mat, .pi/2, 1, 0, 0)
            node.pivot = mult
            let scale: Float = 0.005
            node.scale = SCNVector3(x: scale, y: scale, z: scale)
        case 7: //car
            let mult1 = SCNMatrix4Rotate(mat, .pi/2, 1, 0, 0)
            let mult2 = SCNMatrix4Rotate(mat, -.pi/2, 0, 1, 0)
            let mult3 = SCNMatrix4MakeTranslation(0, -35, 0)
            let mult4 = SCNMatrix4Mult(mult2, mult1)
            let mult = SCNMatrix4Mult(mult3, mult4)
            node.pivot = mult
            let scale: Float = 0.0006
            node.scale = SCNVector3(x: scale, y: scale, z: scale)
        case 8: //ship
            let mult1 = SCNMatrix4Rotate(mat, .pi/2, 1, 0, 0)
            let mult2 = SCNMatrix4Rotate(mat, .pi/2, 0, 1, 0)
            let mult = SCNMatrix4Mult(mult2, mult1)
            node.pivot = mult
            let scale: Float = 0.00006
            node.scale = SCNVector3(x: scale, y: scale, z: scale)
        case 9: //toilet
            let mult1 = SCNMatrix4Rotate(mat, .pi/2, 1, 0, 0)
            let mult2 = SCNMatrix4MakeTranslation(0, -20, 0)
            let mult = SCNMatrix4Mult(mult2, mult1)
            node.pivot = mult
            let scale: Float = 0.0035
            node.scale = SCNVector3(x: scale, y: scale, z: scale)
        default:
            return
        }
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
}
