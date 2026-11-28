import UIKit
import UniformTypeIdentifiers
import Testing
@testable import DUNE

@Suite("Posture display transfer")
@MainActor
struct PostureDisplayTransferTests {
    @Test("Files receives the original photo bytes and matching image type")
    func exportsOnlyOriginalImage() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        let photo = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let png = try #require(photo.pngData())
        let jpeg = try #require(photo.jpegData(compressionQuality: 0.8))
        for (bytes, type) in [(png, UTType.png), (jpeg, UTType.jpeg)] {
            let document = try #require(PosturePhotoDocument(bytes: bytes))
            #expect(document.contentType == type)
            #expect(document.bytes == bytes)
        }
        #expect(PosturePhotoDocument(bytes: Data("fixture note".utf8)) == nil)
    }

    @Test("A cancelled countdown cannot reset a new display's countdown")
    func staleCountdown() async {
        let model = PostureAssessmentViewModel()
        model.capturePhase = .preparing
        model.startCountdown()
        await Task.yield()
        model.stopCamera()
        model.startCountdown()
        for _ in 0..<5 { await Task.yield() }
        #expect(model.capturePhase == .countdown(3))
        model.stopCamera()
    }

    @Test("An interrupted countdown returns to preparation")
    func interruptedCountdown() {
        let model = PostureAssessmentViewModel()
        model.capturePhase = .countdown(2)
        model.stopCamera()
        #expect(model.capturePhase == .preparing)
    }

    @Test("An interrupted capture returns to preparation without error feedback")
    func interruptedCapture() {
        let model = PostureAssessmentViewModel()
        model.capturePhase = .capturing
        model.stopCamera()
        #expect(model.capturePhase == .preparing)
        #expect(model.hapticErrorCount == 0)
    }

    @Test("Stopping preview preserves an assessment result and memo")
    func preserveResult() {
        let model = PostureAssessmentViewModel()
        model.capturePhase = .result
        model.memo = "assessment note"
        model.stopCamera()
        #expect(model.capturePhase == .result)
        #expect(model.memo == "assessment note")
    }
}

#if targetEnvironment(simulator) && os(iOS)
import SwiftData
import SwiftUI
import XCTest

@MainActor
final class PosturePhotoPresentationTests: XCTestCase {
    func testOriginalPhotoActionsInAssessmentDetail() async throws {
        let schema = Schema([PostureAssessmentRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        func sample(_ symbol: String) throws -> Data {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 90, height: 90))
            let icon = try XCTUnwrap(UIImage(systemName: symbol))
            return renderer.pngData { _ in
                UIColor.secondarySystemBackground.setFill()
                UIRectFill(CGRect(x: 0, y: 0, width: 90, height: 90))
                icon.draw(in: CGRect(x: 24, y: 12, width: 42, height: 66))
            }
        }
        let record = try PostureAssessmentRecord(date: Date(timeIntervalSince1970: 1_700_000_000), overallScore: 75,
                                                frontImageData: sample("figure.stand"), sideImageData: sample("figure.walk"))
        container.mainContext.insert(record)
        try container.mainContext.save()

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        defer {
            window.isHidden = true
            previous?.makeKey()
        }
        let screen = NavigationStack { PostureDetailView(record: record) }.modelContainer(container)
        window.rootViewController = UIHostingController(rootView: screen)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        await Task.yield()
        window.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "H07-original-photo-actions"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
