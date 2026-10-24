import UIKit
import Estimator

/// Everything printed on a quote, decoupled from SwiftData so it can be rendered and tested on its own.
struct QuoteDocument: Equatable {
    struct Line: Equatable {
        var description: String
        var amount: String
    }

    var businessName: String
    var businessDetails: [String]
    var logoPNG: Data?
    var title: String
    var number: String
    var date: String
    var clientName: String?
    var clientDetails: [String]
    var jobSummary: String?
    var lines: [Line]
    var subtotal: Line?
    var vat: Line?
    var total: Line
    var validity: String?
    var terms: String?
}

extension QuoteDocument {
    @MainActor
    init(quote: Quote, profile: BusinessProfile?, formatters f: Formatters, locale: Locale = .current) throws {
        let totals = try quote.totals()
        let hasName = !(profile?.name.isEmpty ?? true)
        businessName = hasName ? profile!.name : String(localized: "Quote")
        businessDetails = [profile?.address ?? "", profile?.phone ?? "", profile?.email ?? "",
                           profile.map { $0.vatNumber.isEmpty ? "" : String(localized: "VAT no. \($0.vatNumber)") } ?? ""]
            .flatMap { $0.split(separator: "\n").map(String.init) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        logoPNG = profile?.logo
        title = String(localized: "QUOTE")
        number = quote.displayNumber
        date = (quote.sentAt ?? quote.createdAt).formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
        clientName = quote.client?.name
        clientDetails = [quote.client?.address ?? "", quote.client?.phone ?? "", quote.client?.email ?? ""]
            .filter { !$0.isEmpty }
        jobSummary = QuoteText.jobSummary(quote: quote, formatters: f)
        // The PDF shows cents so every line adds up exactly to the total.
        lines = quote.sortedLineItems.map { Line(description: $0.summary, amount: f.money($0.total, fractionDigits: 2)) }
        if quote.vatEnabled {
            subtotal = Line(description: String(localized: "Subtotal"), amount: f.money(totals.subtotal, fractionDigits: 2))
            vat = Line(description: String(localized: "VAT \(DecimalInput.string(quote.vatRatePercent))%"), amount: f.money(totals.vat, fractionDigits: 2))
        }
        total = Line(description: String(localized: "Total"), amount: f.money(totals.total, fractionDigits: 2))
        validity = QuoteText.validityText(quote: quote)
        let termsText = profile?.terms.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        terms = termsText.isEmpty ? nil : termsText
    }

    var fileName: String {
        let safeNumber = number.replacingOccurrences(of: "#", with: "")
        let client = (clientName ?? "").components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        return client.isEmpty ? "Quote-\(safeNumber).pdf" : "Quote-\(safeNumber)-\(client).pdf"
    }
}

/// Draws a quote as an A4 PDF with Core Graphics. Long quotes continue onto extra pages.
enum QuotePDFRenderer {
    static let pageSize = CGSize(width: 595.28, height: 841.89) // A4 in points
    static let margin: CGFloat = 48

    static func render(_ document: QuoteDocument, accent: UIColor = UIColor(hex: 0xC2410C)) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "\(document.title) \(document.number)",
            kCGPDFContextCreator as String: "RoomQuote"
        ]
        let bounds = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        return renderer.pdfData { context in
            var layout = Layout(context: context, accent: accent)
            layout.newPage()
            layout.drawHeader(document)
            layout.drawParties(document)
            layout.drawLines(document)
            layout.drawFooter(document)
        }
    }

    private struct Layout {
        let context: UIGraphicsPDFRendererContext
        let accent: UIColor
        var y: CGFloat = 0
        var width: CGFloat { pageSize.width - 2 * margin }
        let primary = UIColor(hex: 0x15181D)
        let secondary = UIColor(hex: 0x4B5563)
        let rule = UIColor(hex: 0xE6E8EC)

        init(context: UIGraphicsPDFRendererContext, accent: UIColor) {
            self.context = context
            self.accent = accent
        }

        mutating func newPage() {
            context.beginPage()
            y = margin
        }

        /// Starts a new page if `height` won't fit above the bottom margin.
        mutating func ensureSpace(_ height: CGFloat) {
            if y + height > pageSize.height - margin { newPage() }
        }

        func font(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont { .systemFont(ofSize: size, weight: weight) }

        func attributes(_ size: CGFloat, _ weight: UIFont.Weight, _ color: UIColor, align: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = align
            paragraph.lineBreakMode = .byWordWrapping
            return [.font: font(size, weight), .foregroundColor: color, .paragraphStyle: paragraph]
        }

        /// Draws wrapped text and returns its height.
        @discardableResult
        func draw(_ text: String, at origin: CGPoint, width: CGFloat, _ attrs: [NSAttributedString.Key: Any]) -> CGFloat {
            let string = NSAttributedString(string: text, attributes: attrs)
            let rect = string.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                           options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            string.draw(with: CGRect(origin: origin, size: CGSize(width: width, height: ceil(rect.height))),
                        options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            return ceil(rect.height)
        }

        func height(of text: String, width: CGFloat, _ attrs: [NSAttributedString.Key: Any]) -> CGFloat {
            ceil(NSAttributedString(string: text, attributes: attrs)
                .boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                              options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
        }

        func line(atY lineY: CGFloat, color: UIColor, thickness: CGFloat = 1) {
            color.setFill()
            UIRectFill(CGRect(x: margin, y: lineY, width: width, height: thickness))
        }

        mutating func drawHeader(_ doc: QuoteDocument) {
            var textX = margin
            let logoSide: CGFloat = 56
            if let data = doc.logoPNG, let logo = UIImage(data: data) {
                let scale = min(logoSide / logo.size.width, logoSide / logo.size.height)
                let size = CGSize(width: logo.size.width * scale, height: logo.size.height * scale)
                logo.draw(in: CGRect(origin: CGPoint(x: margin, y: y), size: size))
                textX += logoSide + 14
            }
            let rightWidth: CGFloat = 160
            let leftWidth = width - (textX - margin) - rightWidth - 12
            var leftY = y
            leftY += draw(doc.businessName, at: CGPoint(x: textX, y: leftY), width: leftWidth, attributes(18, .heavy, primary))
            for detail in doc.businessDetails {
                leftY += draw(detail, at: CGPoint(x: textX, y: leftY + 2), width: leftWidth, attributes(9.5, .medium, secondary)) + 2
            }
            let rightX = margin + width - rightWidth
            var rightY = y
            rightY += draw(doc.title, at: CGPoint(x: rightX, y: rightY), width: rightWidth, attributes(22, .heavy, accent, align: .right))
            rightY += draw(doc.number, at: CGPoint(x: rightX, y: rightY + 2), width: rightWidth, attributes(11, .bold, primary, align: .right)) + 2
            rightY += draw(doc.date, at: CGPoint(x: rightX, y: rightY + 2), width: rightWidth, attributes(10, .medium, secondary, align: .right)) + 2
            y = max(leftY, rightY, doc.logoPNG == nil ? y : y + logoSide) + 24
        }

        mutating func drawParties(_ doc: QuoteDocument) {
            var rows: [(String, String)] = []
            if let client = doc.clientName {
                rows.append((String(localized: "For"), ([client] + doc.clientDetails).joined(separator: "\n")))
            }
            if let job = doc.jobSummary { rows.append((String(localized: "Job"), job)) }
            guard !rows.isEmpty else { return }
            let labelWidth: CGFloat = 48
            let valueWidth = width - labelWidth - 24
            let contentHeight = rows.reduce(CGFloat(0)) { $0 + height(of: $1.1, width: valueWidth, attributes(10.5, .medium, primary)) + 6 }
            let box = CGRect(x: margin, y: y, width: width, height: contentHeight + 18)
            UIColor(hex: 0xF4F5F7).setFill()
            UIBezierPath(roundedRect: box, cornerRadius: 6).fill()
            var rowY = y + 12
            for (label, value) in rows {
                draw(label, at: CGPoint(x: margin + 12, y: rowY), width: labelWidth, attributes(10.5, .heavy, primary))
                rowY += draw(value, at: CGPoint(x: margin + 12 + labelWidth, y: rowY), width: valueWidth, attributes(10.5, .medium, primary)) + 6
            }
            y = box.maxY + 24
        }

        mutating func drawLines(_ doc: QuoteDocument) {
            let amountWidth: CGFloat = 120
            let descriptionWidth = width - amountWidth - 12
            drawTableHeader(descriptionWidth: descriptionWidth, amountWidth: amountWidth)
            for item in doc.lines {
                let rowHeight = height(of: item.description, width: descriptionWidth, attributes(10.5, .medium, primary)) + 14
                if y + rowHeight > pageSize.height - margin - 40 {
                    newPage()
                    drawTableHeader(descriptionWidth: descriptionWidth, amountWidth: amountWidth)
                }
                draw(item.description, at: CGPoint(x: margin, y: y + 7), width: descriptionWidth, attributes(10.5, .medium, primary))
                draw(item.amount, at: CGPoint(x: margin + width - amountWidth, y: y + 7), width: amountWidth, attributes(10.5, .semibold, primary, align: .right))
                y += rowHeight
                line(atY: y, color: rule)
            }
            for extra in [doc.subtotal, doc.vat].compactMap({ $0 }) {
                ensureSpace(24)
                draw(extra.description, at: CGPoint(x: margin, y: y + 7), width: descriptionWidth, attributes(10.5, .medium, secondary))
                draw(extra.amount, at: CGPoint(x: margin + width - amountWidth, y: y + 7), width: amountWidth, attributes(10.5, .semibold, primary, align: .right))
                y += 24
            }
            ensureSpace(40)
            y += 6
            line(atY: y, color: primary, thickness: 2)
            y += 10
            draw(doc.total.description, at: CGPoint(x: margin, y: y), width: descriptionWidth, attributes(15, .heavy, primary))
            draw(doc.total.amount, at: CGPoint(x: margin + width - amountWidth - 60, y: y), width: amountWidth + 60, attributes(15, .heavy, primary, align: .right))
            y += 34
        }

        mutating func drawTableHeader(descriptionWidth: CGFloat, amountWidth: CGFloat) {
            draw(String(localized: "Item"), at: CGPoint(x: margin, y: y), width: descriptionWidth, attributes(9.5, .bold, secondary))
            draw(String(localized: "Amount"), at: CGPoint(x: margin + width - amountWidth, y: y), width: amountWidth, attributes(9.5, .bold, secondary, align: .right))
            y += 18
            line(atY: y, color: rule)
        }

        mutating func drawFooter(_ doc: QuoteDocument) {
            let text = [doc.validity, doc.terms].compactMap { $0 }.joined(separator: "\n")
            guard !text.isEmpty else { return }
            let attrs = attributes(9.5, .medium, secondary)
            let textHeight = height(of: text, width: width, attrs)
            ensureSpace(textHeight)
            draw(text, at: CGPoint(x: margin, y: y), width: width, attrs)
            y += textHeight
        }
    }
}
