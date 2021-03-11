import Foundation
import FacebookCore
import FacebookLogin
import iOSSignIn
import ServerShared
import iOSShared
import PersistentValue

// Using the Facebook SDK in a sharing extension:
// https://github.com/facebookarchive/facebook-swift-sdk/issues/177
// https://stackoverflow.com/questions/40163451
// https://github.com/facebook/facebook-ios-sdk/issues/1607

public class FacebookSyncServerSignIn : GenericSignIn {
    static private let credentialsData = try! PersistentValue<Data>(name: "FacebookSyncServerSignIn.data", storage: .keyChain)

    public var signInName = "Facebook"
    
    private var stickySignIn = false

    public var delegate:GenericSignInDelegate?
    private let signInOutButton:FacebookSignInButton!
    
    public init() {
        signInOutButton = FacebookSignInButton()
        signInOutButton.signIn = self
    }
    
    public let userType:UserType = .sharing
    public let cloudStorageType: CloudStorageType? = nil // not owning; must be nil.
    
    public func appLaunchSetup(userSignedIn: Bool, withLaunchOptions options:[UIApplication.LaunchOptionsKey : Any]?) {
    
        ApplicationDelegate.shared.application(UIApplication.shared, didFinishLaunchingWithOptions: options)

        if userSignedIn {
            stickySignIn = true
            autoSignIn()
        }
    }
    
    public func networkChangedState(networkIsOnline: Bool) {
        if stickySignIn && networkIsOnline && credentials == nil {
            logger.info("FacebookSignIn: Trying autoSignIn...")
            autoSignIn()
        }
    }
    
    enum RefreshError: Error {
        case noSavedCreds
        case noUsername
        case noAccessToken
    }
    
    static func refreshAccessToken(completion:((Error?)->())?) {
        // `AccessToken.refreshCurrentAccessToken` isn't working from the sharing extension. Going to hope for the best and not do a refresh.
        if Bundle.isAppExtension {
            completion?(nil)
            return
        }
        
        AccessToken.refreshCurrentAccessToken { _, _, error in
            if let error = error {
                // I.e., I'm not going to force a sign-out because this seems like a generic error. E.g., could have been due to no network connection.
                logger.error("FacebookSignIn: Error refreshing access token: \(error)")
                completion?(error)
                return
            }

            guard let savedCreds = Self.savedCreds else {
                logger.error("FacebookSignIn: Error getting savedCreds after refresh.")
                completion?(RefreshError.noSavedCreds)
                return
            }

            guard let username = savedCreds.username else {
                logger.error("FacebookSignIn: Error getting username after refresh.")
                completion?(RefreshError.noUsername)
                return
            }
            
            guard let accessToken = AccessToken.current else {
                logger.error("FacebookSignIn: Error getting access token after refresh.")
                completion?(RefreshError.noAccessToken)
                return
            }
                        
            Self.savedCreds = FacebookSavedCreds(userId: savedCreds.userId, username: username, accessToken: accessToken)
            
            logger.info("FacebookSignIn: Sucessfully refreshed current access token")
            
            completion?(nil)
        }
    }
    
    private func autoSignIn() {
        Self.refreshAccessToken { error in
            guard error == nil else {
                return
            }
            
            self.completeSignInProcess(autoSignIn: true)
        }
    }
    
    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return ApplicationDelegate.shared.application(app, open: url, options: options)
    }

    @discardableResult
    public func signInButton(configuration:[String:Any]? = nil) -> UIView? {
        return signInOutButton
    }
    
    public var userIsSignedIn: Bool {
        return stickySignIn
    }

    static var savedCreds:FacebookSavedCreds? {
        set {
            let data = try? newValue?.toData()
#if DEBUG
            if let data = data {
                let string = String(data: data, encoding: .utf8)
                logger.debug("savedCreds: \(String(describing: string))")
            }
#endif
            Self.credentialsData.value = data
        }
        
        get {
            guard let data = Self.credentialsData.value,
                let savedCreds = try? FacebookSavedCreds.fromData(data) else {
                return nil
            }
            return savedCreds
        }
    }

    /// Returns non-nil if the user is signed in, and credentials could be refreshed during this app launch.
    public var credentials:GenericCredentials? {
        if let savedCreds = Self.savedCreds {
            return FacebookCredentials(savedCreds: savedCreds)
        }
        else {
            return nil
        }
    }
    
    func signUserOut(cancelOnly: Bool) {
        stickySignIn = false
        Self.savedCreds = nil
        
        DispatchQueue.main.async {
            // Seem to have to do this before the `LoginManager().logOut()`, so we still have a valid token.
            self.reallySignUserOut()
            
            LoginManager().logOut()
            
            if cancelOnly {
                self.delegate?.signInCancelled(self)
            }
            else {
                self.delegate?.userIsSignedOut(self)
            }
        }
    }

    public func signUserOut() {
        signUserOut(cancelOnly: false)
    }
    
    // It seems really hard to fully sign a user out of Facebook. The following helps.
    private func reallySignUserOut() {
        let deletePermission = GraphRequest(graphPath: "me/permissions/", parameters: [:], tokenString: AccessToken.current?.tokenString, version: nil, httpMethod: .delete)
        deletePermission.start { _, _, error in
            if error == nil {
                logger.error("Error: Failed logging out: \(String(describing: error))")
            }
            else {
                logger.info("Success logging out.")
            }
        }
    }
    
    func completeSignInProcess(autoSignIn:Bool) {
        stickySignIn = true
        delegate?.signInCompleted(self, autoSignIn: autoSignIn)
    }
}
