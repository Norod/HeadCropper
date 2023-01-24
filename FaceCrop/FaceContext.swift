//
// Created by Doron Adler on 22/01/2023.
//

import Foundation
import AppKit
import Vision

class FaceContext {
    var croppedImage: CIImage?
    var faceRect: NSRect?
    var cropRect: NSRect?
    var yaw: NSNumber?
    var roll: NSNumber?
    var faceLandmarks: VNFaceLandmarks2D?
}
