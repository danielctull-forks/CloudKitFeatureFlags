//
//  AdditionalUserData.swift
//  
//
//  Created by Robin Malhotra on 11/07/20.
//

import Foundation
import CloudKit

enum AdditionalUserDataKeys: String {
	case userFeatureFlaggingID
}

struct AdditionalUserData {
	let featureFlaggingID: UUID
}

struct NoFeatureFlaggingID: Error {
    let record: CKRecord
}

extension AdditionalUserData {
	init(record: CKRecord) throws {
		guard let featureFlagIDString = record[.userFeatureFlaggingID] as? String,
			  let uuid = UUID(uuidString: featureFlagIDString) else {
			throw NoFeatureFlaggingID(record: record)
		}
		self.featureFlaggingID = uuid
	}
}

extension CKRecord {
	
	subscript(key: AdditionalUserDataKeys) -> Any? {
		get {
			return self[key.rawValue]
		}
		set {
			self[key.rawValue] = newValue as? CKRecordValue
		}
	}
}
