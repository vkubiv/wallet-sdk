//
//  flutterPlugin.swift
//  Runner
//
//  Created by Avast.Inc on 2022-10-24.
//

import Flutter
import UIKit
import Walletsdk

public class SwiftWalletSDKPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "WalletSDKPlugin", binaryMessenger: registrar.messenger())
        let instance = SwiftWalletSDKPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    struct qrCodeData{
        static var requestURI = ""
    }
    
    private var kms:LocalkmsKMS?
    private var didResolver: ApiDIDResolverProtocol?
    private var documentLoader: ApiLDDocumentLoaderProtocol?
    private var crypto: ApiCryptoProtocol?
    private var didDocRes: ApiDIDDocResolution?
    private var didDocID: String?
    private var newOIDCInteraction: Openid4ciInteraction?
    private var didVerificationMethod: ApiVerificationMethod?
    private var activityLogger: MemActivityLogger?

    private var openID4VP: OpenID4VP?
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? Dictionary<String, Any>
        
        switch call.method {
        case "createDID":
            let didMethodType = fetchArgsKeyValue(call, key: "didMethodType")
            createDid(didMethodType: didMethodType!, result: result)
            
        case "authorize":
            let requestURI = fetchArgsKeyValue(call, key: "requestURI")
            qrCodeData.requestURI = requestURI!
            authorize(requestURI: requestURI!, result: result)
            
        case "requestCredential":
            let otp = fetchArgsKeyValue(call, key: "otp")
            requestCredential(otp: otp!, result: result)

        case "fetchDID":
            let didID = fetchArgsKeyValue(call, key: "didID")
            if didDocID == nil {
                didDocID = didID
            }

        case "resolveCredentialDisplay":
            resolveCredentialDisplay(arguments: arguments!,  result: result)
            
        case "getCredID":
            getCredID(arguments: arguments!,  result: result)
            
        case "parseActivities":
            parseActivities(arguments: arguments!,  result: result)
            
        case "initSDK":
            initSDK(result:result)
            
        case "issuerURI":
            issuerURI(result:result)

        case "activityLogger":
            storeActivityLogger(result:result)

        case "processAuthorizationRequest":
            processAuthorizationRequest(arguments: arguments!, result: result)
            
        case "presentCredential":
            presentCredential(result: result)
            
        default:
            print("No call method is found")
        }
    }
    
    private func initSDK(result: @escaping FlutterResult) {
        let kmsstore = kmsStore()
        kms = LocalkmsNewKMS(kmsstore, nil)
        didResolver = DidNewResolver("http://did-resolver.trustbloc.local:8072/1.0/identifiers", nil)
        crypto = kms?.getCrypto()
        documentLoader = LdNewDocLoader()
        activityLogger = MemNewActivityLogger()
        result(true)
    }
    
    private func createOpenID4VP() throws -> OpenID4VP {
        guard let kms = self.kms else {
            throw OpenID4VPError.runtimeError("SDK is not initialized, call initSDK()")
        }
        guard let crypto = self.crypto else {
            throw OpenID4VPError.runtimeError("SDK is not initialized, call initSDK()")
        }
        guard let didResolver = self.didResolver else {
            throw OpenID4VPError.runtimeError("SDK is not initialized, call initSDK()")
        }
        guard let documentLoader = self.documentLoader else {
            throw OpenID4VPError.runtimeError("SDK is not initialized, call initSDK()")
        }
        
        return OpenID4VP(keyReader: kms, didResolver: didResolver, documentLoader: documentLoader, crypto: crypto, activityLogger: activityLogger!)
    }
    /**
     This method  invoke processAuthorizationRequest defined in OpenID4Vp file.
     */
    public func processAuthorizationRequest(arguments: Dictionary<String, Any> , result: @escaping FlutterResult) {
        do {
            
            guard let authorizationRequest = arguments["authorizationRequest"] as? String else{
                return  result(FlutterError.init(code: "NATIVE_ERR",
                                                 message: "error while process authorization request",
                                                 details: "parameter authorizationRequest is missed"))
            }
            
            guard let storedCredentials = arguments["storedCredentials"] as? Array<String> else{
                return  result(FlutterError.init(code: "NATIVE_ERR",
                                                 message: "error while process authorization request",
                                                 details: "parameter storedCredentials is missed"))
            }
            
            
            let openID4VP = try createOpenID4VP()
            self.openID4VP = openID4VP
            
            let opts = VcparseNewOpts(true, nil)
            var parsedCredentials: Array<ApiVerifiableCredential> = Array()
            
            for cred in storedCredentials{
                let parsedVC = VcparseParse(cred, opts, nil)!
                parsedCredentials.append(parsedVC)
            }
            
            let matchedCredentials = try openID4VP.processAuthorizationRequest(authorizationRequest: authorizationRequest, credentials: parsedCredentials)
            result(matchedCredentials)
            
        } catch OpenID4VPError.runtimeError(let errorMsg){
            result(FlutterError.init(code: "NATIVE_ERR",
                                     message: "error while process authorization request",
                                     details: errorMsg))
        } catch let error as NSError {
            result(FlutterError.init(code: "NATIVE_ERR",
                                     message: "error while process authorization request",
                                     details: error.description))
        }
    }
    
    /**
     This method invokes presentCredentialt defined in OpenID4Vp file.
     */
    public func presentCredential(result: @escaping FlutterResult) {
        do {
            guard let openID4VP = self.openID4VP else{
                return  result(FlutterError.init(code: "NATIVE_ERR",
                                                 message: "error while process present credential",
                                                 details: "OpenID4VP interaction is not initialted"))
            }

            try openID4VP.presentCredential(didVerificationMethod: didVerificationMethod!)
            result(true);
            
        } catch OpenID4VPError.runtimeError(let errorMsg){
            result(FlutterError.init(code: "NATIVE_ERR",
                                     message: "error while process authorization request",
                                     details: errorMsg))
        } catch let error as NSError{
            result(FlutterError.init(code: "NATIVE_ERR",
                                     message: "error while process authorization request",
                                     details: error.description))
        }
    }
    
    /**
     Create method of  DidNewCreatorWithKeyWriter creates a DID document using the given DID method.
     The usage of ApiCreateDIDOpts depends on the DID method you're using.
     In the app when user logins we invoke sdk DidNewCreatorWithKeyWriter create method to create new did per user.
     */
    public func createDid(didMethodType: String, result: @escaping FlutterResult){
        let didCreator = DidNewCreatorWithKeyWriter(self.kms, nil)
        do {
            let apiCreate = ApiCreateDIDOpts.init()
            if (didMethodType == "jwk"){
                apiCreate.keyType = "ECDSAP384IEEEP1363"
            }
          
            let doc = try didCreator!.create(didMethodType, createDIDOpts: apiCreate)
            didDocID = doc.id_(nil)
            didVerificationMethod = try doc.assertionMethod()
            result(didDocID)
        } catch {
            result(FlutterError.init(code: "NATIVE_ERR",
                                     message: "error while creating did",
                                     details: error))
        }
    }
    
    /**
     *Authorize method of Openid4ciNewInteraction is used by a wallet to authorize an issuer's OIDC Verifiable Credential Issuance Request.
     After initializing the Interaction object with an Issuance Request, this should be the first method you call in
     order to continue with the flow.
     
     AuthorizeResult is the object returned from the Client.Authorize method.
     The userPinRequired method available on authorize result returns boolean value to differentiate pin is required or not.
     */
    public func authorize(requestURI: String, result: @escaping FlutterResult){
        let clientConfig =  Openid4ciClientConfig("ClientID", crypto: self.crypto, didRes: self.didResolver, activityLogger: activityLogger)
        newOIDCInteraction = Openid4ciNewInteraction(qrCodeData.requestURI, clientConfig, nil)
        do {
            let authorizeResult  = try newOIDCInteraction?.authorize()
            let userPINRequired = authorizeResult?.userPINRequired;
            // Todo Issue-65 Pass the whole object for the future changes
            result(Bool(userPINRequired ?? false))
          } catch {
              result(FlutterError.init(code: "NATIVE_ERR",
                                       message: "error while creating new OIDC interaction",
                                       details: error))
          }
    }
    
    /**
    * RequestCredential method of Openid4ciNewInteraction is the final step in the
    interaction. This is called after the wallet is authorized and is ready to receive credential(s).
    
    Here if the pin required is true in the authorize method, then user need to enter OTP which is intercepted to create CredentialRequest Object using
    Openid4ciNewCredentialRequestOpt.
     If flow doesnt not require pin than Credential Request Opts will have empty string otp and sdk will return credential Data based on empty otp.
    */
    public func requestCredential(otp: String, result: @escaping FlutterResult){
        let clientConfig =  Openid4ciClientConfig("ClientID", crypto: self.crypto, didRes: self.didResolver, activityLogger: activityLogger)
        newOIDCInteraction = Openid4ciNewInteraction(qrCodeData.requestURI, clientConfig, nil)
        do {
            let credentialRequest = Openid4ciNewCredentialRequestOpts( otp )
            let credResp  = try newOIDCInteraction?.requestCredential(credentialRequest, vm: didVerificationMethod)
            let credentialData = credResp?.atIndex(0)!;
            result(credentialData?.serialize(nil))
          } catch let error as NSError{
              result(FlutterError.init(code: "Exception",
                                       message: "error while requesting credential",
                                       details: error.description))
          }
        
    }
    
    /**
     * ResolveDisplay resolves display information for issued credentials based on an issuer's metadata, which is fetched
       using the issuer's (base) URI. The CredentialDisplays returns DisplayData object correspond to the VCs passed in and are in the
       same order. This method requires one or more VCs and the issuer's base URI.
       IssuerURI and array of credentials  are parsed using VcparseParse to be passed to Openid4ciResolveDisplay which returns the resolved Display Data
     */
    
    public func resolveCredentialDisplay(arguments: Dictionary<String, Any>, result: @escaping FlutterResult){
        do {
            guard let issuerURI = arguments["uri"] as? String else{
                return  result(FlutterError.init(code: "NATIVE_ERR",
                                                 message: "error while resolve credential display",
                                                 details: "parameter issuerURI is missed"))
            }

            guard let vcCredentials = arguments["vcCredentials"] as? Array<String> else{
                return  result(FlutterError.init(code: "NATIVE_ERR",
                                                 message: "error while resolve credential display",
                                                 details: "parameter storedcredentials is missed"))
            }

            let opts = VcparseNewOpts(true, nil)
            var parsedCredentials: ApiVerifiableCredentialsArray = ApiVerifiableCredentialsArray()!

            for cred in vcCredentials{
                let parsedVC = VcparseParse(cred, opts, nil)!
                parsedCredentials.add(parsedVC)
            }
            let resolvedDisplayData = Openid4ciResolveDisplay(parsedCredentials, issuerURI, nil, nil)
            let displayDataResp = resolvedDisplayData?.serialize(nil)
            result(displayDataResp)
          } catch let error as NSError {
                result(FlutterError.init(code: "Exception",
                                         message: "error while resolving credential",
                                         details: error.description))
            }
    }
    /**
     ApiParseActivity is invoked to parse the list of activities which are stored in the app when we issue and present credential,
     */
    public func parseActivities(arguments: Dictionary<String, Any>,result: @escaping FlutterResult){
        var activityList: [Any] = []
        guard let activities = arguments["activities"] as? Array<String> else{
            return  result(FlutterError.init(code: "NATIVE_ERR",
                                             message: "error while parsing activities",
                                             details: "parameter activities is missing"))
        }
                
        for activity in activities {
            let activityObj = ApiParseActivity(activity, nil)
            var status = activityObj!.status()
            var date = NSDate(timeIntervalSince1970: TimeInterval(activityObj!.unixTimestamp()))
            var utcDateFormatter = DateFormatter()
            utcDateFormatter.dateStyle = .long
            utcDateFormatter.timeStyle = .short
            let updatedDate = date
            var type = activityObj?.type()
            var activityDicResp:[String:Any] = [
                "Status":  status,
                "Issued By": activityObj?.client(),
                "Operation": activityObj?.operation(),
                "Activity Type": activityObj?.type(),
                "Date": utcDateFormatter.string(from: updatedDate as Date),
            ]
            activityList.append(activityDicResp)
        }
    

        result(activityList)
    }
    
    /**
     Local function to fetch all activities and send the serialized response to the app to be stored in the flutter secure storage.
     */
    public func storeActivityLogger(result: @escaping FlutterResult){
        var activityList: [Any] = []
        var aryLength = activityLogger!.length()
        for index in 0..<aryLength {
            activityList.append(activityLogger!.atIndex(index)!.serialize(nil))
        }

        result(activityList)
    }
    
    /**
     Local function  to get the credential IDs of the requested credentials.
     */
    public func getCredID(arguments: Dictionary<String, Any>, result: @escaping FlutterResult){
        
        guard let vcCredentials = arguments["vcCredentials"] as? Array<String> else{
            return  result(FlutterError.init(code: "NATIVE_ERR",
                                             message: "error while fetching credential ID",
                                             details: "parameter storedcredentials is missed"))
        }
        let opts = VcparseNewOpts(true, nil)
        var credIDs: [Any] = []

        for cred in vcCredentials{
            let parsedVC = VcparseParse(cred, opts, nil)!
            let credID = parsedVC.id_()
            print("credid -->", credID)
            credIDs.append(credID)
            
        }
        print("first credid -->", credIDs[0])
        result(credIDs[0])
    }
    
    /**
     * IssuerURI returns the issuer's URI from the initiation request. It's useful to store this somewhere in case
        there's a later need to refresh credential display data using the latest display information from the issuer.
     */
    public func issuerURI( result: @escaping FlutterResult){
        let issuerURIResp = newOIDCInteraction?.issuerURI();
        result(issuerURIResp)
    }

    
    public func fetchArgsKeyValue(_ call: FlutterMethodCall, key: String) -> String? {
        guard let args = call.arguments else {
            return ""
        }
        let myArgs = args as? [String: Any];
        return myArgs?[key] as? String;
    }

    //Define type method to access the new interaction further in the flow
    class OpenID
    {
        class func NewInteraction(requestURI: String, clientConfig: Openid4ciClientConfig) -> Openid4ciInteraction?
          {
              return Openid4ciNewInteraction(requestURI, clientConfig, nil)
          }
        

    }
}

