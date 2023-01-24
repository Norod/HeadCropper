//
// Created by Doron Adler on 22/01/2023.
//

import Foundation
import AppKit
import Vision

class FaceCrop {
    static func cropImage(image: NSImage, rect: NSRect) -> NSImage {
        let imageRef = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        let imageRefRect = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
        let imagePartRef = imageRef?.cropping(to: imageRefRect)
        let cropImage = NSImage(cgImage: imagePartRef!, size: rect.size)
        return cropImage
    }
    

    static func convertBoundingBoxToRect(boundingBox: CGRect, imageSize: CGRect) -> CGRect {
        // Convert the face rectangle from normalized coordinates to pixel coordinates
        let x = (boundingBox.minX * imageSize.width)
        let y = (boundingBox.minY * imageSize.height)
        let width = (boundingBox.width * imageSize.width)
        let height = (boundingBox.height * imageSize.height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func calculateCropRect(faceContext: FaceContext, imageSize: CGRect)  {
        guard let faceRect = faceContext.faceRect else {
            return
        }

        let scaleFactor = 2.5
        var scaledWidth = faceRect.size.width * scaleFactor
        var scaledHeight = faceRect.size.height * scaleFactor
        
        let yaw = faceContext.yaw?.doubleValue ?? 0.0
        let xPosShiftFactor = 0.5 + (yaw / 8.0)
        let roll = faceContext.roll?.doubleValue ?? 0.0
        let yPosShiftFactor = 0.5  + (roll / 8.0)
        var originX = faceRect.origin.x - ((scaledWidth - faceRect.size.width) * xPosShiftFactor)
        var originY = faceRect.origin.y - ((scaledHeight - faceRect.size.height) * yPosShiftFactor)

        if (originX < 0) {
            originX = 0
        }

        if (originX + scaledWidth > imageSize.width) {
            scaledWidth = imageSize.width - originX
        }

        if (originY < 0) {
            originY = 0
        }

        if (originY + scaledHeight > imageSize.height) {
            scaledHeight = imageSize.height - originY
        }
        
        let cropRect = CGRect(x: originX, y: originY, width: scaledWidth, height: scaledHeight)
        faceContext.cropRect = cropRect
    }

    static func applyCrop(faceContext: FaceContext, image: CIImage) {
        guard let cropRect = faceContext.cropRect else {
            return
        }
        let croppedImage = image.cropped(to: cropRect)        
        faceContext.croppedImage = croppedImage
    }

    static func cropHeads(_ image: CIImage, completion: @escaping ([FaceContext]) -> Void) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
            guard let observations = request.results as? [VNFaceObservation] else {
                fatalError("unexpected result type from VNDetectFaceLandmarksRequest")
            }

            var faceContexts = [FaceContext]()
            for observation in observations {
                let faceContext = FaceContext()
                let faceRect = convertBoundingBoxToRect(boundingBox: observation.boundingBox, imageSize: image.extent)
                faceContext.faceRect = faceRect
                faceContext.yaw = observation.yaw
                faceContext.roll = observation.roll
                faceContext.faceLandmarks = observation.landmarks
                calculateCropRect(faceContext: faceContext, imageSize: image.extent)
                applyCrop(faceContext: faceContext, image: image)
                faceContexts.append(faceContext)
            }
            completion(faceContexts)
        })
        let handler =  VNImageRequestHandler(ciImage: image, options: [:])
        do {
            try handler.perform([faceDetectionRequest])
        } catch {
            print(error)
        }
    }
}
