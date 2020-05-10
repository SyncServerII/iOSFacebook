# iOSFacebook

1) Add your app as an app to Facebook (see https://developers.facebook.com). This will give you the app id and display name as below.

2) Add the following in your Info.plist
```
	<key>FacebookAppID</key>
	<string>PUT-YOUR-APP-ID-HERE</string>
    
	<key>FacebookDisplayName</key>
	<string>PUT-YOUR-APP-DISPLAY-NAME-HERE</string>
    
    <key>LSApplicationQueriesSchemes</key>
    <array>
      <string>fbapi</string>
      <string>fbapi20130214</string>
      <string>fbapi20130410</string>
      <string>fbapi20130702</string>
      <string>fbapi20131010</string>
      <string>fbapi20131219</string>
      <string>fbapi20140410</string>
      <string>fbapi20140116</string>
      <string>fbapi20150313</string>
      <string>fbapi20150629</string>
      <string>fbapi20160328</string>
      <string>fbauth</string>
      <string>fb-messenger-share-api</string>
      <string>fbauth2</string>
      <string>fbshareextension</string>
    </array>
```

See also  https://developers.facebook.com/docs/facebook-login/ios/   


3) Add fb<PUT-YOUR-APP-ID-HERE> as a URL Scheme in your app project in Xcode under the "Info" tab.

4) Add a Swift Package Manager dependency to this package to your project. E.g.,
```
    .package(url: "https://github.com/SyncServerII/iOSFacebook.git", .branch("master")),
```

5) Use this package in your project. E.g.,

```
    import iOSFacebook
```
