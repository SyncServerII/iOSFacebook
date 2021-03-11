import iOSSignIn
import FacebookCore
import ServerShared
import iOSShared

/// Enables you to sign in as a Facebook user to (a) create a new sharing user (must have an invitation from another SyncServer user), or (b) sign in as an existing sharing user.
public class FacebookCredentials : GenericCredentials {
    private var savedCreds:FacebookSavedCreds!

    var accessToken:AccessToken! {
        return savedCreds?.accessToken
    }
    
    var userProfile:Profile! {
        return savedCreds?.userProfile
    }
    
    public var userId:String {
        guard let userId = savedCreds?.userId else {
            logger.error("FacebookCredentials: No savedCreds; could not get userId")
            return ""
        }
        
        return userId
    }
    
    public var username:String? {
        return savedCreds?.username
    }
    
    public var uiDisplayName:String? {
        return savedCreds?.username
    }
    
    // Helper
    public init(savedCreds:FacebookSavedCreds) {
        self.savedCreds = savedCreds
    }
    
    public var httpRequestHeaders:[String:String] {
        var result = [String:String]()
        result[ServerConstants.XTokenTypeKey] = AuthTokenType.FacebookToken.rawValue
        result[ServerConstants.HTTPOAuth2AccessTokenKey] = accessToken?.tokenString
        return result
    }
    
    public func refreshCredentials(completion: @escaping (Error?) ->()) {
        completion(GenericCredentialsError.noRefreshAvailable)
        FacebookSyncServerSignIn.refreshAccessToken { error in
            completion(error)
        }
    }
}
