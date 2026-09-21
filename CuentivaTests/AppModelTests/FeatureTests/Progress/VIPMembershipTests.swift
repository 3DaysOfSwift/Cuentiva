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

@Suite struct VIPMembershipTests {
    @Test(arguments: [0, 99, 100, 101, 1000])
    func membershipAndBadgesShareTheSavedCompletionThreshold(count: Int) throws {
        var progress = LearnerProgress()
        progress.completed = Set((0..<count).map { "book-\($0)" })
        #expect(progress.isVIP == (count >= 100))
        #expect(progress.readerBadges.contains(.vip) == progress.isVIP)
        let restored = try ProgressRecords.decode(ProgressRecords.encode(progress))
        #expect(restored.isVIP == progress.isVIP)
    }
}
