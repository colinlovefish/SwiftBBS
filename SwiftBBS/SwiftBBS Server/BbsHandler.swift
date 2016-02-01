//
//  BbsHandler.swift
//  SwiftBBS
//
//  Created by Takeo Namba on 2016/01/16.
//	Copyright GrooveLab
//

import PerfectLib

class BbsHandler: BaseRequestHandler {
    //  repository
    lazy var bbsRepository: BbsRepository = BbsRepository(db: self.db)
    lazy var bbsCommentRepository: BbsCommentRepository = BbsCommentRepository(db: self.db)
    lazy var imageRepository: ImageRepository = ImageRepository(db: self.db)
    
    //  upload image
    lazy var uploadMaxFileSize: Int = Config.uploadImageFileSize
    lazy var uploadAllowFileExtensions: String = Config.uploadImageFileExtensions.joinWithSeparator(",")

    override init() {
        super.init()
        
        //  define action acl
        needLoginActions = ["add", "addcomment"]
        redirectUrlIfNotLogin = "/user/login"
        
        //        noNeedLoginActions = []
        //        redirectUrlIfLogin = "/"
    }
    
    override func dispatchAction(action: String) throws -> ActionResponse {
        switch request.action {
        case "add" where request.requestMethod() == "POST":
            return try addAction()
        case "addcomment" where request.requestMethod() == "POST":
            return try addcommentAction()
        case "detail":
            return try detailAction()
        default:
            return try listAction()
        }
    }
    
    //  MARK: actions
    func listAction() throws -> ActionResponse {
        let keyword = request.param("keyword")
        let bbsEntities = try bbsRepository.selectByKeyword(keyword, selectOption: selectOption)
        
        var values = [String: Any]()
        values["keyword"] = keyword ?? ""
        values["bbsList"] = bbsEntities.map({ (bbsEntity) -> [String: Any] in
            var dictionary = bbsEntity.toDictionary()
            if !request.acceptJson {
                dictionary["comment"] = (dictionary["comment"] as! String).stringByEncodingHTML.htmlBrString
            }
            return dictionary
        })
        
        let totalCount = try bbsRepository.countByKeyword(keyword)
        values["pager"] = Pager(totalCount: totalCount, selectOption: selectOption).toDictionary()
        
        return .Output(templatePath: "bbs_list.mustache", values: values)
    }
    
    func addAction() throws -> ActionResponse {
        let title: String!
        let comment: String!
        let image: MimeReader.BodySpec?

        //  validate
        do {
            let validator = ValidatorManager.build(["required", "length,1,100"])
            title = try validator.validatedString(request.param("title"))
        } catch ValidationError.Invalid(let message) {
            return .Error(status: 500, message: "invalidate request parameter title:" + message)
        }
        
        do {
            let validator = ValidatorManager.build(["required", "length,1,1000"])
            comment = try validator.validatedString(request.param("comment"))
        } catch ValidationError.Invalid(let message) {
            return .Error(status: 500, message: "invalidate request parameter comment:" + message)
        }

        do {
            image = request.uploadedFile("image")
            let validator = ValidatorManager.build(["image,\(uploadMaxFileSize),\(uploadAllowFileExtensions)"])
            try validator.validate(image)
        } catch ValidationError.Invalid(let message) {
            return .Error(status: 500, message: "invalidate request parameter image:" + message)
        }
        
        //  insert  TODO: begin transaction
        let entity = BbsEntity(id: nil, title: title, comment: comment, userId: try self.userIdInSession()!, createdAt: nil, updatedAt: nil)
        try bbsRepository.insert(entity)
        
        let bbsId = bbsRepository.lastInsertId()
        
        //  add image
        if let image = image {
            let imageService = ImageService(
                uploadedImage: image,
                uploadDirPath: request.docRoot + Config.uploadDirPath,
                repository: imageRepository
            )
            imageService.parent = .Bbs
            imageService.parentId = bbsId
            imageService.userId = try self.userIdInSession()!
            try imageService.save()    //  TODO: delete file if catch exception
        }
        
        if request.acceptJson {
            var values = [String: Any]()
            values["bbsId"] = bbsId
            return .Output(templatePath: nil, values: values)
        } else {
            return .Redirect(url: "/bbs/detail/\(bbsId)")
        }
    }
    
    func detailAction() throws -> ActionResponse {
        guard let bbsIdString = request.urlVariables["id"], let bbsId = Int(bbsIdString) else {
            return .Error(status: 500, message: "invalidate request parameter")
        }
        
        var values = [String: Any]()
        
        //  bbs
        guard let bbsEntity = try bbsRepository.findById(bbsId) else {
            return .Error(status: 404, message: "not found bbs")
        }
        var dictionary = bbsEntity.toDictionary()
        if !request.acceptJson {
            dictionary["comment"] = (dictionary["comment"] as! String).stringByEncodingHTML.htmlBrString
        }
        values["bbs"] = dictionary
        
        //  bbs image
        let imageEntities = try imageRepository.selectBelongTo(parent:.Bbs, parentId: bbsEntity.id)
        if let imageEntity = imageEntities.first {
            var dictionary = imageEntity.toDictionary()
            dictionary["url"] = "/" + Config.uploadDirPath + (dictionary["path"] as! String)
            values["image"] = dictionary
        }
        
        //  bbs post
        let bbsCommentEntities = try bbsCommentRepository.selectByBbsId(bbsId)
        values["comments"] = bbsCommentEntities.map({ (entity) -> [String: Any] in
            var dictionary = entity.toDictionary()
            if !request.acceptJson {
                dictionary["comment"] = (dictionary["comment"] as! String).stringByEncodingHTML.htmlBrString
            }
            return dictionary
        })
        
        return .Output(templatePath: "bbs_detail.mustache", values: values)
    }
    
    func addcommentAction() throws -> ActionResponse {
        let bbsId: Int!
        let comment: String!
        
        //  validate
        do {
            let validator = ValidatorManager.build(["required", "int,1,n"])
            bbsId = try validator.validatedInt(request.param("bbs_id"))
        } catch ValidationError.Invalid(let message) {
            return .Error(status: 500, message: "invalidate request parameter bbs_id:" + message)
        }
        
        do {
            let validator = ValidatorManager.build(["required", "length,1,1000"])
            comment = try validator.validatedString(request.param("comment"))
        } catch ValidationError.Invalid(let message) {
            return .Error(status: 500, message: "invalidate request parameter comment:" + message)
        }
        
        //  insert
        let entity = BbsCommentEntity(id: nil, bbsId: bbsId, comment: comment, userId: try userIdInSession()!, createdAt: nil, updatedAt: nil)
        try bbsCommentRepository.insert(entity)
        
        if request.acceptJson {
            var values = [String: Any]()
            values["commentId"] = bbsCommentRepository.lastInsertId()
            return .Output(templatePath: nil, values: values)
        } else {
            return .Redirect(url: "/bbs/detail/\(entity.bbsId)")
        }
    }
}
