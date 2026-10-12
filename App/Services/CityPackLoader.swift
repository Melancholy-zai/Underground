import Foundation

struct LoadedCity {
    let repository: CityRepository
    let svg: String
}

enum CityPackLoader {
    static func load(bundle: Bundle = .main) throws -> LoadedCity {
        guard let folder = bundle.url(forResource: "CityPack", withExtension: nil) else {
            throw MetroError.invalidData("缺少内置城市资料包，请重新构建 App")
        }
        let manifest = try Data(contentsOf: folder.appendingPathComponent("manifest.json"))
        let city = try Data(contentsOf: folder.appendingPathComponent("city.json"))
        let svgData = try Data(contentsOf: folder.appendingPathComponent("map.svg"))
        let repository = try CityRepository(manifestData: manifest, cityData: city, svgData: svgData)
        guard let svg = String(data: svgData, encoding: .utf8) else {
            throw MetroError.invalidData("城市资料编码无效")
        }
        return LoadedCity(repository: repository, svg: svg)
    }
}
