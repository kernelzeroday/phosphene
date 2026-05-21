// ObjC protocol declarations for XPC interface metadata.
//
// Compiled only by the ObjC compiler (via ProtocolRegistrar.m) to ensure
// proper method-description metadata generation that protocol_copyMethodDescriptionList
// can enumerate — required by NSXPCInterface for XPC dispatch.
//
// IMPORTANT: Protocol names are prefixed with "Phosphene" to avoid colliding
// with identically-named protocols in Apple's WallpaperExtensionKit framework.
// The ObjC runtime keeps whichever protocol is registered first; our binary's
// protocols load before dlopen'd frameworks. Without the prefix, the framework's
// version (with empty metadata from a different compilation) would be shadowed
// by ours — or vice versa — causing NSXPCInterface to have no methods.

#import <Foundation/Foundation.h>

// MARK: - Extension protocol (what WallpaperAgent calls on us)

@protocol PhospheneWallpaperExtensionXPCProtocol <NSObject>

@required

// MARK: - Lifecycle
- (void)acquireWithId:(id)anId request:(id)request reply:(void (^ _Nonnull)(id _Nullable, NSError * _Nullable))reply;
- (void)updateWithId:(id)anId request:(id)request reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)invalidateWithId:(id)anId reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)snapshotWithId:(id)anId reply:(void (^ _Nonnull)(id _Nullable, NSError * _Nullable))reply;

// MARK: - Settings
- (void)provideSettingsViewModelsWithContentTypes:(id)contentTypes reply:(void (^ _Nonnull)(id _Nullable, NSError * _Nullable))reply;

// MARK: - Choices
- (void)addChoiceRequestWithChoiceRequest:(id)request onBehalfOfProcess:(id)process reply:(void (^ _Nonnull)(id _Nullable, NSError * _Nullable))reply;
- (void)removeChoiceRequestWithChoiceRequest:(id)request reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)selectedChoicesDidChangeFor:(id)anId reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)invokeContextMenuActionWithMenuItemID:(id)menuItemID groupItemID:(id)groupItemID reply:(void (^ _Nonnull)(NSError * _Nullable))reply;

// MARK: - Downloads
- (void)isChoiceDownloadedWith:(id)choiceId reply:(void (^ _Nonnull)(BOOL, NSError * _Nullable))reply;
- (id)downloadWithChoiceID:(id)choiceId reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)pauseDownloadFor:(id)anId reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)cancelDownloadFor:(id)anId reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)resumeDownloadFor:(id)anId reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)removeDownloadFor:(id)anId reply:(void (^ _Nonnull)(NSError * _Nullable))reply;

// MARK: - Migration
- (void)migrateSelectedChoiceFor:(id)anId reply:(void (^ _Nonnull)(id _Nullable, NSError * _Nullable))reply;
- (void)migrateFrom:(id)from to:(id)to reply:(void (^ _Nonnull)(NSError * _Nullable))reply;

// MARK: - Shuffle
- (void)skipShuffledContentWithId:(id)anId reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)canSkipShuffledContentWithId:(id)anId reply:(void (^ _Nonnull)(BOOL, NSError * _Nullable))reply;

// MARK: - Debug & Notifications
- (void)handleDebugRequestFor:(id)request reply:(void (^ _Nonnull)(id _Nullable, NSError * _Nullable))reply;
- (void)handleNotificationWithNamed:(id)name reply:(void (^ _Nonnull)(NSError * _Nullable))reply;

@end

// MARK: - Proxy protocol (what we call on WallpaperAgent)

@protocol PhospheneWallpaperExtensionProxyXPCProtocol <NSObject>

@required
- (void)pingWithId:(id _Nullable)anId;
- (void)updateSettingsViewModels:(id _Nullable)models reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)requestReadOnlyAccessTo:(id _Nullable)url reply:(void (^ _Nonnull)(id _Nullable))reply;
- (void)invalidateSnapshotsWithReply:(void (^ _Nonnull)(NSError * _Nullable))reply;

@end
