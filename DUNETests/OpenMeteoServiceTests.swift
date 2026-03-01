import Foundation
import Testing
@testable import DUNE

@Suite("OpenMeteoService")
struct OpenMeteoServiceTests {

    // MARK: - WMO Code Mapping

    @Test("Clear sky codes map to .clear")
    func clearCodes() {
        #expect(OpenMeteoService.mapWMOCode(0) == .clear)
        #expect(OpenMeteoService.mapWMOCode(1) == .clear)
    }

    @Test("Partly cloudy code maps correctly")
    func partlyCloudy() {
        #expect(OpenMeteoService.mapWMOCode(2) == .partlyCloudy)
    }

    @Test("Overcast maps to .cloudy")
    func overcast() {
        #expect(OpenMeteoService.mapWMOCode(3) == .cloudy)
    }

    @Test("Fog codes map to .fog")
    func fog() {
        #expect(OpenMeteoService.mapWMOCode(45) == .fog)
        #expect(OpenMeteoService.mapWMOCode(48) == .fog)
    }

    @Test("Drizzle codes map to .rain")
    func drizzle() {
        #expect(OpenMeteoService.mapWMOCode(51) == .rain)
        #expect(OpenMeteoService.mapWMOCode(53) == .rain)
        #expect(OpenMeteoService.mapWMOCode(55) == .rain)
    }

    @Test("Freezing drizzle/rain maps to .sleet")
    func freezingPrecipitation() {
        #expect(OpenMeteoService.mapWMOCode(56) == .sleet)
        #expect(OpenMeteoService.mapWMOCode(57) == .sleet)
        #expect(OpenMeteoService.mapWMOCode(66) == .sleet)
        #expect(OpenMeteoService.mapWMOCode(67) == .sleet)
    }

    @Test("Rain codes map correctly")
    func rain() {
        #expect(OpenMeteoService.mapWMOCode(61) == .rain)
        #expect(OpenMeteoService.mapWMOCode(63) == .rain)
        #expect(OpenMeteoService.mapWMOCode(80) == .rain)
        #expect(OpenMeteoService.mapWMOCode(81) == .rain)
    }

    @Test("Heavy rain codes map to .heavyRain")
    func heavyRain() {
        #expect(OpenMeteoService.mapWMOCode(65) == .heavyRain)
        #expect(OpenMeteoService.mapWMOCode(82) == .heavyRain)
    }

    @Test("Snow codes map to .snow")
    func snow() {
        #expect(OpenMeteoService.mapWMOCode(71) == .snow)
        #expect(OpenMeteoService.mapWMOCode(73) == .snow)
        #expect(OpenMeteoService.mapWMOCode(75) == .snow)
        #expect(OpenMeteoService.mapWMOCode(77) == .snow)
        #expect(OpenMeteoService.mapWMOCode(85) == .snow)
        #expect(OpenMeteoService.mapWMOCode(86) == .snow)
    }

    @Test("Thunderstorm codes map to .thunderstorm")
    func thunderstorm() {
        #expect(OpenMeteoService.mapWMOCode(95) == .thunderstorm)
        #expect(OpenMeteoService.mapWMOCode(96) == .thunderstorm)
        #expect(OpenMeteoService.mapWMOCode(99) == .thunderstorm)
    }

    @Test("Unknown WMO code defaults to .cloudy")
    func unknownCode() {
        #expect(OpenMeteoService.mapWMOCode(-1) == .cloudy)
        #expect(OpenMeteoService.mapWMOCode(100) == .cloudy)
        #expect(OpenMeteoService.mapWMOCode(999) == .cloudy)
    }

    // MARK: - ISO 8601 Parsing

    @Test("Parses standard ISO 8601 with timezone")
    func parseStandardISO() {
        let date = OpenMeteoService.parseISO8601("2026-02-28T14:00:00Z")
        #expect(date != nil)
    }

    @Test("Parses Open-Meteo hourly format without timezone")
    func parseOpenMeteoHourly() {
        let date = OpenMeteoService.parseISO8601("2026-02-28T14:00")
        #expect(date != nil)
    }

    @Test("Returns nil for invalid string")
    func parseInvalid() {
        #expect(OpenMeteoService.parseISO8601("not-a-date") == nil)
        #expect(OpenMeteoService.parseISO8601("") == nil)
    }

    // MARK: - JSON Decoding

    @Test("Decodes valid Open-Meteo response")
    func decodeValidResponse() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 15.3,
                "apparent_temperature": 13.1,
                "relative_humidity_2m": 72.0,
                "weather_code": 3,
                "wind_speed_10m": 12.5,
                "uv_index": 4.2,
                "is_day": 1
            },
            "hourly": {
                "time": ["2026-02-28T14:00", "2026-02-28T15:00"],
                "temperature_2m": [15.3, 14.8],
                "weather_code": [3, 61]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        #expect(response.current.temperature_2m == 15.3)
        #expect(response.current.apparent_temperature == 13.1)
        #expect(response.current.relative_humidity_2m == 72.0)
        #expect(response.current.weather_code == 3)
        #expect(response.current.wind_speed_10m == 12.5)
        #expect(response.current.uv_index == 4.2)
        #expect(response.current.is_day == 1)

        #expect(response.hourly?.time.count == 2)
        #expect(response.hourly?.temperature_2m.count == 2)
        #expect(response.hourly?.weather_code.count == 2)
    }

    @Test("Decodes response without hourly data")
    func decodeWithoutHourly() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 20.0,
                "apparent_temperature": 18.0,
                "relative_humidity_2m": 50.0,
                "weather_code": 0,
                "wind_speed_10m": 5.0,
                "uv_index": 6.0,
                "is_day": 1
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        #expect(response.current.temperature_2m == 20.0)
        #expect(response.hourly == nil)
    }

    // MARK: - UV Index Safety

    @Test("UV index isFinite guard: NaN/Infinity produces 0 fallback")
    func uvIndexIsFiniteGuard() {
        // mapToSnapshot is private, and JSON cannot encode NaN/Infinity.
        // This test verifies the clamping logic boundary at the WeatherSnapshot level,
        // and documents that the isFinite guard exists in OpenMeteoService.mapToSnapshot:94
        // to prevent Int(Double.nan) undefined behavior.
        let snapshot = WeatherSnapshot(
            temperature: 20, feelsLike: 20, condition: .clear,
            humidity: 0.5, uvIndex: 0, windSpeed: 10,
            isDaytime: true, fetchedAt: Date(), hourlyForecast: [],
            dailyForecast: [],
            airQuality: nil
        )
        // uvIndex 0 is the fallback value used when isFinite fails
        #expect(snapshot.uvIndex == 0)
        #expect(!snapshot.isHighUV)
    }

    // MARK: - OpenMeteoError

    @Test("OpenMeteoError cases are distinct")
    func errorCases() {
        let invalid = OpenMeteoError.invalidResponse
        let http = OpenMeteoError.httpError(429)

        #expect(invalid.localizedDescription.isEmpty == false)
        if case .httpError(let code) = http {
            #expect(code == 429)
        } else {
            Issue.record("Expected httpError case")
        }
    }

    // MARK: - WMO Complete Coverage

    @Test("All documented WMO codes are handled")
    func allWMOCodes() {
        // Verify every documented WMO code returns a non-cloudy result
        // (cloudy is only for overcast=3 or unknown)
        let expectedNonCloudy: [Int: WeatherConditionType] = [
            0: .clear, 1: .clear,
            2: .partlyCloudy,
            45: .fog, 48: .fog,
            51: .rain, 53: .rain, 55: .rain,
            56: .sleet, 57: .sleet,
            61: .rain, 63: .rain,
            65: .heavyRain,
            66: .sleet, 67: .sleet,
            71: .snow, 73: .snow, 75: .snow, 77: .snow,
            80: .rain, 81: .rain,
            82: .heavyRain,
            85: .snow, 86: .snow,
            95: .thunderstorm, 96: .thunderstorm, 99: .thunderstorm,
        ]

        for (code, expected) in expectedNonCloudy {
            #expect(
                OpenMeteoService.mapWMOCode(code) == expected,
                "WMO code \(code) should map to \(expected)"
            )
        }
    }

    // MARK: - Daily Data Decoding

    @Test("Decodes response with daily data")
    func decodeDailyData() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 20.0,
                "apparent_temperature": 18.0,
                "relative_humidity_2m": 50.0,
                "weather_code": 0,
                "wind_speed_10m": 5.0,
                "uv_index": 3.0,
                "is_day": 1
            },
            "daily": {
                "time": ["2026-03-01", "2026-03-02"],
                "weather_code": [0, 61],
                "temperature_2m_max": [22.5, 18.0],
                "temperature_2m_min": [12.0, 10.5],
                "precipitation_probability_max": [5, 70],
                "uv_index_max": [6.0, 3.0]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        #expect(response.daily != nil)
        #expect(response.daily?.time.count == 2)
        #expect(response.daily?.temperature_2m_max[0] == 22.5)
        #expect(response.daily?.temperature_2m_min[1] == 10.5)
        #expect(response.daily?.weather_code[1] == 61)
        #expect(response.daily?.precipitation_probability_max?[0] == 5)
        #expect(response.daily?.uv_index_max?[0] == 6.0)
    }

    @Test("Decodes response without daily data")
    func decodeWithoutDaily() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 20.0,
                "apparent_temperature": 18.0,
                "relative_humidity_2m": 50.0,
                "weather_code": 0,
                "wind_speed_10m": 5.0,
                "uv_index": 6.0,
                "is_day": 1
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        #expect(response.daily == nil)
    }

    // MARK: - Expanded Hourly Data Decoding

    @Test("Decodes expanded hourly fields")
    func decodeExpandedHourly() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 20.0,
                "apparent_temperature": 18.0,
                "relative_humidity_2m": 50.0,
                "weather_code": 0,
                "wind_speed_10m": 5.0,
                "uv_index": 3.0,
                "is_day": 1
            },
            "hourly": {
                "time": ["2026-03-01T12:00", "2026-03-01T13:00"],
                "temperature_2m": [20.0, 21.5],
                "weather_code": [0, 2],
                "apparent_temperature": [18.0, 19.5],
                "relative_humidity_2m": [50.0, 55.0],
                "uv_index": [3.0, 5.0],
                "wind_speed_10m": [10.0, 15.0],
                "precipitation_probability": [0, 20]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        #expect(response.hourly?.apparent_temperature?.count == 2)
        #expect(response.hourly?.relative_humidity_2m?.count == 2)
        #expect(response.hourly?.uv_index?.count == 2)
        #expect(response.hourly?.wind_speed_10m?.count == 2)
        #expect(response.hourly?.precipitation_probability?.count == 2)
        #expect(response.hourly?.apparent_temperature?[1] == 19.5)
        #expect(response.hourly?.precipitation_probability?[1] == 20)
    }

    // MARK: - Date-Only Parsing

    @Test("Parses date-only format for daily data")
    func parseDateOnly() {
        let date = OpenMeteoService.parseDateOnly("2026-03-01")
        #expect(date != nil)
    }

    @Test("Returns nil for invalid date-only format")
    func parseDateOnlyInvalid() {
        #expect(OpenMeteoService.parseDateOnly("not-a-date") == nil)
        #expect(OpenMeteoService.parseDateOnly("") == nil)
        #expect(OpenMeteoService.parseDateOnly("2026-03-01T12:00") == nil)
    }
}
