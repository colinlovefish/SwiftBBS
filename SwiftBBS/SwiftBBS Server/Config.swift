//
//  Config.swift
//  SwiftBBS
//
//  Created by Takeo Namba on 2016/01/02.
//	Copyright GrooveLab
//

import PerfectLib

class Config {
    static let sessionName = "session"
    static let sessionExpires = 60
    static let dbName = "SwiftBBS"
    static let dbPath = PerfectServer.staticPerfectServer.homeDir() + serverSQLiteDBs + dbName
    static let uploadDirPath = "uploads/"
    static let uploadImageFileSize = 3 * 1024 * 1024
    static let uploadImageFileExtensions = ["jpg","png"]

#if os(Linux)
    static let imageMagickDir = ""
#else
    static let imageMagickDir = "/usr/local/bin/"
#endif
}
