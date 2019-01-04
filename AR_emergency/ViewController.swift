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
    @IBOutlet weak var controllerView: UIView!
    @IBOutlet weak var toggleView: UIView!
    
    @IBAction func tapButton(_ sender: Any) {
        let uiImage = sceneView.snapshot()
        let cropedUIImage = uiImage.cropImage(w: Int(self.windowView.bounds.width*2), h: Int(self.windowView.bounds.height*2))
        self.coreMLRequest(image: cropedUIImage)
        
        self.button.isHidden = true
        self.windowView.isHidden = true
    }
    
    private let device = MTLCreateSystemDefaultDevice()!
    
    let skechModel = SketchResModel()
    let classDic: [Int : String] = [0: "butterfly", 1: "chair", 2: "dog", 3: "dragon", 4: "elephant", 5: "horse", 6: "pizza", 7: "race_car", 8: "ship", 9: "toilet"]
    public var classLabel: Int = -1 //表示するオブジェクトの番号
    
    private var isObjectOnPlane = false
    
    var cViewWidth :CGFloat = 0
    var tViewWidth :CGFloat = 0
    var cViewCenter :CGPoint = CGPoint(x: 0, y: 0)
    
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
        
        controllerView.layer.borderColor = UIColor.gray.cgColor
        controllerView.layer.borderWidth = 20
        controllerView.layer.cornerRadius = controllerView.bounds.width/2.0
        controllerView.layer.masksToBounds = true
        cViewWidth = controllerView.bounds.width
        controllerView.isHidden = true
        
        tViewWidth = toggleView.bounds.width
        toggleView.layer.cornerRadius = tViewWidth/2
        toggleView.layer.masksToBounds = true
        cViewCenter = CGPoint(x: cViewWidth/2, y: self.view.bounds.height - cViewWidth/2)
        toggleView.center = cViewCenter
        toggleView.isHidden = true
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
        
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        sceneView.session.run(configuration)
    }

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
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
                let theta = Float(atan2(toggleView.center.x - cViewCenter.x, cViewCenter.y - toggleView.center.y))
                objNode.eulerAngles.y = -theta
                print(objNode.eulerAngles.y)
                objNode.position.z += Float(distance)*cos(theta)*5e-5
                objNode.position.x -= Float(distance)*sin(theta)*5e-5
                print(objNode.position)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        toggleView.center = cViewCenter
    }
   
    
    // didUpdate
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if self.classLabel != -1{
                
                // ARPlaneAnchor
                if !self.isObjectOnPlane {
                    if let planeAnchor = anchor as? ARPlaneAnchor{
                        if let planeGeometry = planeAnchor.findShapedPlaneNode(on: node)?.geometry as? ARSCNPlaneGeometry {
                            planeGeometry.update(from: planeAnchor.geometry)
                        } else {
                            let planeGeo = ARSCNPlaneGeometry(device: self.device)!
                            planeGeo.update(from: planeAnchor.geometry)
                            
                            let color = UIColor.white
                            planeAnchor.addPlaneNode(on: node, geometry: planeGeo, contents: color.withAlphaComponent(0.3))
                        }
                    }
                }
                
                // ARImageAnchor
                if let imageAnchor = anchor as? ARImageAnchor {
                    if let planeNode = self.sceneView.scene.rootNode.childNode(withName: "Plane", recursively: true) {
                        if let objNode = self.sceneView.scene.rootNode.childNode(withName: "objectNode", recursively: true) {
                            if planeNode.childNodes.count > 0{
                                // 4. PlaneNodeにobjNodeが追加されているとき
                                if !self.isObjectOnPlane {
                                    // コントローラーを表示
                                    self.controllerView.isHidden = false
                                    self.toggleView.isHidden = false
                                    print("add objNode")
                                    print(objNode.worldPosition)
                                    print(objNode.position)
                                    self.isObjectOnPlane = true
                                }
                            } else {
                                // 2. objNodeが存在している時
                                print("objNode")
                                print(objNode.worldPosition)
                                print(objNode.position)
                                print("PlaneNode")
                                print(planeNode.worldPosition)
                                print(planeNode.position)
                                //let distance = sqrt(pow(objNode.worldPosition.x - planeNode.worldPosition.x, 2.0) + pow(objNode.worldPosition.y - planeNode.worldPosition.y, 2.0) + pow(objNode.worldPosition.z - planeNode.worldPosition.z, 2.0))
                                let distance = sqrt(pow(objNode.worldPosition.y - planeNode.worldPosition.y, 2.0))
                                print(distance)
                                print(distance)
                                // 3. 画像と平面が近くなったとき
                                if distance < 0.1 {
                                    objNode.removeFromParentNode()
                                    objNode.eulerAngles = SCNVector3Zero
                                    objNode.position = SCNVector3(x: 0, y: 0.05, z: 0)
                                    //objNode.position = planeNode.convertPosition(SCNVector3(x: objNode.worldPosition.x - planeNode.worldPosition.x, y: objNode.worldPosition.y - planeNode.worldPosition.y, z: objNode.worldPosition.z - planeNode.worldPosition.z), to: nil)
                                    
                                    planeNode.addChildNode(objNode)
                                }
                            }
                        } else {
                            // 1. 最初に平面と画像を認識したとき
                            print("detect image and plane")
                            let dummyPlane = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height)
                            dummyPlane.firstMaterial?.diffuse.contents = UIColor(white: 1.0, alpha: 0)
                            
                            let dummyPlaneNode = SCNNode(geometry: dummyPlane)
                            dummyPlaneNode.eulerAngles.x = -.pi/2.0
                            //planeNode.name = "planeNode"
                            
                            let shipScene = SCNScene(named: "art.scnassets/ship.scn")!
                            let objectNode = shipScene.rootNode.childNodes.first!
                            objectNode.eulerAngles.x = .pi/2
                            objectNode.name = "objectNode"
                            
                            dummyPlaneNode.addChildNode(objectNode)
                            node.addChildNode(dummyPlaneNode)
                        }
                    }
                }
            }
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
