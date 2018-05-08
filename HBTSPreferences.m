#import "HBTSPreferences.h"

static NSString *const kHBTSPreferencesSuiteName = @"ws.hbang.typestatusmac";

@implementation HBTSPreferences

+ (instancetype)sharedInstance {
	static HBTSPreferences *sharedInstance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});

	return sharedInstance;
}

- (id)_objectForKey:(NSString *)key default:(id)defaultValue {
	CFTypeRef value = CFPreferencesCopyValue((__bridge CFStringRef)key, (__bridge CFStringRef)kHBTSPreferencesSuiteName, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	id objcValue = CFBridgingRelease(value);
	return objcValue ?: defaultValue;
}

- (void)_setObject:(id)value forKey:(NSString *)key {
	CFPreferencesSetValue((__bridge CFStringRef)key, (__bridge CFTypeRef)value, (__bridge CFStringRef)kHBTSPreferencesSuiteName, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}

- (NSTimeInterval)displayDuration {
	return ((NSNumber *)[self _objectForKey:@"OverlayDuration" default:@5.0]).doubleValue;
}

- (NSString *)lastVersion {
	return [self _objectForKey:@"LastVersion" default:nil];
}

- (void)setLastVersion:(NSString *)lastVersion {
	[self _setObject:lastVersion forKey:@"LastVersion"];
}

@end
