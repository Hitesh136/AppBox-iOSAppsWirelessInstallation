///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///
/// Auto-generated by Stone, do not modify.
///

#import <Foundation/Foundation.h>

#import "DBSerializableProtocol.h"

@class DBSHARINGModifySharedLinkSettingsError;
@class DBSHARINGSharedLinkSettingsError;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - API Object

///
/// The `ModifySharedLinkSettingsError` union.
///
/// This class implements the `DBSerializable` protocol (serialize and
/// deserialize instance methods), which is required for all Obj-C SDK API route
/// objects.
///
@interface DBSHARINGModifySharedLinkSettingsError : NSObject <DBSerializable, NSCopying>

#pragma mark - Instance fields

/// The `DBSHARINGModifySharedLinkSettingsErrorTag` enum type represents the
/// possible tag states with which the `DBSHARINGModifySharedLinkSettingsError`
/// union can exist.
typedef NS_ENUM(NSInteger, DBSHARINGModifySharedLinkSettingsErrorTag) {
  /// The shared link wasn't found.
  DBSHARINGModifySharedLinkSettingsErrorSharedLinkNotFound,

  /// The caller is not allowed to access this shared link.
  DBSHARINGModifySharedLinkSettingsErrorSharedLinkAccessDenied,

  /// This type of link is not supported.
  DBSHARINGModifySharedLinkSettingsErrorUnsupportedLinkType,

  /// (no description).
  DBSHARINGModifySharedLinkSettingsErrorOther,

  /// There is an error with the given settings
  DBSHARINGModifySharedLinkSettingsErrorSettingsError,

  /// The caller's email should be verified
  DBSHARINGModifySharedLinkSettingsErrorEmailNotVerified,

};

/// Represents the union's current tag state.
@property (nonatomic, readonly) DBSHARINGModifySharedLinkSettingsErrorTag tag;

/// There is an error with the given settings @note Ensure the `isSettingsError`
/// method returns true before accessing, otherwise a runtime exception will be
/// raised.
@property (nonatomic, readonly) DBSHARINGSharedLinkSettingsError *settingsError;

#pragma mark - Constructors

///
/// Initializes union class with tag state of "shared_link_not_found".
///
/// Description of the "shared_link_not_found" tag state: The shared link wasn't
/// found.
///
/// @return An initialized instance.
///
- (instancetype)initWithSharedLinkNotFound;

///
/// Initializes union class with tag state of "shared_link_access_denied".
///
/// Description of the "shared_link_access_denied" tag state: The caller is not
/// allowed to access this shared link.
///
/// @return An initialized instance.
///
- (instancetype)initWithSharedLinkAccessDenied;

///
/// Initializes union class with tag state of "unsupported_link_type".
///
/// Description of the "unsupported_link_type" tag state: This type of link is
/// not supported.
///
/// @return An initialized instance.
///
- (instancetype)initWithUnsupportedLinkType;

///
/// Initializes union class with tag state of "other".
///
/// @return An initialized instance.
///
- (instancetype)initWithOther;

///
/// Initializes union class with tag state of "settings_error".
///
/// Description of the "settings_error" tag state: There is an error with the
/// given settings
///
/// @param settingsError There is an error with the given settings
///
/// @return An initialized instance.
///
- (instancetype)initWithSettingsError:(DBSHARINGSharedLinkSettingsError *)settingsError;

///
/// Initializes union class with tag state of "email_not_verified".
///
/// Description of the "email_not_verified" tag state: The caller's email should
/// be verified
///
/// @return An initialized instance.
///
- (instancetype)initWithEmailNotVerified;

- (instancetype)init NS_UNAVAILABLE;

#pragma mark - Tag state methods

///
/// Retrieves whether the union's current tag state has value
/// "shared_link_not_found".
///
/// @return Whether the union's current tag state has value
/// "shared_link_not_found".
///
- (BOOL)isSharedLinkNotFound;

///
/// Retrieves whether the union's current tag state has value
/// "shared_link_access_denied".
///
/// @return Whether the union's current tag state has value
/// "shared_link_access_denied".
///
- (BOOL)isSharedLinkAccessDenied;

///
/// Retrieves whether the union's current tag state has value
/// "unsupported_link_type".
///
/// @return Whether the union's current tag state has value
/// "unsupported_link_type".
///
- (BOOL)isUnsupportedLinkType;

///
/// Retrieves whether the union's current tag state has value "other".
///
/// @return Whether the union's current tag state has value "other".
///
- (BOOL)isOther;

///
/// Retrieves whether the union's current tag state has value "settings_error".
///
/// @note Call this method and ensure it returns true before accessing the
/// `settingsError` property, otherwise a runtime exception will be thrown.
///
/// @return Whether the union's current tag state has value "settings_error".
///
- (BOOL)isSettingsError;

///
/// Retrieves whether the union's current tag state has value
/// "email_not_verified".
///
/// @return Whether the union's current tag state has value
/// "email_not_verified".
///
- (BOOL)isEmailNotVerified;

///
/// Retrieves string value of union's current tag state.
///
/// @return A human-readable string representing the union's current tag state.
///
- (NSString *)tagName;

@end

#pragma mark - Serializer Object

///
/// The serialization class for the `DBSHARINGModifySharedLinkSettingsError`
/// union.
///
@interface DBSHARINGModifySharedLinkSettingsErrorSerializer : NSObject

///
/// Serializes `DBSHARINGModifySharedLinkSettingsError` instances.
///
/// @param instance An instance of the `DBSHARINGModifySharedLinkSettingsError`
/// API object.
///
/// @return A json-compatible dictionary representation of the
/// `DBSHARINGModifySharedLinkSettingsError` API object.
///
+ (NSDictionary *)serialize:(DBSHARINGModifySharedLinkSettingsError *)instance;

///
/// Deserializes `DBSHARINGModifySharedLinkSettingsError` instances.
///
/// @param dict A json-compatible dictionary representation of the
/// `DBSHARINGModifySharedLinkSettingsError` API object.
///
/// @return An instantiation of the `DBSHARINGModifySharedLinkSettingsError`
/// object.
///
+ (DBSHARINGModifySharedLinkSettingsError *)deserialize:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
