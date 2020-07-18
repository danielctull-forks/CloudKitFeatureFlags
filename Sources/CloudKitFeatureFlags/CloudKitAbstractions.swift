//
//  CloudKitAbstractions.swift
//  
//
//  Created by Robin Malhotra on 17/07/20.
//

import CloudKit
import Combine

protocol Database {
	func fetch(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord?, Error?) -> Void)
	func save(_ record: CKRecord, completionHandler: @escaping (CKRecord?, Error?) -> Void)
	func perform(_ query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?, completionHandler: @escaping ([CKRecord]?, Error?) -> Void)
}

protocol Container {

	/// I'd love to name this `publicCloudDatabase` but Swift won't let me
	var featureFlaggingDatabase: Database { get }

	func fetchUserRecordID(completionHandler: @escaping (CKRecord.ID?, Error?) -> Void)
}

extension CKDatabase: Database { }

extension CKContainer: Container {
	var featureFlaggingDatabase: Database {
		return publicCloudDatabase
	}
}

extension Container {

    var userRecordID: AnyPublisher<CKRecord.ID, CKError> {
        Future { promise in
            fetchUserRecordID { id, error in
                guard let id = id else {
                    let error = error as? CKError ?? CKError(.internalError)
                    promise(.failure(error))
                    return
                }
                promise(.success(id))
            }
        }
        .eraseToAnyPublisher()
    }
}

extension Database {

    func record(for id: CKRecord.ID) -> AnyPublisher<CKRecord, CKError> {
        Future { promise in
            fetch(withRecordID: id) { record, error in
                guard let record = record else {
                    let error = error as? CKError ?? CKError(.internalError)
                    promise(.failure(error))
                    return
                }
                promise(.success(record))
            }
        }
        .eraseToAnyPublisher()
    }

    func save(record: CKRecord) -> AnyPublisher<CKRecord, CKError> {
        Future { promise in
            save(record) { record, error in
                guard let record = record else {
                    let error = error as? CKError ?? CKError(.internalError)
                    promise(.failure(error))
                    return
                }
                promise(.success(record))
            }
        }
        .eraseToAnyPublisher()
    }

    func records(matching query: CKQuery, inZoneWith id: CKRecordZone.ID?) -> AnyPublisher<[CKRecord], CKError> {

        Future { promise in
            perform(query, inZoneWith: id) { records, error in
                guard let records = records else {
                    let error = error as? CKError ?? CKError(.internalError)
                    promise(.failure(error))
                    return
                }
                promise(.success(records))
            }
        }
        .eraseToAnyPublisher()
    }
}
