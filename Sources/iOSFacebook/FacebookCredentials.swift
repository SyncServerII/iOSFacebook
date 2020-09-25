import iOSSignIn
import FacebookCore
import ServerShared

/// Enables you to sign in as a Facebook user to (a) create a new sharing user (must have an invitation from another SyncServer user), or (b) sign in as an existing sharing user.
public class FacebookCredentials : GenericCredentials {
    #warning("When I integrate `SignIns` into iOSBasics remove cloudStorageType from `GenericCredentials` and this class")
    public var cloudStorageType: CloudStorageType? {
        return nil
    }
    
    var accessToken:AccessToken!
    var userProfile:Profile!
    
    public var userId:String {
        return userProfile.userID
    }
    
    public var username:String? {
        return userProfile.name
    }
    
    public var uiDisplayName:String? {
        return userProfile.name
    }
    
    public var httpRequestHeaders:[String:String] {
        var result = [String:String]()
        result[ServerConstants.XTokenTypeKey] = AuthTokenType.FacebookToken.rawValue
        result[ServerConstants.HTTPOAuth2AccessTokenKey] = accessToken.tokenString
        return result
    }
    
    public func refreshCredentials(completion: @escaping (Error?) ->()) {
        completion(GenericCredentialsError.noRefreshAvailable)
        // The AccessToken refresh method doesn't work if the access token has expired. So, I think it's not useful here.
    }
}
