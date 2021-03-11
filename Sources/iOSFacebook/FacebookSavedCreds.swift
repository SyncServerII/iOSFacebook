//
//  FacebookSavedCreds.swift
//  
//
//  Created by Christopher G Prince on 2/8/21.
//

import Foundation
import iOSSignIn
import iOSShared
import FacebookCore

public class FacebookSavedCreds: GenericCredentialsCodable, Equatable {
    public var userId:String
    public var username:String?
    
    // Unused. Just for compliance to `GenericCredentialsCodable`. See `GoogleCredentials`.
    public var uiDisplayName:String?
    
    var userProfile:Profile {
        return Profile(userID: userId, firstName: nil, middleName: nil, lastName: nil, name: username, linkURL: nil, refreshDate: nil)
    }
    
    var _accessToken:Data?
    var accessToken:AccessToken! {
        return Self.accessTokenFrom(data: _accessToken)
    }
    
    private static func accessTokenFrom(data:Data?) -> AccessToken! {
        guard let data = data else {
            return nil
        }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: AccessToken.self, from: data)
        } catch let error {
            logger.error("\(error)")
            return nil
        }
    }
    
    private static func dataFromAccessToken(_ accessToken: AccessToken) -> Data? {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: accessToken as Any, requiringSecureCoding: true)
        } catch let error {
            logger.error("\(error)")
            return nil
        }
    }
    
    public init(userId:String, username:String?, accessToken: AccessToken) {
        self.userId = userId
        self.username = username
        self._accessToken = Self.dataFromAccessToken(accessToken)
    }
    
    public static func == (lhs: FacebookSavedCreds, rhs: FacebookSavedCreds) -> Bool {
        return lhs.accessToken == rhs.accessToken &&
            lhs.userId == rhs.userId &&
            lhs.username == rhs.username
    }
}
