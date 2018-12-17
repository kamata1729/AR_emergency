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
    
    let skechModel = SketchResModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.showsStatistics = true
        
        
        //let scene = SCNScene(named: "art.scnassets/ship.scn")!
        //sceneView.scene = scene
        
        print("butterfly")
        self.coreMLRequest(image: UIImage(named: "butterfly.png")!)
        
        print("chair")
        self.coreMLRequest(image: UIImage(named: "chair.png")!)
        print("dog")
        self.coreMLRequest(image: UIImage(named: "dog.png")!)
        print("dragon")
        self.coreMLRequest(image: UIImage(named: "dragon.png")!)
        print("elephant")
        self.coreMLRequest(image: UIImage(named: "elephant.png")!)
        print("horse")
        self.coreMLRequest(image: UIImage(named: "horse.png")!)
        print("pizza")
        self.coreMLRequest(image: UIImage(named: "pizza.png")!)
        print("race_car")
        self.coreMLRequest(image: UIImage(named: "race_car.png")!)
        print("ship")
        self.coreMLRequest(image: UIImage(named: "ship.png")!)
        print("toilet")
        self.coreMLRequest(image: UIImage(named: "toilet.png")!)
 
    }
    
    override func viewDidLayoutSubviews() {
        windowView.layer.borderColor = UIColor.red.cgColor
        windowView.layer.borderWidth = 10
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.timerUpdate), userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    @objc func timerUpdate() {
        let uiImage = sceneView.snapshot()
        let cropedUIImage = uiImage.cropImage2(w: Int(self.windowView.bounds.width*2), h: Int(self.windowView.bounds.height*2))
        self.coreMLRequest(image: cropedUIImage)
    }

    
    func coreMLRequest(image: UIImage){
        /*
         butterfly 0
         chair 1
         dog 2
         dragon 3
         elephant 4
         horse 5
         pizza 6
         race_car 7
         ship 8
         toilet 9
         */
        self.sampleImageView.image = image
        let imgSize: Int = 225
        let imageShape: CGSize = CGSize(width: imgSize, height: imgSize)
        let imagePixel = image.resize(to: imageShape).getPixelBuffer()
        let mlarray = try! MLMultiArray(shape: [1, NSNumber(value: imgSize), NSNumber(value: imgSize)], dataType: MLMultiArrayDataType.float32 )
        for i in 0..<imgSize*imgSize {
            mlarray[i] = imagePixel[i] as NSNumber
        }
        
        if let prediction = try? self.skechModel.prediction(_0: mlarray) {
            print(prediction._126.sorted{ $0.value > $1.value }.first)
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
    //get gray scale img array [Double]
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
        let thresh: Float = 0.5
        
        for j in 0..<height {
            for i in 0..<width {
                let pixelInfo = bytesPerRow * j + i * bytesPerPixel
                let r = CGFloat(pixelData[pixelInfo])
                let g = CGFloat(pixelData[pixelInfo+1])
                let b = CGFloat(pixelData[pixelInfo+2])
                
                var v: Float = 0.8
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
    
    func cropImage(w:Int, h:Int) -> UIImage {
        // リサイズ処理
        let origRef    = self.cgImage
        let origWidth  = Int(origRef!.width)
        let origHeight = Int(origRef!.height)
        var resizeWidth:Int = 0, resizeHeight:Int = 0
        
        if (origWidth < origHeight) {
            resizeWidth = w
            resizeHeight = origHeight * resizeWidth / origWidth
        } else {
            resizeHeight = h
            resizeWidth = origWidth * resizeHeight / origHeight
        }
        
        let resizeSize = CGSize.init(width: CGFloat(resizeWidth), height: CGFloat(resizeHeight))
        
        UIGraphicsBeginImageContext(resizeSize)
        
        self.draw(in: CGRect.init(x: 0, y: 0, width: CGFloat(resizeWidth), height: CGFloat(resizeHeight)))
        
        let resizeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 切り抜き処理
        
        let cropRect  = CGRect.init(x: CGFloat((resizeWidth - w) / 2), y: CGFloat((resizeHeight - h) / 2), width: CGFloat(w), height: CGFloat(h))
        let cropRef   = resizeImage!.cgImage!.cropping(to: cropRect)
        let cropImage = UIImage(cgImage: cropRef!)
        
        return cropImage
    }
    
    func cropImage2(w: Int, h: Int) -> UIImage {
        let origRef    = self.cgImage
        let origWidth  = Int(origRef!.width)
        let origHeight = Int(origRef!.height)
        let cropRect  = CGRect.init(x: CGFloat((origWidth - w) / 2), y: CGFloat((origHeight - h) / 2), width: CGFloat(w), height: CGFloat(h))
        let cropRef   = self.cgImage!.cropping(to: cropRect)
        let cropImage = UIImage(cgImage: cropRef!)
        
        return cropImage
    }
}

