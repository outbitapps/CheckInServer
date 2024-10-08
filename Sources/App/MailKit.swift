//
//  File.swift
//  
//
//  Created by Payton Curry on 5/9/24.
//

import Foundation

struct MailerMail: Codable {
    var from: MailerUser
    var to: [MailerUser]
    var personalization: MailerPersonalization
    var template_id: String
    var subject: String
}
struct MailerPersonalization: Codable {
    var email: String
    var data: String
}
struct MailerUser: Codable {
    public var email: String
}

