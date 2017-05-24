///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///
/// Auto-generated by Stone, do not modify.
///

#import <Foundation/Foundation.h>

#import "DBSerializableProtocol.h"

@class DBTEAMLOGExternalSharingPolicy;
@class DBTEAMLOGSharingChangeFolderJoinPolicyDetails;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - API Object

///
/// The `SharingChangeFolderJoinPolicyDetails` struct.
///
/// Changed whether team members can join shared folders owned externally (i.e.
/// outside the team).
///
/// This class implements the `DBSerializable` protocol (serialize and
/// deserialize instance methods), which is required for all Obj-C SDK API route
/// objects.
///
@interface DBTEAMLOGSharingChangeFolderJoinPolicyDetails : NSObject <DBSerializable, NSCopying>

#pragma mark - Instance fields

/// New external join policy.
@property (nonatomic, readonly) DBTEAMLOGExternalSharingPolicy *dNewValue;

/// Previous external join policy. Might be missing due to historical data gap.
@property (nonatomic, readonly, nullable) DBTEAMLOGExternalSharingPolicy *previousValue;

#pragma mark - Constructors

///
/// Full constructor for the struct (exposes all instance variables).
///
/// @param dNewValue New external join policy.
/// @param previousValue Previous external join policy. Might be missing due to
/// historical data gap.
///
/// @return An initialized instance.
///
- (instancetype)initWithDNewValue:(DBTEAMLOGExternalSharingPolicy *)dNewValue
                    previousValue:(nullable DBTEAMLOGExternalSharingPolicy *)previousValue;

///
/// Convenience constructor (exposes only non-nullable instance variables with
/// no default value).
///
/// @param dNewValue New external join policy.
///
/// @return An initialized instance.
///
- (instancetype)initWithDNewValue:(DBTEAMLOGExternalSharingPolicy *)dNewValue;

- (instancetype)init NS_UNAVAILABLE;

@end

#pragma mark - Serializer Object

///
/// The serialization class for the `SharingChangeFolderJoinPolicyDetails`
/// struct.
///
@interface DBTEAMLOGSharingChangeFolderJoinPolicyDetailsSerializer : NSObject

///
/// Serializes `DBTEAMLOGSharingChangeFolderJoinPolicyDetails` instances.
///
/// @param instance An instance of the
/// `DBTEAMLOGSharingChangeFolderJoinPolicyDetails` API object.
///
/// @return A json-compatible dictionary representation of the
/// `DBTEAMLOGSharingChangeFolderJoinPolicyDetails` API object.
///
+ (NSDictionary *)serialize:(DBTEAMLOGSharingChangeFolderJoinPolicyDetails *)instance;

///
/// Deserializes `DBTEAMLOGSharingChangeFolderJoinPolicyDetails` instances.
///
/// @param dict A json-compatible dictionary representation of the
/// `DBTEAMLOGSharingChangeFolderJoinPolicyDetails` API object.
///
/// @return An instantiation of the
/// `DBTEAMLOGSharingChangeFolderJoinPolicyDetails` object.
///
+ (DBTEAMLOGSharingChangeFolderJoinPolicyDetails *)deserialize:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
