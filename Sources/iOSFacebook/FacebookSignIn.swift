import Foundation
import FacebookCore
import FacebookLogin
import iOSSignIn
import ServerShared
import iOSShared

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
    
    fileprivate func signUserOut(cancelOnly: Bool) {
        stickySignIn = false
        
        // Seem to have to do this before the `LoginManager().logOut()`, so we still have a valid token.
        reallySignUserOut()
        
        LoginManager().logOut()
        
        if cancelOnly {
            delegate?.signInCancelled(self)
        }
        else {
            delegate?.userIsSignedOut(self)
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
    
    fileprivate func completeSignInProcess(autoSignIn:Bool) {
        stickySignIn = true
        delegate?.signInCompleted(self, autoSignIn: autoSignIn)
    }
}

private class FacebookSignInButton : UIControl {
    var signInButton:FBLoginButton!
    weak var signIn: FacebookSyncServerSignIn!
        
    init() {
        // The parameters here are really unused-- I'm just using the FB LoginButton for it's visuals. I'm handling the actions myself because I need an indication of when the button is tapped, and can't seem to do that with FB's button. See the LoginManager below.
        signInButton = FBLoginButton()
        
        // It seems like asking for specific permissions isn't necessary. Seems like we get default user profile permissions. See https://developers.facebook.com/docs/facebook-login/permissions#reference-default
        // signInButton.permissions = []
        
        signInButton.isUserInteractionEnabled = false
        signInButton.frame.origin = CGPoint.zero
        super.init(frame: signInButton.frame)
        addSubview(signInButton)
        signInButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addTarget(self, action: #selector(tap), for: .touchUpInside)
        clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Adapted from https://stackoverflow.com/questions/28131970
    private func fetchUserData(completion: @escaping (Error?)->()) {
        let graphRequest = GraphRequest(graphPath: "me", parameters: ["fields":"id, name"])
        graphRequest.start { (connection, result, error) in
            guard error == nil else {
                completion(error)
                return
            }
            
            completion(nil)
        }
    }

    @objc private func tap() {
        if signIn.userIsSignedIn {
            signIn.signUserOut()
            logger.info("signUserOut: FacebookSignIn: explicit request to signout")
        }
        else {
            signIn.delegate!.signInStarted(signIn)
            
            let loginManager = LoginManager()
            loginManager.logOut()
            loginManager.logIn(permissions: [], viewController: nil) {[unowned self] loginResult in
                switch loginResult {
                case .failed(let error):
                    logger.error("\(error)")
                    // 10/22/17; This is an explicit sign-in request. User is not yet signed in. Seems legit to sign them out.
                    self.signIn.signUserOut()
                    logger.error("signUserOut: FacebookSignIn: error during explicit request to signin")

                case .cancelled:
                    logger.info("User cancelled login.")
                    // 10/22/17; User cancelled sign-in flow. Seems fine to sign them out.
                    self.signIn.signUserOut(cancelOnly: true)
                    logger.info("signUserOut: FacebookSignIn: user cancelled sign-in during explicit request to signin")

                case .success(_, _, _):
                    logger.info("Logged in!")
                    
                    // Seems the UserProfile isn't loaded yet.
                    self.fetchUserData() { error in
                        if let error = error {
                            Alert.show(withTitle: "Alert!", message: "Error fetching UserProfile: \(error)")
                            logger.error("Error fetching UserProfile: \(error)")
                            // 10/22/17; As above-- this is coming from an explicit request to sign the user in. Seems fine to sign them out after an error.
                            self.signIn.signUserOut()
                            logger.error("signUserOut: FacebookSignIn: UserProfile.fetch failed during explicit request to signin")
                        }
                        else {
                            self.signIn.completeSignInProcess(autoSignIn: false)
                        }
                    }
                }
            }
        }
    }
}
