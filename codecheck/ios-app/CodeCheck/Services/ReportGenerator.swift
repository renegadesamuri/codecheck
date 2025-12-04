import Foundation
import PDFKit
import UIKit

@MainActor
class ReportGenerator {

    // Generate a professional PDF report for a project
    static func generateProjectReport(
        project: Project,
        measurements: [Measurement],
        photos: [PhotoDocumentation],
        user: User?
    ) -> URL? {
        let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        let renderer = UIGraphicsPDFRenderer(bounds: pageSize)

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "CodeCheck_\(project.name.replacingOccurrences(of: " ", with: "_"))_\(Date().formatted(date: .numeric, time: .omitted)).pdf"
        let fileURL = documentsPath.appendingPathComponent(fileName)

        do {
            try renderer.writePDF(to: fileURL) { context in
                // Page 1: Cover Page
                drawCoverPage(context: context, pageSize: pageSize, project: project, user: user)

                // Page 2: Executive Summary
                context.beginPage()
                drawExecutiveSummary(context: context, pageSize: pageSize, project: project, measurements: measurements)

                // Page 3+: Measurements Detail
                for (index, measurement) in measurements.enumerated() {
                    if index > 0 && index % 3 == 0 {
                        context.beginPage()
                    }
                    let yOffset = CGFloat((index % 3) * 240) + 80
                    drawMeasurementDetail(context: context, pageSize: pageSize, measurement: measurement, yOffset: yOffset)
                }

                // Last Pages: Photos
                if !photos.isEmpty {
                    context.beginPage()
                    drawPhotoGallery(context: context, pageSize: pageSize, photos: photos)
                }
            }

            return fileURL
        } catch {
            print("Error generating PDF: \(error)")
            return nil
        }
    }

    // MARK: - Cover Page
    private static func drawCoverPage(context: UIGraphicsPDFRendererContext, pageSize: CGRect, project: Project, user: User?) {
        let cgContext = context.cgContext

        // Background gradient
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0).cgColor,
            UIColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 1.0).cgColor
        ]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0])!

        cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: pageSize.width, y: pageSize.height), options: [])

        // App Logo/Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let title = "CodeCheck"
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: CGPoint(x: (pageSize.width - titleSize.width) / 2, y: 150), withAttributes: titleAttributes)

        // Subtitle
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        let subtitle = "Construction Compliance Report"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        subtitle.draw(at: CGPoint(x: (pageSize.width - subtitleSize.width) / 2, y: 210), withAttributes: subtitleAttributes)

        // Project Name
        let projectNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let projectNameSize = project.name.size(withAttributes: projectNameAttributes)
        project.name.draw(at: CGPoint(x: (pageSize.width - projectNameSize.width) / 2, y: 350), withAttributes: projectNameAttributes)

        // Project Details Box
        cgContext.setFillColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        cgContext.fill(CGRect(x: 100, y: 450, width: pageSize.width - 200, height: 200))

        let detailsAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.white
        ]

        var yPosition: CGFloat = 475

        "Type: \(project.type.rawValue)".draw(at: CGPoint(x: 120, y: yPosition), withAttributes: detailsAttributes)
        yPosition += 25

        "Location: \(project.location)".draw(at: CGPoint(x: 120, y: yPosition), withAttributes: detailsAttributes)
        yPosition += 25

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        "Date: \(dateFormatter.string(from: project.createdAt))".draw(at: CGPoint(x: 120, y: yPosition), withAttributes: detailsAttributes)
        yPosition += 25

        if let user = user {
            "Inspector: \(user.name ?? user.email)".draw(at: CGPoint(x: 120, y: yPosition), withAttributes: detailsAttributes)
        }

        // Footer
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(0.7)
        ]
        let footer = "Generated by CodeCheck • \(Date().formatted(date: .long, time: .shortened))"
        let footerSize = footer.size(withAttributes: footerAttributes)
        footer.draw(at: CGPoint(x: (pageSize.width - footerSize.width) / 2, y: pageSize.height - 50), withAttributes: footerAttributes)
    }

    // MARK: - Executive Summary
    private static func drawExecutiveSummary(context: UIGraphicsPDFRendererContext, pageSize: CGRect, project: Project, measurements: [Measurement]) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        "Executive Summary".draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        var yPosition: CGFloat = 100

        // Summary Stats
        let compliantCount = measurements.filter { $0.isCompliant == true }.count
        let totalCount = measurements.count
        let complianceRate = totalCount > 0 ? (Double(compliantCount) / Double(totalCount)) * 100 : 0

        let statsBox = CGRect(x: 50, y: yPosition, width: pageSize.width - 100, height: 120)
        context.cgContext.setFillColor(UIColor.systemGray6.cgColor)
        context.cgContext.fill(statsBox)

        yPosition += 20

        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.black
        ]

        "Total Measurements: \(totalCount)".draw(at: CGPoint(x: 70, y: yPosition), withAttributes: headingAttributes)
        yPosition += 25

        "Compliant: \(compliantCount)".draw(at: CGPoint(x: 70, y: yPosition), withAttributes: bodyAttributes)
        yPosition += 20

        let complianceColor = complianceRate >= 90 ? UIColor.systemGreen : (complianceRate >= 70 ? UIColor.systemOrange : UIColor.systemRed)
        context.cgContext.setFillColor(complianceColor.cgColor)
        "Compliance Rate: \(String(format: "%.1f%%", complianceRate))".draw(at: CGPoint(x: 70, y: yPosition), withAttributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: complianceColor
        ])

        yPosition += 60

        // Measurement Breakdown
        "Measurement Breakdown".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: titleAttributes)
        yPosition += 40

        let measurementTypes = Dictionary(grouping: measurements, by: { $0.type })
        for (type, typeMeasurements) in measurementTypes {
            let typeCompliant = typeMeasurements.filter { $0.isCompliant == true }.count
            "\(type.rawValue): \(typeCompliant)/\(typeMeasurements.count) compliant".draw(at: CGPoint(x: 70, y: yPosition), withAttributes: bodyAttributes)
            yPosition += 20
        }
    }

    // MARK: - Measurement Detail
    private static func drawMeasurementDetail(context: UIGraphicsPDFRendererContext, pageSize: CGRect, measurement: Measurement, yOffset: CGFloat) {
        let boxRect = CGRect(x: 50, y: yOffset, width: pageSize.width - 100, height: 200)

        // Background
        context.cgContext.setFillColor(UIColor.systemGray6.cgColor)
        context.cgContext.fill(boxRect)

        // Border color based on compliance
        let borderColor = measurement.isCompliant == true ? UIColor.systemGreen : UIColor.systemRed
        context.cgContext.setStrokeColor(borderColor.cgColor)
        context.cgContext.setLineWidth(3)
        context.cgContext.stroke(boxRect)

        var yPos = yOffset + 20

        // Type
        let typeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        measurement.type.rawValue.draw(at: CGPoint(x: 70, y: yPos), withAttributes: typeAttributes)
        yPos += 30

        // Value
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
            .foregroundColor: borderColor
        ]
        let valueString = String(format: "%.2f %@", measurement.value, measurement.unit.rawValue)
        valueString.draw(at: CGPoint(x: 70, y: yPos), withAttributes: valueAttributes)
        yPos += 40

        // Status
        let statusAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: borderColor
        ]
        let status = measurement.isCompliant == true ? "✓ COMPLIANT" : "✗ NON-COMPLIANT"
        status.draw(at: CGPoint(x: 70, y: yPos), withAttributes: statusAttributes)
        yPos += 25

        // Notes
        if let notes = measurement.notes, !notes.isEmpty {
            let notesAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            "Notes: \(notes)".draw(at: CGPoint(x: 70, y: yPos), withAttributes: notesAttributes)
        }

        // Date
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.gray
        ]
        let dateString = measurement.takenAt.formatted(date: .abbreviated, time: .shortened)
        dateString.draw(at: CGPoint(x: 70, y: yOffset + 170), withAttributes: dateAttributes)
    }

    // MARK: - Photo Gallery
    private static func drawPhotoGallery(context: UIGraphicsPDFRendererContext, pageSize: CGRect, photos: [PhotoDocumentation]) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        "Photo Documentation".draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)

        var yPosition: CGFloat = 100

        for (index, photo) in photos.enumerated() {
            if index > 0 && index % 2 == 0 {
                context.beginPage()
                yPosition = 50
            }

            if let image = photo.image {
                // Draw image
                let imageHeight: CGFloat = 250
                let imageWidth = pageSize.width - 100
                let imageRect = CGRect(x: 50, y: yPosition, width: imageWidth, height: imageHeight)
                image.draw(in: imageRect)

                yPosition += imageHeight + 10

                // Location
                let locationAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.black
                ]
                photo.location.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: locationAttributes)
                yPosition += 20

                // Notes
                if !photo.notes.isEmpty {
                    let notesAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                        .foregroundColor: UIColor.darkGray
                    ]
                    photo.notes.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: notesAttributes)
                    yPosition += 15
                }

                // Tags
                if !photo.tags.isEmpty {
                    let tagsAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                        .foregroundColor: UIColor.systemBlue
                    ]
                    "Tags: \(photo.tags.joined(separator: ", "))".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: tagsAttributes)
                }

                yPosition += 40
            }
        }
    }
}
