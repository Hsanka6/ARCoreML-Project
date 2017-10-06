//
//  ViewController.swift
//  ArCoreML
//
//  Created by Haasith Sanka on 10/5/17.
//  Copyright © 2017 Haasith Sanka. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    private var resnetModel = Resnet50()
    
    
    private var hitTestResult : ARHitTestResult!
    private var visionRequests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        registerGestureRecognizers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    
    private func registerGestureRecognizers() {
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        self.sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func tapped(recognizer: UITapGestureRecognizer)
    {
        let sceneView = recognizer.view as! ARSCNView
        let touchLocation = self.sceneView.center
        
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        let hitTestResults = sceneView.hitTest(touchLocation, types: .featurePoint)
        
        
        if hitTestResults.isEmpty {
            return
        }
        
        guard let hitTestResult = hitTestResults.first else
        {
            return
        }
        self.hitTestResult = hitTestResult
        
        let pixelBuffer = currentFrame.capturedImage
        
        
        performVisionRequest(pixelBuffer: pixelBuffer)
    }
    
    private func performVisionRequest(pixelBuffer:CVPixelBuffer) {
        let visionModel = try!VNCoreMLModel(for: resnetModel.model)
        
        let request = VNCoreMLRequest(model: visionModel) { request, error in
            if error != nil{
                print(error.debugDescription)
                return
            }
            
            guard let observations = request.results else {
                return
            }
            let observation = observations.first as! VNClassificationObservation
            
            
            print("Name \(observation.identifier) and confidence is \(observation.confidence)")
            
            
            DispatchQueue.main.async {
                self.displayPredictions(text:observation.identifier)
            }
        }
        
        request.imageCropAndScaleOption = .centerCrop
        
        self.visionRequests = [request]
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .upMirrored, options: [ : ])
        
        DispatchQueue.global().async {
            try! imageRequestHandler.perform(self.visionRequests)
        }
    }
    
    
    private func displayPredictions(text: String)
    {
       //let node = createText(text: text)
        let node = createNewBubbleParentNode ( text )
        node.position = SCNVector3(self.hitTestResult.worldTransform.columns.3.x,self.hitTestResult.worldTransform.columns.3.y, self.hitTestResult.worldTransform.columns.3.z)
        
        self.sceneView.scene.rootNode.addChildNode(node)
        
    }
    
    func createNewBubbleParentNode ( _ text : String ) -> SCNNode {
        
        let bubbleDepth: Float = 0.01
         // TEXT BILLBOARD CONSTRAINT
         let billboardConstraint = SCNBillboardConstraint ()
         billboardConstraint.freeAxes = SCNBillboardAxis.Y
        // BUBBLE-TEXT
         let bubble = SCNText ( string : text , extrusionDepth :
            CGFloat ( bubbleDepth ))
         var font = UIFont ( name : "Futura" , size : 0.15 )
         //font = font?.withTraits(traits: .traitBold)
         bubble.font = font
        bubble.alignmentMode = kCAAlignmentCenter
        bubble.firstMaterial?.diffuse.contents = UIColor.orange
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
         // bubble.flatness // setting this too low can causecrashes.
         bubble.chamferRadius = CGFloat ( bubbleDepth )
        
         // BUBBLE NODE
         let ( minBound , maxBound ) = bubble.boundingBox
         let bubbleNode = SCNNode ( geometry : bubble )
         // Centre Node - to Centre-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation ((maxBound.x - minBound.x)/2 , minBound.y, bubbleDepth/2 )
         // Reduce default text size
        bubbleNode.scale = SCNVector3Make ( 0.2 , 0.2 , 0.2)
        // CENTRE POINT NODE
         let sphere = SCNSphere ( radius : 0.005 )
         sphere.firstMaterial?.diffuse.contents = UIColor.cyan
         let sphereNode = SCNNode ( geometry : sphere )
        
         // BUBBLE PARENT NODE
         let bubbleNodeParent = SCNNode ()
         bubbleNodeParent.addChildNode ( bubbleNode )
         bubbleNodeParent.addChildNode ( sphereNode )
         bubbleNodeParent.constraints = [ billboardConstraint ]
        
         return bubbleNodeParent
        
    }
    
    
    
    private func createText(text: String)->SCNNode{
        let parentNode = SCNNode()
        
        let sphere = SCNSphere(radius: 0.01)
        
        let sphereMaterial = SCNMaterial()
        sphereMaterial.diffuse.contents = UIColor.orange
        sphere.firstMaterial = sphereMaterial
        let sphereNode =  SCNNode(geometry: sphere)
        
        let textGeometry = SCNText(string: text, extrusionDepth: 0)
        textGeometry.alignmentMode = kCAAlignmentCenter
        textGeometry.firstMaterial?.diffuse.contents = UIColor.orange
        textGeometry.firstMaterial?.specular.contents = UIColor.white
        textGeometry.firstMaterial?.isDoubleSided = true
        
        let font = UIFont(name: "Futura", size: 0.15)
        
        textGeometry.font = font
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        parentNode.addChildNode(sphereNode)
        parentNode.addChildNode(textNode)
        return parentNode
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
