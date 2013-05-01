#import <Cocoa/Cocoa.h>

@interface HBTypeStatusMac : NSObject {
	NSStatusItem *_statusItem;
	NSImage *_icon;
}

+(HBTypeStatusMac *)sharedInstance;
-(void)setIconVisible:(BOOL)iconVisible withName:(NSString *)name;
@end
