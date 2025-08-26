# Face Recognition

Face recognition library for Ver-ID using ArcFace model.

## Installation

### Swift Package Manager

1. Open your project in Xcode.
2. Select your project in the Project Navigator.
3. Click on the Package Dependencies tab.
4. Click the + icon and enter `https://github.com/AppliedRecognition/Face-Recognition-ArcFace-Apple.git` in the search box labelled "Search or Enter Package URL".
5. In the Dependency Rule drop-down select Up to Next Major Version and enter 1.0.0 in the adjacent text box.
6. Press the "Add Package" button.

## Usage

You will need an API key to use the face recognition in your project. The API key in tests is rate-limited and not suitable for production applications. Please [contact Applied Recognition](mailto:support@appliedrecognition.com) to obtain an API key.

### Sample code

```swift
import UIKit
import VerIDCommonTypes
import FaceRecognitionArcFace
import FaceDetectionRetinaFace

let faceRecognition = FaceRecognitionArcFace(apiKey: <your API key>, url: <API URL>)
let faceDetection = try FaceDetectionRetinaFace()

func isPersonInImage(_ image1: UIImage, sameAsPersonInImage image2: UIImage) async throws -> Bool {
    // 1. Create Ver-ID images from UIImages
    guard let cgImage1 = image1.cgImage, let verIDImage1 = Image(cgImage: cgImage1) else {
        throw FaceRecognitionError.imageConversionFailed
    }
    guard let cgImage2 = image2.cgImage, let verIDImage2 = Image(cgImage: cgImage2) else {
        throw FaceRecognitionError.imageConversionFailed
    }
    
    // 2. Detect faces (assuming one face per image)
    let face1 = try await detectFaceInImage(verIDImage1)
    let face2 = try await detectFaceInImage(verIDImage2)
    
    // 3. Extract face templates from faces
    let faceTemplate1 = try await faceRecognition.createFaceRecognitionTemplates(from: [face1], in: verIDImage1).first!
    let faceTemplate2 = try await faceRecognition.createFaceRecognitionTemplates(from: [face2], in: verIDImage2).first!
    
    // 4. Compare face templates
    let score = try await faceRecognition.compareFaceRecognitionTemplates([faceTemplate1], to: faceTemplate2).first!
    
    // 5. Return whether score > threshold
    return score >= faceRecognition.defaultThreshold
}

func detectFaceInImage(_ image: Image) async throws -> Face {
    guard let face = try await faceDetection.detectFaceInImage(image, limit: 1).first else {
        throw FaceRecognitionError.noFaceDetected
    }
    return face
}

enum FaceRecognitionError: Error {
    case imageConversionFailed, noFaceDetected
}
```
