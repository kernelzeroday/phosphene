//
//  WallpaperExtension-Bridging-Header.h
//  WallpaperVideoExtension
//
//  ObjC protocol definitions matching WallpaperExtensionKit.
//  XPC type classes are loaded at runtime via dlopen.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// MARK: - Private CAContext API (for remote rendering)

@interface CAContext : NSObject
@property (readonly) unsigned int contextId;
@property (retain) CALayer *layer;
+ (id)remoteContext;
+ (id)remoteContextWithOptions:(id)options;
+ (id)contextWithCGSConnection:(unsigned int)cgsconnection options:(id)options;
+ (void)setAllowsCGSConnections:(_Bool)cgsconnections;
@end

// MARK: - Private CGS API

extern unsigned int CGSMainConnectionID(void);

// MARK: - Extension Entry Points

// NSExtensionMain is the Foundation entry point for old-style NS extensions.
FOUNDATION_EXPORT int NSExtensionMain(int argc, char *argv[]);

// EXExtensionMain is the ExtensionFoundation entry point for ExtensionKit
// extensions. On macOS 26, _start() reenters the binary's main() entry point;
// detect reentry with ext_main_already_called() and enter dispatchMain().
extern int EXExtensionMain(int argc, char *argv[]);

// MARK: - C exit catcher (setjmp/longjmp helper)

// Calls ext_main(argc, argv) while catching exit(0) via atexit + longjmp.
// Returns 0 on normal return, 1 if exit(0) was caught.
int catch_exit_and_call_ext_main(int (*ext_main)(int, char **), int argc, char *argv[]);

// Reentrancy guard: returns 1 if set_ext_main_called() was called.
int ext_main_already_called(void);
void set_ext_main_called(void);

// Install a SIGTRAP handler that skips brk instructions (arm64),
// letting _start() continue past assertionFailure calls.
void install_sigtrap_skip_handler(void);

// MARK: - XPC protocols (Swift-visible declarations)
//
// Full protocol declarations live in WallpaperProtocols.h and are compiled
// only by the ObjC compiler (via ProtocolRegistrar.m) so the runtime has
// proper method-description metadata for NSXPCInterface.
//
// These duplicate declarations let Swift see the types for casting. They
// use "Phosphene"-prefixed names to avoid colliding with Apple's framework.
// MARK: - Identity helper (IdentityHelper.m)

id _Nullable CreateExtensionIdentityFromBundle(NSError * _Nullable * _Nullable outError);
void SetIvarAtOffset(id _Nonnull target, NSInteger offset, id _Nonnull value);
void DumpIdentity(id _Nonnull identity);

// MARK: - C-level XPC listener (XPCListenerHelper.m)

// MARK: - syslog helper (os_log wrapper callable from Swift 6)

#import <os/log.h>

static inline void syslog_trace(NSString * _Nonnull msg) {
    os_log(OS_LOG_DEFAULT, "%{public}@", msg);
}

// MARK: - XPC connection swizzle (XPCListenerHelper.m)

void InstallXPCConnectionSwizzle(void (^ _Nonnull configureBlock)(NSXPCConnection * _Nonnull));
void InstallShouldAcceptSwizzle(id _Nonnull delegate);

@protocol PhospheneWallpaperExtensionProxyXPCProtocol <NSObject>
- (void)pingWithId:(id _Nullable)anId;
- (void)updateSettingsViewModels:(id _Nullable)models reply:(void (^ _Nonnull)(NSError * _Nullable))reply;
- (void)requestReadOnlyAccessTo:(id _Nullable)url reply:(void (^ _Nonnull)(id _Nullable))reply;
- (void)invalidateSnapshotsWithReply:(void (^ _Nonnull)(NSError * _Nullable))reply;
@end
