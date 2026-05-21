// Dummy ObjC classes conforming to the XPC protocols.
//
// Forces the ObjC compiler to generate protocol metadata with populated
// method-description lists that protocol_copyMethodDescriptionList can
// enumerate — required by NSXPCInterface for XPC method dispatch.

#import "WallpaperProtocols.h"

@interface _WallpaperProtocolDummy : NSObject <PhospheneWallpaperExtensionXPCProtocol>
@end

@implementation _WallpaperProtocolDummy

// MARK: - Lifecycle
- (void)acquireWithId:(id)anId request:(id)request reply:(void (^)(id _Nullable, NSError * _Nullable))reply { reply(nil, nil); }
- (void)updateWithId:(id)anId request:(id)request reply:(void (^)(NSError * _Nullable))reply { reply(nil); }
- (void)invalidateWithId:(id)anId reply:(void (^)(NSError * _Nullable))reply { reply(nil); }
- (void)snapshotWithId:(id)anId reply:(void (^)(id _Nullable, NSError * _Nullable))reply { reply(nil, nil); }

// MARK: - Settings
- (void)provideSettingsViewModelsWithContentTypes:(id)contentTypes reply:(void (^)(id _Nullable, NSError * _Nullable))reply { reply(nil, nil); }

// MARK: - Choices
- (void)addChoiceRequestWithChoiceRequest:(id)request onBehalfOfProcess:(id)process reply:(void (^)(id _Nullable, NSError * _Nullable))reply { reply(nil, nil); }
- (void)removeChoiceRequestWithChoiceRequest:(id)request reply:(void (^)(NSError * _Nullable))reply { reply(nil); }
- (void)selectedChoicesDidChangeFor:(id)anId reply:(void (^)(NSError * _Nullable))reply { reply(nil); }
- (void)invokeContextMenuActionWithMenuItemID:(id)menuItemID groupItemID:(id)groupItemID reply:(void (^)(NSError * _Nullable))reply { reply(nil); }

// MARK: - Downloads
- (void)isChoiceDownloadedWith:(id)choiceId reply:(void (^)(BOOL, NSError * _Nullable))reply { reply(YES, nil); }
- (id)downloadWithChoiceID:(id)choiceId reply:(void (^)(NSError * _Nullable))reply { reply(nil); return nil; }
- (void)pauseDownloadFor:(id)anId reply:(void (^)(NSError * _Nullable))reply { reply(nil); }
- (void)cancelDownloadFor:(id)anId reply:(void (^)(NSError * _Nullable))reply { reply(nil); }
- (void)resumeDownloadFor:(id)anId reply:(void (^)(NSError * _Nullable))reply { reply(nil); }
- (void)removeDownloadFor:(id)anId reply:(void (^)(NSError * _Nullable))reply { reply(nil); }

// MARK: - Migration
- (void)migrateSelectedChoiceFor:(id)anId reply:(void (^)(id _Nullable, NSError * _Nullable))reply { reply(nil, nil); }
- (void)migrateFrom:(id)from to:(id)to reply:(void (^)(NSError * _Nullable))reply { reply(nil); }

// MARK: - Shuffle
- (void)skipShuffledContentWithId:(id)anId reply:(void (^)(NSError * _Nullable))reply { reply(nil); }
- (void)canSkipShuffledContentWithId:(id)anId reply:(void (^)(BOOL, NSError * _Nullable))reply { reply(NO, nil); }

// MARK: - Debug & Notifications
- (void)handleDebugRequestFor:(id)request reply:(void (^)(id _Nullable, NSError * _Nullable))reply { reply(nil, nil); }
- (void)handleNotificationWithNamed:(id)name reply:(void (^)(NSError * _Nullable))reply { reply(nil); }

@end

@interface _WallpaperProxyProtocolDummy : NSObject <PhospheneWallpaperExtensionProxyXPCProtocol>
@end

@implementation _WallpaperProxyProtocolDummy

- (void)pingWithId:(id)anId {}
- (void)updateSettingsViewModels:(id)models reply:(void (^)(NSError * _Nullable))reply { reply(nil); }
- (void)requestReadOnlyAccessTo:(id)url reply:(void (^)(id _Nullable))reply { reply(nil); }
- (void)invalidateSnapshotsWithReply:(void (^)(NSError * _Nullable))reply { reply(nil); }

@end
