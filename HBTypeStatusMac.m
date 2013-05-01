#import "HBTypeStatusMac.h"

@implementation HBTypeStatusMac
static HBTypeStatusMac *sharedInstance;

+(void)load {
	HBTypeStatusMac *myself = [HBTypeStatusMac sharedInstance];

	myself->_statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	myself->_statusItem.length = 0;
	myself->_statusItem.image = [[NSBundle bundleForClass:self.class] imageForResource:@"TypeStatus.tiff"];
	myself->_statusItem.image.size = NSMakeSize(18.f, 18.f);
}

-(void)setIconVisible:(BOOL)iconVisible withName:(NSString *)name {
	_statusItem.length = iconVisible ? -1 : 0;
	_statusItem.title = iconVisible ? name : nil;
}

+(HBTypeStatusMac *)sharedInstance {
	if (!sharedInstance) {
		sharedInstance = [[HBTypeStatusMac alloc] init];
	}

	return sharedInstance;
}

@end
