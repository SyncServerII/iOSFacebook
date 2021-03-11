
import Foundation
import FacebookCore
import FacebookLogin
import iOSShared

class FacebookSignInButton : UIControl {
    enum FacebookSignInButtonError: Error {
        case noUserAttributes
    }
    
    var signInButton:FBLoginButton!
    weak var signIn: FacebookSyncServerSignIn!
    
    init() {
        // The parameters here are really unused-- I'm just using the FB LoginButton for it's visuals. I'm handling the actions myself because I need an indication of when the button is tapped, and can't seem to do that with FB's button. See the LoginManager below.
        signInButton = FBLoginButton()
        
        // It seems like asking for specific permissions isn't necessary. Seems like we get default user profile permissions. See https://developers.facebook.com/docs/facebook-login/permissions#reference-default
        
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
    
    let nameKey = "name"
    let idKey = "id"
    
    // Adapted from https://stackoverflow.com/questions/28131970
    private func fetchUserData(completion: @escaping (Error?)->()) {
        let graphRequest = GraphRequest(graphPath: "me", parameters: ["fields":"\(nameKey), \(idKey)"])
        graphRequest.start { (connection, result, error) in
            if let error = error {
                completion(error)
                return
            }
            
            guard let result = result as? [String: String],
                let id = result[self.idKey],
                let name = result[self.nameKey] else {
                completion(FacebookSignInButtonError.noUserAttributes)
                return
            }

            Profile.current = Profile(userID: id, firstName: nil, middleName: nil, lastName: nil, name: name, linkURL: nil, refreshDate: Date())
            
            logger.debug("result: \(result)")
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
            loginManager.logIn(permissions: [], viewController: nil) {[weak self] loginResult in
                guard let self = self else { return }
                
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
                    self.fetchUserData() { [weak self] error in
                        guard let self = self else { return }
                        
                        func handleError(_ error: Error?) {
                            Alert.show(withTitle: "Alert!", message: "Error fetching UserProfile: \(String(describing: error))")
                            logger.error("Error fetching UserProfile: \(String(describing: error))")
                            // 10/22/17; As above-- this is coming from an explicit request to sign the user in. Seems fine to sign them out after an error.
                            self.signIn.signUserOut()
                            logger.error("signUserOut: FacebookSignIn: UserProfile.fetch failed during explicit request to signin")
                        }
                        
                        if let error = error {
                            handleError(error)
                            return
                        }
                        
                        guard let profile = Profile.current,
                            let username = profile.name,
                            let accessToken = AccessToken.current else {
                            handleError(nil)
                            return
                        }
 
                        FacebookSyncServerSignIn.savedCreds = FacebookSavedCreds(userId: profile.userID, username: username, accessToken: accessToken)
                        
                        self.signIn.completeSignInProcess(autoSignIn: false)
                    }
                }
            }
        }
    }
}
