#import <Foundation/Foundation.h>
#import <objc/runtime.h>

id _Nullable CreateExtensionIdentityFromBundle(NSError **outError) {
    Class identityCls = objc_getClass("_EXExtensionIdentity");
    if (!identityCls) {
        if (outError) *outError = [NSError errorWithDomain:@"Phosphene" code:1
            userInfo:@{NSLocalizedDescriptionKey: @"_EXExtensionIdentity class not found"}];
        return nil;
    }

    // Try initWithNSExtension:error: — requires an NSExtension from the bundle
    SEL nsExtSel = NSSelectorFromString(@"initWithNSExtension:error:");

    // First, try to discover our own extension
    NSBundle *extBundle = [NSBundle mainBundle];
    NSLog(@"[IdentityHelper] Bundle ID: %@", extBundle.bundleIdentifier);
    NSLog(@"[IdentityHelper] Bundle path: %@", extBundle.bundlePath);

    // Try LSApplicationExtensionRecord approach
    Class lsRecordCls = objc_getClass("LSApplicationExtensionRecord");
    if (lsRecordCls) {
        NSLog(@"[IdentityHelper] Found LSApplicationExtensionRecord class");
        SEL bundleIdSel = NSSelectorFromString(@"applicationExtensionRecordForBundleIdentifier:error:");
        if ([lsRecordCls respondsToSelector:bundleIdSel]) {
            NSLog(@"[IdentityHelper] Trying applicationExtensionRecordForBundleIdentifier:");
            NSError *lsError = nil;
            NSMethodSignature *sig = [lsRecordCls methodSignatureForSelector:bundleIdSel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setTarget:lsRecordCls];
            [inv setSelector:bundleIdSel];
            NSString *bundleId = extBundle.bundleIdentifier;
            [inv setArgument:&bundleId atIndex:2];
            [inv setArgument:&lsError atIndex:3];
            [inv invoke];

            __unsafe_unretained id record = nil;
            [inv getReturnValue:&record];
            NSLog(@"[IdentityHelper] LS record: %@ error: %@", record, lsError);

            if (record) {
                SEL initSel = NSSelectorFromString(@"initWithApplicationExtensionRecord:");
                id identity = [[identityCls alloc] performSelector:initSel withObject:record];
                if (identity) {
                    NSLog(@"[IdentityHelper] Created identity from LS record!");
                    return identity;
                }
            }
        }
    }

    // Try creating NSExtension and using initWithNSExtension:error:
    Class nsExtCls = objc_getClass("NSExtension");
    if (nsExtCls) {
        NSLog(@"[IdentityHelper] Trying NSExtension approach");

        // Try extensionWithIdentifier:error:
        SEL extWithIdSel = NSSelectorFromString(@"extensionWithIdentifier:error:");
        if ([nsExtCls respondsToSelector:extWithIdSel]) {
            NSError *nsExtError = nil;
            NSMethodSignature *sig = [nsExtCls methodSignatureForSelector:extWithIdSel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setTarget:nsExtCls];
            [inv setSelector:extWithIdSel];
            NSString *bundleId = extBundle.bundleIdentifier;
            [inv setArgument:&bundleId atIndex:2];
            [inv setArgument:&nsExtError atIndex:3];
            [inv invoke];

            __unsafe_unretained id nsExtObj = nil;
            [inv getReturnValue:&nsExtObj];
            NSLog(@"[IdentityHelper] NSExtension: %@ error: %@", nsExtObj, nsExtError);

            if (nsExtObj && [identityCls instancesRespondToSelector:nsExtSel]) {
                NSError *idError = nil;
                id identity = [identityCls alloc];
                NSMethodSignature *idSig = [identity methodSignatureForSelector:nsExtSel];
                NSInvocation *idInv = [NSInvocation invocationWithMethodSignature:idSig];
                [idInv setTarget:identity];
                [idInv setSelector:nsExtSel];
                [idInv setArgument:&nsExtObj atIndex:2];
                [idInv setArgument:&idError atIndex:3];
                [idInv invoke];

                __unsafe_unretained id result = nil;
                [idInv getReturnValue:&result];
                NSLog(@"[IdentityHelper] Identity from NSExtension: %@ error: %@", result, idError);
                if (result) return result;
            }
        }
    }

    if (outError) *outError = [NSError errorWithDomain:@"Phosphene" code:10
        userInfo:@{NSLocalizedDescriptionKey: @"All identity creation methods failed"}];
    return nil;
}

void SetIvarAtOffset(id target, NSInteger offset, id value) {
    void *basePtr = (__bridge void *)target;
    void **slot = (void **)((uint8_t *)basePtr + offset);
    id oldValue = (__bridge id)(*slot);
    (void)oldValue;
    *slot = (__bridge_retained void *)value;
}

void DumpIdentity(id identity) {
    if (!identity) return;
    Class cls = object_getClass(identity);
    NSLog(@"[identity] class: %@", NSStringFromClass(cls));

    SEL selectors[] = {
        NSSelectorFromString(@"serviceName"),
        NSSelectorFromString(@"bundleIdentifier"),
        NSSelectorFromString(@"bundleVersion"),
        NSSelectorFromString(@"extensionPointIdentifier"),
        NSSelectorFromString(@"uniqueIdentifier"),
    };
    for (int i = 0; i < sizeof(selectors)/sizeof(selectors[0]); i++) {
        if ([identity respondsToSelector:selectors[i]]) {
            id val = [identity performSelector:selectors[i]];
            NSLog(@"[identity] %@: %@", NSStringFromSelector(selectors[i]), val);
        }
    }
}
