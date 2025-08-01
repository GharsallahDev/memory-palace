import Vision
import UIKit
import CoreImage

@MainActor
class FaceDetectionManager: ObservableObject {
    @Published var isProcessing = false
    @Published var detectionProgress: Double = 0.0
    @Published var lastError: String?
    
    private let minFaceSize: Float = 0.05
    private let maxFaces: Int = 20
        
    func detectFaces(in image: UIImage) async -> [VNFaceObservation] {
        isProcessing = true
        detectionProgress = 0.0
        lastError = nil
        
        defer {
            isProcessing = false
            detectionProgress = 1.0
        }
        
        guard let cgImage = image.cgImage else {
            lastError = "Failed to process image"
            return []
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.lastError = error.localizedDescription
                        continuation.resume(returning: [])
                        return
                    }
                    
                    guard let observations = request.results as? [VNFaceObservation] else {
                        self.lastError = "No face detection results"
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let validFaces = observations.filter { observation in
                        observation.confidence > 0.5 &&
                        observation.boundingBox.width > CGFloat(self.minFaceSize) &&
                        observation.boundingBox.height > CGFloat(self.minFaceSize)
                    }
                    
                    let limitedFaces = Array(validFaces.prefix(self.maxFaces))
                                        
                    continuation.resume(returning: limitedFaces)
                }
            }
            
            request.revision = VNDetectFaceRectanglesRequestRevision3
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.lastError = error.localizedDescription
                    continuation.resume(returning: [])
                }
            }
        }
    }
        
    func processFacesForMemory(_ memory: Memory, image: UIImage) async -> [FaceTag] {
        let observations = await detectFaces(in: image)
        
        let faceTags = observations.map { observation in
            FaceTag(memoryId: memory.id, observation: observation)
        }
                
        return faceTags
    }
        
    func cropFaceRegion(from image: UIImage, observation: VNFaceObservation, padding: CGFloat = 0.2) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        let boundingBox = observation.boundingBox
        let faceRect = VNImageRectForNormalizedRect(boundingBox, Int(imageSize.width), Int(imageSize.height))
        
        let paddedRect = faceRect.insetBy(dx: -faceRect.width * padding, dy: -faceRect.height * padding)
        
        let clampedRect = paddedRect.intersection(CGRect(origin: .zero, size: imageSize))
        
        guard let croppedCGImage = cgImage.cropping(to: clampedRect) else { return nil }
        
        return UIImage(cgImage: croppedCGImage)
    }
        
    func createFaceOverlay(for image: UIImage, faces: [VNFaceObservation]) -> [CGRect] {
        let imageSize = image.size
        
        return faces.map { observation in
            let boundingBox = observation.boundingBox
            
            let convertedRect = CGRect(
                x: boundingBox.origin.x * imageSize.width,
                y: (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height,
                width: boundingBox.width * imageSize.width,
                height: boundingBox.height * imageSize.height
            )
            
            return convertedRect
        }
    }
    
    
    func processBatchOfMemories(_ memories: [Memory], images: [UIImage]) async -> [Memory] {
        guard memories.count == images.count else {
            lastError = "Memory and image count mismatch"
            return memories
        }
        
        isProcessing = true
        detectionProgress = 0.0
        
        var processedMemories: [Memory] = []
        
        for (index, memory) in memories.enumerated() {
            let image = images[index]
            
            if memory.type == .photo && !memory.faceDetectionCompleted {
                let faceTags = await processFacesForMemory(memory, image: image)
                var updatedMemory = memory
                updatedMemory.addFaceTags(faceTags)
                processedMemories.append(updatedMemory)
            } else {
                processedMemories.append(memory)
            }
            
            detectionProgress = Double(index + 1) / Double(memories.count)
        }
        
        isProcessing = false
        detectionProgress = 1.0
        
        return processedMemories
    }
        
    func areFacesSimilar(_ face1: VNFaceObservation, _ face2: VNFaceObservation, threshold: Float = 0.8) -> Bool {

        let ratio1 = face1.boundingBox.width / face1.boundingBox.height
        let ratio2 = face2.boundingBox.width / face2.boundingBox.height
        
        let ratioSimilarity = 1.0 - abs(ratio1 - ratio2)
        
        return Float(ratioSimilarity) > threshold
    }
        
    func resetState() {
        isProcessing = false
        detectionProgress = 0.0
        lastError = nil
    }
    
    var canDetectFaces: Bool {
        return !isProcessing
    }
    
    var processingStatus: String {
        if isProcessing {
            return "Detecting faces... \(Int(detectionProgress * 100))%"
        } else if let error = lastError {
            return "Error: \(error)"
        } else {
            return "Ready for face detection"
        }
    }
}
