//
//  GitHub.swift
//	Perfect Authentication / Auth Providers
//  Inspired by Turnstile (Edward Jiang)
//
//  Created by Jonathan Guthrie on 2017-01-24
//
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import Foundation
import PerfectHTTP
import TurnstileCrypto
import PerfectSession

public struct GitHubConfig {
	public static var appid = ""
	public static var secret = ""

	/// Where should Facebook redirect to after Authorization
	public static var endpointAfterAuth = ""

	/// Where should the app redirect to after Authorization & Token Exchange
	public static var redirectAfterAuth = ""

	public init(){}
}

/**
Facebook allows you to authenticate against Facebook for login purposes.
*/
public class GitHub: OAuth2 {
	/**
	Create a Facebook object. Uses the Client ID and Client Secret from the
	Facebook Developers Console.
	*/
	public init(clientID: String, clientSecret: String) {
		let tokenURL = "https://github.com/login/oauth/access_token"
		let authorizationURL = URL(string: "https://github.com/login/oauth/authorize")!
		super.init(clientID: clientID, clientSecret: clientSecret, authorizationURL: authorizationURL, tokenURL: tokenURL)
	}


	private var appAccessToken: String {
		return clientID + "%7C" + clientSecret
	}


	public func getUserData(_ accessToken: String) -> [String: Any] {
		let url = "https://api.github.com/user?access_token=\(accessToken)"
		let (_, data, _, _) = makeRequest(.get, url)

		var out = [String: Any]()

		if let n = data["id"] {
			out["userid"] = "\(n)"
		}
		if let n = data["name"] {
			let nn = n as! String
			let nnn = nn.split(" ")
			if nnn.count > 0 {
				out["first_name"] = nnn.first
			}
			if nnn.count > 1 {
				out["last_name"] = nnn.last
			}
		}
		if let n = data["avatar_url"] {
			out["picture"] = n as! String
		}



		return out
		//return data
	}

	public func exchange(request: HTTPRequest, state: String) throws -> OAuth2Token {
		return try exchange(request: request, state: state, redirectURL: GitHubConfig.endpointAfterAuth)
	}

	public func getLoginLink(state: String, scopes: [String] = []) -> String {
		return getLoginLink(redirectURL: GitHubConfig.endpointAfterAuth, state: state, scopes: scopes)
	}


	// Could be improved, I'm sure...
	func dig(mineFor: [String], data: [String: Any]) -> Any {
		if mineFor.count == 0 { return "" }
		for (key,value) in data {
			if key == mineFor[0] {
				var newMine = mineFor
				newMine.removeFirst()
				if newMine.count == 0 {
					return value
				} else if value is [String: Any] {
					return dig(mineFor: newMine, data: value as! [String : Any])
				}
			}
		}
		return ""
	}


	public static func authResponse(data: [String:Any]) throws -> RequestHandler {
		return {
			request, response in
			let fb = GitHub(clientID: GitHubConfig.appid, clientSecret: GitHubConfig.secret)
			do {
				guard let state = request.session?.data["state"] else {
					throw OAuth2Error(code: .unsupportedResponseType)
				}
				let t = try fb.exchange(request: request, state: state as! String)
				request.session?.data["accessToken"] = t.accessToken

				let userdata = fb.getUserData(t.accessToken)

				request.session?.data["loginType"] = "github"


				if let i = userdata["userid"] {
					request.session?.userid = i as! String
				}
				if let i = userdata["first_name"] {
					request.session?.data["firstName"] = i as! String
				}
				if let i = userdata["last_name"] {
					request.session?.data["lastName"] = i as! String
				}
				if let i = userdata["picture"] {
					request.session?.data["picture"] = i as! String
				}

			} catch {
				print(error)
			}
			response.redirect(path: GitHubConfig.redirectAfterAuth)
		}
	}





	public static func sendToProvider(data: [String:Any]) throws -> RequestHandler {
		let rand = URandom()

		return {
			request, response in
			// Add secure state token to session
			// We expect to get this back from the auth
			request.session?.data["state"] = rand.secureToken
			let tw = GitHub(clientID: GitHubConfig.appid, clientSecret: GitHubConfig.secret)
			print(tw.getLoginLink(state: request.session?.data["state"] as! String, scopes: ["user"]))
			response.redirect(path: tw.getLoginLink(state: request.session?.data["state"] as! String, scopes: ["user"]))
		}
	}


}
