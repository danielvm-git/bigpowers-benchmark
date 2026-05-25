@testable import BigPowersBenchmarkKit
import Foundation
import Testing

@Suite("PingTransport")
struct PingTransportTests {
    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        for transport in PingTransport.allCases {
            let data = try JSONEncoder().encode(transport)
            let decoded = try JSONDecoder().decode(PingTransport.self, from: data)
            #expect(decoded == transport)
        }
    }

    @Test("channelDisplayName maps subscription channels")
    func channelDisplayName() {
        #expect(PingTransport.openRouter.channelDisplayName == "OpenRouter")
        #expect(PingTransport.nousResearch.channelDisplayName == "Nous Portal")
        #expect(PingTransport.claudeCLI.channelDisplayName == "Claude CLI")
        #expect(PingTransport.geminiCLI.channelDisplayName == "Gemini CLI")
        #expect(PingTransport.openCode.channelDisplayName == "OpenCode Zen")
    }
}

@Suite("StaticModelCatalogs")
struct StaticModelCatalogsTests {
    @Test("all catalogs are non-empty")
    func nonEmpty() {
        #expect(!StaticModelCatalogs.nousResearch.isEmpty)
        #expect(!StaticModelCatalogs.claudeCLI.isEmpty)
        #expect(!StaticModelCatalogs.geminiCLI.isEmpty)
        #expect(!StaticModelCatalogs.openCode.isEmpty)
        #expect(!StaticModelCatalogs.all.isEmpty)
    }

    @Test("nous research catalog has 24 portal models")
    func nousCatalogCount() {
        #expect(StaticModelCatalogs.nousResearch.count == 24)
    }

    @Test("static models have correct transport and pricing")
    func transportAndPricing() {
        for model in StaticModelCatalogs.nousResearch {
            #expect(!model.isFreeModel)
            #expect(model.pingTransport == .nousResearch)
            #expect(model.provider == "nousresearch-direct")
            #expect(model.apiModelId != model.id)
        }

        for model in StaticModelCatalogs.claudeCLI {
            #expect(!model.isFreeModel)
            #expect(model.pingTransport == .claudeCLI)
            #expect(model.provider == "claudecli")
        }

        for model in StaticModelCatalogs.geminiCLI {
            #expect(!model.isFreeModel)
            #expect(model.pingTransport == .geminiCLI)
            #expect(model.provider == "geminicli")
        }

        for model in StaticModelCatalogs.openCode {
            #expect(model.pingTransport == .openCode)
            #expect(model.provider == "opencode")
            #expect(model.apiModelId.hasPrefix("opencode/"))
            if model.apiModelId.contains("-free") {
                #expect(model.isFreeModel)
            } else {
                #expect(!model.isFreeModel)
            }
        }
    }

    @Test("ModelInfo decodes legacy cache without transport fields")
    func legacyDecode() throws {
        let json = """
        {
          "id": "openai/gpt-4o",
          "name": "GPT-4o",
          "provider": "openai",
          "contextWindow": 128000,
          "tier": "deep",
          "capabilities": ["tools"],
          "pricing": { "inputPer1k": 5, "outputPer1k": 15 }
        }
        """
        let model = try JSONDecoder().decode(ModelInfo.self, from: Data(json.utf8))
        #expect(model.pingTransport == .openRouter)
        #expect(model.resolvedModelId == nil)
        #expect(model.apiModelId == "openai/gpt-4o")
    }

    @Test("applyCache updates nousResearch and openCode")
    func applyCache() {
        let savedNous = StaticModelCatalogs.nousResearch
        let savedOpenCode = StaticModelCatalogs.openCode
        defer {
            StaticModelCatalogs.nousResearch = savedNous
            StaticModelCatalogs.openCode = savedOpenCode
        }

        let refreshedNous = [
            StaticModelCatalogs.portalModel(id: "test/only", name: "Only Test"),
        ]
        let refreshedOpenCode = [
            StaticModelCatalogs.opencodeModel(id: "opencode/test", name: "OpenCode Zen Test"),
        ]
        StaticModelCatalogs.applyCache(
            StaticCatalogCache(
                fetchedAt: Date(),
                nousResearch: refreshedNous,
                openCode: refreshedOpenCode
            )
        )

        #expect(StaticModelCatalogs.nousResearch.count == 1)
        #expect(StaticModelCatalogs.nousResearch[0].apiModelId == "test/only")
        #expect(StaticModelCatalogs.openCode.count == 1)
        #expect(StaticModelCatalogs.openCode[0].apiModelId == "opencode/test")
        #expect(StaticModelCatalogs.all.contains { $0.id == "nousresearch-direct:test/only" })
    }
}
