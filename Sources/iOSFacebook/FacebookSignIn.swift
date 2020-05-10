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

    public func signUserOut() {
        stickySignIn = false
        
        // Seem to have to do this before the `LoginManager().logOut()`, so we still have a valid token.
        reallySignUserOut()
        
        LoginManager().logOut()
        delegate?.userIsSignedOut(self)
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
    
    /*
    fileprivate func completeSignInProcess(autoSignIn:Bool) {
        
        // The Facebook signin button (`LoginButton`) automatically changes it's state to show "Sign out" when signed in. So, don't need to do that manually here.
        
        guard let userAction = delegate?.shouldDoUserAction(signIn: self) else {
            // This occurs if we don't have a delegate (e.g., on a silent sign in). But, we need to set up creds-- because this is what gives us credentials for connecting to the SyncServer.
            SyncServerUser.session.creds = credentials
            managerDelegate?.signInStateChanged(to: .signedIn, for: self)
            return
        }
        
        switch userAction {
        case .signInExistingUser:
            SyncServerUser.session.checkForExistingUser(creds: credentials!) {
                (checkForUserResult, error) in
                if error == nil {
                    switch checkForUserResult! {
                    case .noUser:
                        self.delegate?.userActionOccurred(action:
                            .userNotFoundOnSignInAttempt, signIn: self)
                        // 10/22/17; It seems legit to sign the user out. The server told us the user was not on the system.
                        self.signUserOut()
                        Log.msg("signUserOut: FacebookSignIn: noUser in checkForExistingUser")
                    
                    case .user(accessToken: let accessToken):
                        Log.msg("Sharing user signed in: access token: \(String(describing: accessToken))")
                        self.delegate?.userActionOccurred(action: .existingUserSignedIn, signIn: self)
                        self.managerDelegate?.signInStateChanged(to: .signedIn, for: self)
                    }
                }
                else {
                    let message = "Error checking for existing user: \(error!)"
                    Log.error(message)
                    
                    // 10/22/17; It doesn't seem legit to sign user out if we're doing this during a launch sign-in. That is, the user was signed in last time the app launched. And this is a generic error (e.g., a network error). However, if we're not doing this during app launch, i.e., this is a sign-in request explicitly by the user, if that fails it means we're not already signed-in, so it's safe to force the sign out.
                    
                    if autoSignIn {
                        self.managerDelegate?.signInStateChanged(to: .signedIn, for: self)
                    }
                    else {
                        self.signUserOut()
                        Log.msg("signUserOut: FacebookSignIn: error in checkForExistingUser and not autoSignIn")
                        Alert.show(withTitle: "Alert!", message: message)
                    }
                }
            }
            
        case .createOwningUser:
            // Facebook users cannot be owning users! They don't have cloud storage.
            Alert.show(withTitle: "Alert!", message: "Somehow a Facebook user attempted to create an owning user!!")
            // 10/22/17; Seems legit. Very odd error situation.
            signUserOut()
            Log.msg("signUserOut: FacebookSignIn: tried to create an owning user!")
            
        case .createSharingUser(invitationCode: let invitationCode):
            SyncServerUser.session.redeemSharingInvitation(creds: credentials!, invitationCode: invitationCode, cloudFolderName: SyncServerUser.session.cloudFolderName) {[unowned self] longLivedAccessToken, sharingGroupUUID, error in
                if error == nil, let sharingGroupUUID = sharingGroupUUID {
                    Log.msg("Facebook long-lived access token: \(String(describing: longLivedAccessToken))")
                    self.successCreatingSharingUser(sharingGroupUUID: sharingGroupUUID)
                }
                else {
                    Log.error("Error: \(error!)")
                    Alert.show(withTitle: "Alert!", message: "Error creating sharing user: \(error!)")
                    // 10/22/17; The common situation here seems to be the user is signing up via a sharing invitation. They are not on the system yet in that case. Seems safe to sign them out.
                    self.signUserOut()
                    Log.msg("signUserOut: FacebookSignIn: error in redeemSharingInvitation in")
                }
            }
            
        case .error:
            // 10/22/17; Error situation.
            self.signUserOut()
            Log.msg("signUserOut: FacebookSignIn: generic error in completeSignInProcess in")
        }
    }
    */
}

private class FacebookSignInButton : UIControl {
    var signInButton:FBLoginButton!
    weak var signIn: FacebookSyncServerSignIn!
        
    init() {
        // The parameters here are really unused-- I'm just using the FB LoginButton for it's visuals. I'm handling the actions myself because I need an indication of when the button is tapped, and can't seem to do that with FB's button. See the LoginManager below.
        signInButton = FBLoginButton()
        
        // It seems like asking for specific permissions isn't necessary. Seems like we get default user profile permissions. See https://developers.facebook.com/docs/facebook-login/permissions#reference-default
        // signInButton.permissions = []
        
        super.init(frame: signInButton.frame)
        addSubview(signInButton)
        signInButton.autoresizingMask = [.flexibleWidth]
        signInButton.addTarget(self, action: #selector(tap), for: .touchUpInside)
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
            signIn.delegate?.signInStarted(signIn)
            
            let loginManager = LoginManager()
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
                    self.signIn.signUserOut()
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


