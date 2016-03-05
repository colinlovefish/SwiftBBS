//
//  ImageService.swift
//  SwiftBBS
//
//  Created by Takeo Namba on 2016/01/29.
//  Copyright GrooveLab
//

import PerfectLib

class ImageService {
    typealias ImageSize = (width: UInt, height: UInt)
    
    let uploadedImage: MimeReader.BodySpec
    let uploadDirPath: String
    let repository: ImageRepository
    var fileName: String? {
        return uploadedImage.tmpFileName.split(Character("/")).last
    }
    var fileExtension: String? {
        return uploadedImage.fileName.fileExtension
    }
    var originalName: String {
        return uploadedImage.fileName
    }
    var maxImageSize: ImageSize = (width: 100, height: 100)
    var parent = ImageEntity.Parent.Bbs
    var parentId: UInt = 0
    var userId: UInt = 0
    
    init(uploadedImage: MimeReader.BodySpec, uploadDirPath: String, repository: ImageRepository) {
        self.uploadedImage = uploadedImage
        self.uploadDirPath = uploadDirPath
        self.repository = repository
    }
    
    func save() throws {
        guard let imageFile = try copyToUploadDir() else {
            return
        }
        
        let imageSize = try resize(imageFile)
        let entity = ImageEntity(
            id: nil,
            parent: parent,
            parentId: parentId,
            path: fileName! + "." + fileExtension!,
            ext: fileExtension!,
            originalName: originalName,
            width: imageSize.width,
            height: imageSize.height,
            userId: userId,
            createdAt: nil,
            updatedAt: nil)
        try repository.insert(entity)
    }
    
    static func resize(filePath: String, maxImageSize: ImageSize) throws {
        let proc = try SysProcess(Config.imageMagickDir + "mogrify", args:["-strip", "-resize", "\(maxImageSize.width)x\(maxImageSize.height)>", filePath], env:nil)
        defer { proc.close() }
        if proc.isOpen() {
            try proc.wait(true)
        }
    }
    
    static func imageSize(filePath: String) throws -> ImageSize {
        let proc = try SysProcess(Config.imageMagickDir + "identify", args:["-format", "%wx%h", filePath], env:nil)
        defer { proc.close() }
        
        let fileOut = proc.stdout!
        let retString = UTF8Encoding.encode(try fileOut.readSomeBytes(4096))
        let imageSize = retString.split(Character("x"))
        return (width: UInt(imageSize.first ?? "0") ?? 0, UInt(imageSize.last ?? "0") ?? 0)
    }
    
    private func copyToUploadDir() throws -> File? {
        guard let fileName = fileName, let fileExtension = fileExtension else {
            return nil
        }
        return try File(uploadedImage.tmpFileName).copyTo(uploadDirPath + fileName + "." + fileExtension)
    }
    
    private func resize(file: File) throws -> ImageSize {
        try self.dynamicType.resize(file.path(), maxImageSize: maxImageSize)
        return try self.dynamicType.imageSize(file.path())
    }
}

