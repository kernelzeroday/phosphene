// XPC swizzles — installed before _start() so we can intercept
// the extensiond-brokered connection.
//
// 1. NSXPCListener tracing (initWithMachServiceName:, _initShared, resume)
// 2. NSXPCConnection.resume swizzle — injects exported object if nil
// 3. Post-resume validation — checks if _exportInfo survives

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <unistd.h>

// ── Globals ──────────────────────────────────────────────────────
static void (^g_configureBlock)(NSXPCConnection *) = nil;
static BOOL g_configuring = NO;

// ── NSXPCListener tracing ────────────────────────────────────────

static id (*g_origListenerInit)(id, SEL, id) = NULL;
static id swizzled_listenerInit(id self_, SEL _cmd, id serviceName) {
    id result = g_origListenerInit(self_, _cmd, serviceName);
    NSLog(@"[XPCTrace] NSXPCListener initWithMachServiceName: %@ → %p", serviceName, result);
    return result;
}

static id (*g_origListenerInitShared)(id, SEL) = NULL;
static id swizzled_listenerInitShared(id self_, SEL _cmd) {
    id result = g_origListenerInitShared(self_, _cmd);
    NSLog(@"[XPCTrace] NSXPCListener _initShared → %p", result);
    return result;
}

// ── NSXPCConnection.resume swizzle ───────────────────────────────

static void (*g_origConnectionResume)(id, SEL) = NULL;

static void swizzled_connectionResume(id self_, SEL _cmd) {
    NSXPCConnection *connection = (NSXPCConnection *)self_;
    pid_t remotePID = connection.processIdentifier;
    pid_t myPID = getpid();

    NSLog(@"[XPCTrace] resume ENTER conn=%p PID=%d exported=%p interface=%p",
          connection, remotePID,
          connection.exportedObject,
          connection.exportedInterface);

    if (!g_configuring
        && connection.exportedObject == nil
        && g_configureBlock != nil
        && remotePID > 0
        && remotePID != myPID)
    {
        NSLog(@"[XPCTrace] Auto-configuring conn=%p from PID %d", connection, remotePID);
        g_configuring = YES;
        g_configureBlock(connection);
        g_configuring = NO;

        NSLog(@"[XPCTrace] After configureBlock conn=%p exported=%p interface=%p",
              connection, connection.exportedObject, connection.exportedInterface);
        // configureBlock called resume internally — skip double-resume
        return;
    }

    g_origConnectionResume(self_, _cmd);

    NSLog(@"[XPCTrace] resume EXIT conn=%p exported=%p interface=%p",
          connection, connection.exportedObject, connection.exportedInterface);
}

// ── shouldAcceptNewConnection swizzle on NSXPCListener delegate ──

static BOOL (*g_origShouldAccept)(id, SEL, id, id) = NULL;

static BOOL swizzled_shouldAcceptNewConnection(id self_, SEL _cmd, id listener, id connection) {
    NSXPCConnection *conn = (NSXPCConnection *)connection;
    NSLog(@"[XPCTrace] shouldAcceptNewConnection ENTER conn=%p PID=%d exported=%p",
          conn, conn.processIdentifier, conn.exportedObject);

    BOOL result = g_origShouldAccept(self_, _cmd, listener, connection);

    NSLog(@"[XPCTrace] shouldAcceptNewConnection EXIT conn=%p result=%d exported=%p",
          conn, result, conn.exportedObject);
    return result;
}

// ── Public entry point ───────────────────────────────────────────

void InstallXPCConnectionSwizzle(void (^ _Nonnull configureBlock)(NSXPCConnection *)) {
    g_configureBlock = [configureBlock copy];

    // 1. NSXPCListener.initWithMachServiceName:
    {
        Method m = class_getInstanceMethod([NSXPCListener class], @selector(initWithMachServiceName:));
        if (m) {
            g_origListenerInit = (id (*)(id, SEL, id))method_getImplementation(m);
            method_setImplementation(m, (IMP)swizzled_listenerInit);
        }
    }

    // 2. NSXPCListener._initShared
    {
        SEL sel = NSSelectorFromString(@"_initShared");
        Method m = class_getInstanceMethod([NSXPCListener class], sel);
        if (m) {
            g_origListenerInitShared = (id (*)(id, SEL))method_getImplementation(m);
            method_setImplementation(m, (IMP)swizzled_listenerInitShared);
        }
    }

    // 3. NSXPCListener.resume (trace only)
    {
        static void (*origListenerResume)(id, SEL) = NULL;
        Method m = class_getInstanceMethod([NSXPCListener class], @selector(resume));
        if (m) {
            origListenerResume = (void (*)(id, SEL))method_getImplementation(m);
            void (^block)(id) = ^(id self_) {
                NSLog(@"[XPCTrace] NSXPCListener.resume: listener=%p delegate=%p",
                      self_, [(NSXPCListener *)self_ delegate]);
                origListenerResume(self_, @selector(resume));
            };
            method_setImplementation(m, imp_implementationWithBlock(block));
        }
    }

    // 4. NSXPCConnection.resume — inject exported object before first resume
    {
        Method m = class_getInstanceMethod([NSXPCConnection class], @selector(resume));
        if (m) {
            g_origConnectionResume = (void (*)(id, SEL))method_getImplementation(m);
            method_setImplementation(m, (IMP)swizzled_connectionResume);
        }
    }

    NSLog(@"[XPCTrace] All swizzles installed (PID %d)", getpid());
}

// Separate function to swizzle shouldAcceptNewConnection on a specific delegate.
// Called from Swift after creating the delegate.
void InstallShouldAcceptSwizzle(id delegate) {
    Class cls = object_getClass(delegate);
    SEL sel = @selector(listener:shouldAcceptNewConnection:);
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        g_origShouldAccept = (BOOL (*)(id, SEL, id, id))method_getImplementation(m);
        method_setImplementation(m, (IMP)swizzled_shouldAcceptNewConnection);
        NSLog(@"[XPCTrace] Swizzled shouldAcceptNewConnection on %s", class_getName(cls));
    } else {
        NSLog(@"[XPCTrace] WARNING: shouldAcceptNewConnection not found on %s", class_getName(cls));
    }
}
