//
//  ViewController.swift
//  HeadCropper
//
//  Created by Doron Adler on 22/01/2023.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var labelTextField: NSTextField!
    @IBOutlet weak var startButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    func processFolder(_ folderURL: URL, saveFolderURL: URL? = nil) {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants], errorHandler: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "jpg" || fileURL.pathExtension == "jpeg" || fileURL.pathExtension == "png" || fileURL.pathExtension == "heic" {
                processImage(fileURL, saveFolderURL: saveFolderURL)
            }
        }
    }

    func processImage(_ imageURL: URL, saveFolderURL: URL? = nil) {
        DispatchQueue.main.async {
            self.labelTextField.stringValue = "Processing \(imageURL.pathComponents.last ?? "image")"
        }
        let image = NSImage(contentsOf: imageURL)
        if let image = image {
            guard let ciImage = CIImage(data: image.tiffRepresentation!) else {
                DispatchQueue.main.async {
                    self.labelTextField.stringValue = "Unable to read \(imageURL.pathComponents.last ?? "image")"
                }
                return
            }
            FaceCrop.cropHeads(ciImage, scaleFactor: 2.5) { contexts in
                var headIndex = 0
                for faceContext in contexts {
                    let croppedImage = faceContext.croppedImage
                    var croppedImageURL = imageURL.deletingPathExtension().appendingPathExtension("_head_\(headIndex).jpg")
                    if let saveFolderURL = saveFolderURL {
                        let origImageName = imageURL.pathComponents.last ?? "image"
                        croppedImageURL =
                        saveFolderURL.appendingPathComponent("\(origImageName)_head_\(headIndex).jpg")
                    }
                    headIndex += 1
                    if let croppedImage = croppedImage {
                        let bitmap = NSBitmapImageRep(ciImage: croppedImage)
                        if let jpegData = bitmap.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [:]) {
                            do {
                                try jpegData.write(to: croppedImageURL)
                                DispatchQueue.main.async {
                                    self.labelTextField.stringValue = "Saved \(croppedImageURL.absoluteString)"
                                }
                            } catch {
                                print("Error writing cropped image to disk: \(error)")
                                DispatchQueue.main.async {
                                    self.labelTextField.stringValue = "Error writing cropped image to disk: \(error)"
                                }
                            }
                        }
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.labelTextField.stringValue = "Unable to load \(imageURL.pathComponents.last ?? "image")"
            }
        }
    }
    
    func openSavePanelForFolderSelection(completionHandler handler: @escaping (URL?) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.title = "Choose a folder name for saving cropped results"
        savePanel.canCreateDirectories = true
        savePanel.canSelectHiddenExtension = false
        savePanel.begin { (result) in
            if result == .OK {
                if let url = savePanel.url {
                    print("Save to folder: \(url)")
                    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    handler (url)
                }
            } else {
                handler(nil)
            }
        }
    }

    @IBAction func loadPanelForImagesOrFolders(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = NSImage.imageTypes
        //openPanel.allowedContentTypes =
        openPanel.begin { (result) in
            if result == .OK {
                if let urls = openPanel.urls as [URL]? {
                    for url in urls {
                        if url.hasDirectoryPath {
                            let saveFolderURL = url.appendingPathComponent("heads")
                            try? FileManager.default.createDirectory(at: saveFolderURL, withIntermediateDirectories: true)
                            print("Save to folder: \(saveFolderURL)")
                            self.startButton.isEnabled = false
                            DispatchQueue.global(qos: .userInitiated).async {
                                self.processFolder(url, saveFolderURL: saveFolderURL)
                                DispatchQueue.main.async {
                                    self.startButton.isEnabled = true
                                    self.labelTextField.stringValue = "Done saving to \(saveFolderURL.absoluteString)"
                                }
                            }

                        } else {
                            self.openSavePanelForFolderSelection { resultURL in
                                self.startButton.isEnabled = false
                                DispatchQueue.global(qos: .userInitiated).async {
                                    if let saveFolderURL = resultURL {
                                        self.processImage(url, saveFolderURL: saveFolderURL)
                                        DispatchQueue.main.async {
                                            self.startButton.isEnabled = true
                                            self.labelTextField.stringValue = "Done saving to \(saveFolderURL.absoluteString)"
                                        }
                                    } else {
                                        self.processImage(url)
                                        DispatchQueue.main.async {
                                            self.startButton.isEnabled = true
                                            self.labelTextField.stringValue = "Done"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    
}

