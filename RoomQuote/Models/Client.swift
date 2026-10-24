import Foundation
import SwiftData

@Model
final class Client {
    var name: String = ""
    var phone: String = ""
    var email: String = ""
    var address: String = ""
    var notes: String = ""
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Quote.client)
    var quotes: [Quote]? = []

    init(name: String, phone: String = "", email: String = "", address: String = "") {
        self.name = name
        self.phone = phone
        self.email = email
        self.address = address
    }
}
