//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct CompletionChatOfferTests {
    @Test(arguments: [0, 5, 10, 11, 12, 100])
    func offerStartsAtElevenCompletedBooks(total: Int) {
        for isNew in [true, false] {
            let receipt = CompletionReceipt(book: sample(), isNew: isNew, total: total)
            #expect(receipt.offersChat == (total >= 11))
        }
    }
}
