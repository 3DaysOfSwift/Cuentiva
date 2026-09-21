//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
import CryptoKit
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct CatalogueAddressTests {
    @Test func missingDownloadAddressFailsWithoutStartingARequest() async {
        let transport = GitHubCatalogueTransport(endpoint: nil)
        await #expect(throws: AppFailure.self) { try await transport.fetch(pack: nil) }
    }
}
