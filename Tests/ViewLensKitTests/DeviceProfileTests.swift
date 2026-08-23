import Testing
import CoreGraphics
@testable import ViewLensKit

@Suite("DeviceProfile Specifications Tests")
struct DeviceProfileTests {
    @Test("iPhone 16 Pro metrics match hardware standards")
    func testiPhone16ProMetrics() {
        let profile = DeviceProfile.iPhone16Pro
        #expect(profile.pointWidth == 393)
        #expect(profile.pointHeight == 852)
        #expect(profile.scale == 3.0)
        #expect(profile.pixelWidth == 1179)
        #expect(profile.pixelHeight == 2556)
        #expect(profile.safeAreaInsets.top == 59)
        #expect(profile.safeAreaInsets.bottom == 34)
    }

    @Test("iPhone SE 3rd gen metrics match hardware standards")
    func testiPhoneSEMetrics() {
        let profile = DeviceProfile.iPhoneSE
        #expect(profile.pointWidth == 375)
        #expect(profile.pointHeight == 667)
        #expect(profile.scale == 2.0)
        #expect(profile.pixelWidth == 750)
        #expect(profile.pixelHeight == 1334)
        #expect(profile.safeAreaInsets.top == 20)
        #expect(profile.safeAreaInsets.bottom == 0)
    }

    @Test("Lookup by string query")
    func testNamedLookup() {
        #expect(DeviceProfile.named("iPhone16Pro")?.id == "iPhone16Pro")
        #expect(DeviceProfile.named("iphone se")?.id == "iPhoneSE")
        #expect(DeviceProfile.named("iPadPro11")?.id == "iPadPro11")
    }
}
