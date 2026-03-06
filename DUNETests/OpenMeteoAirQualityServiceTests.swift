import CoreLocation
import Foundation
import Testing
@testable import DUNE

@Suite("OpenMeteoAirQualityService")
struct OpenMeteoAirQualityServiceTests {
    private let responseJSON = """
    {
        "current": {
            "pm10": 25.5,
            "pm2_5": 12.3,
            "us_aqi": 52,
            "european_aqi": 35,
            "ozone": 45.0,
            "nitrogen_dioxide": 18.5,
            "sulphur_dioxide": 3.2,
            "carbon_monoxide": 220.0
        },
        "hourly": {
            "time": ["2026-03-01T12:00", "2026-03-01T13:00"],
            "pm10": [25.5, 30.0],
            "pm2_5": [12.3, 15.0],
            "us_aqi": [52, 60]
        }
    }
    """

    // MARK: - JSON Decoding

    @Test("Decodes valid air quality response")
    func decodeValidResponse() throws {
        let data = responseJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(AirQualityResponse.self, from: data)

        #expect(response.current.pm2_5 == 12.3)
        #expect(response.current.pm10 == 25.5)
        #expect(response.current.us_aqi == 52)
        #expect(response.current.european_aqi == 35)
        #expect(response.current.ozone == 45.0)
        #expect(response.current.nitrogen_dioxide == 18.5)
        #expect(response.current.sulphur_dioxide == 3.2)
        #expect(response.current.carbon_monoxide == 220.0)

        #expect(response.hourly?.time.count == 2)
        #expect(response.hourly?.pm2_5.count == 2)
        #expect(response.hourly?.pm10.count == 2)
        #expect(response.hourly?.us_aqi.count == 2)
    }

    @Test("Decodes response without hourly data")
    func decodeWithoutHourly() throws {
        let json = """
        {
            "current": {
                "pm10": 20.0,
                "pm2_5": 10.0,
                "us_aqi": 40,
                "european_aqi": 25
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(AirQualityResponse.self, from: data)

        #expect(response.current.pm2_5 == 10.0)
        #expect(response.hourly == nil)
        #expect(response.current.ozone == nil)
        #expect(response.current.nitrogen_dioxide == nil)
    }

    @Test("Decodes response without optional pollutants")
    func decodeWithoutPollutants() throws {
        let json = """
        {
            "current": {
                "pm10": 30.0,
                "pm2_5": 20.0,
                "us_aqi": 65,
                "european_aqi": 45
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(AirQualityResponse.self, from: data)

        #expect(response.current.ozone == nil)
        #expect(response.current.sulphur_dioxide == nil)
        #expect(response.current.carbon_monoxide == nil)
    }

    // MARK: - OpenMeteoAirQualityError

    @Test("Error cases are distinct")
    func errorCases() {
        let invalid = OpenMeteoAirQualityError.invalidResponse
        let http = OpenMeteoAirQualityError.httpError(429)
        let url = OpenMeteoAirQualityError.invalidURL

        #expect(invalid.localizedDescription.isEmpty == false)
        if case .httpError(let code) = http {
            #expect(code == 429)
        } else {
            Issue.record("Expected httpError case")
        }
        if case .invalidURL = url {
            // pass
        } else {
            Issue.record("Expected invalidURL case")
        }
    }

    @Test("Air quality cache hit is scoped to normalized request location")
    func cacheScopedToNormalizedLocation() async throws {
        let session = URLSession.stubbedSession()
        let service = OpenMeteoAirQualityService(session: session)
        let lock = NSLock()
        var requestedURLs: [URL] = []
        let data = try #require(responseJSON.data(using: .utf8))

        URLProtocolStub.setHandler { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }
            lock.withLock {
                requestedURLs.append(url)
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }
        defer { URLProtocolStub.reset() }

        let seoul = CLLocation(latitude: 37.5665, longitude: 126.9780)
        let nearbySameRoundedCell = CLLocation(latitude: 37.5664, longitude: 126.9783)
        let busan = CLLocation(latitude: 35.1796, longitude: 129.0756)

        _ = try await service.fetchAirQuality(for: seoul)
        _ = try await service.fetchAirQuality(for: nearbySameRoundedCell)
        _ = try await service.fetchAirQuality(for: busan)

        let calls = lock.withLock { requestedURLs }
        #expect(calls.count == 2)
        guard calls.count == 2 else { return }
        #expect(calls[0].query?.contains("latitude=37.57") == true)
        #expect(calls[0].query?.contains("longitude=126.98") == true)
        #expect(calls[1].query?.contains("latitude=35.18") == true)
        #expect(calls[1].query?.contains("longitude=129.08") == true)
    }
}
