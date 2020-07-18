//
//  FeatureFlagCoordinator.swift
//  
//
//  Created by Robin Malhotra on 11/07/20.
//

import Foundation
import CloudKit
import Combine

extension Publisher where Failure == Error {

    /// Handles a specific error type from an upstream publisher by replacing it
    /// with another publisher.
    ///
    /// - Parameters:
    ///   - type: The type of error to handle.
    ///   - handler: A closure that accepts the upstream failure as input and
    ///              returns a publisher to replace the upstream publisher.
    /// - Returns: A publisher that handles errors of the given type from an
    ///            upstream publisher by replacing the failed publisher with
    ///            another publisher.
    public func `catch`<F: Error, P: Publisher>(
        _ type: F.Type,
        _ handler: @escaping (F) -> P
    ) -> Publishers.TryCatch<Self, P> where P.Output == Output {
        tryCatch { error in
            guard let failure = error as? F else { throw error }
            return handler(failure)
        }
    }
}

class FeatureFlagCoordinator {

	let container: Container
	//TODO: make this a store that's updated from CK subscription
	private let featureFlags: AnyPublisher<[String: FeatureFlag], Error>
	private let userData: AnyPublisher<AdditionalUserData, Error>

	init(container: Container) {
		self.container = container
        let database = container.featureFlaggingDatabase

        func createFeatureFlaggingID(_ record: CKRecord) -> AnyPublisher<AdditionalUserData, Error> {
            record[.userFeatureFlaggingID] = UUID().uuidString
            return database
                .save(record: record)
                .tryMap(AdditionalUserData.init)
                .eraseToAnyPublisher()
        }

        userData = container
            .userRecordID
            .flatMap(database.record(for:))
            .tryMap(AdditionalUserData.init)
            .catch(NoFeatureFlaggingID.self) { createFeatureFlaggingID($0.record) }
            .eraseToAnyPublisher()

        let query = CKQuery(recordType: "FeatureFlag", predicate: NSPredicate(value: true))
        featureFlags = database
            .records(matching: query, inZoneWith: nil)
            .mapError { $0 as Error }
            .map {
                $0.compactMap(FeatureFlag.init).reduce(into: [:]) { dict, flag in
                    dict[flag.name] = flag
                }
            }
            .eraseToAnyPublisher()
	}

	@discardableResult func featureEnabled(name: String) -> AnyPublisher<Bool, Error> {
		Publishers.CombineLatest(featureFlags, userData).map { (dict, userData) -> Bool in
			guard let ff = dict[name] else {
				return false
			}
			//TODO: figure out what to do here
			return FlaggingLogic.shouldBeActive(hash: FlaggingLogic.userFeatureFlagHash(flagUUID: ff.uuid, userUUID: userData.featureFlaggingID), rollout: ff.rollout)
		}.eraseToAnyPublisher()
	}
}
