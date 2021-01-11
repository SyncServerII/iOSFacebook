import Foundation
import FacebookCore
import FacebookLogin
import iOSSignIn
import ServerShared
import iOSShared

// Using the Facebook SDK in a sharing extension:
// https://github.com/facebookarchive/facebook-swift-sdk/issues/177
// https://stackoverflow.com/questions/40163451
// https://github.com/facebook/facebook-ios-sdk/issues/1607

public class FacebookSyncServerSignIn : GenericSignIn {
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
    
    private func autoSignIn() {
        AccessToken.refreshCurrentAccessToken { _, _, error in
            if error == nil {
                logger.info("FacebookSignIn: Sucessfully refreshed current access token")
                self.completeSignInProcess(autoSignIn: true)
            }
            else {
                // I.e., I'm not going to force a sign-out because this seems like a generic error. E.g., could have been due to no network connection.
                logger.error("FacebookSignIn: Error refreshing access token: \(error!)")
            }
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

    /// Returns non-nil if the user is signed in, and credentials could be refreshed during this app launch.
    public var credentials:GenericCredentials? {
        if stickySignIn && AccessToken.current != nil {
            let creds = FacebookCredentials()
            creds.accessToken = AccessToken.current
            creds.userProfile = Profile.current
            return creds
        }
        else {
            return nil
        }
    }
    
    func signUserOut(cancelOnly: Bool) {
        stickySignIn = false
        
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
