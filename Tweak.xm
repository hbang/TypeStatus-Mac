#import <AppKit/AppKit.h>
#import <IMCore/IMAccount.h>
#import <IMCore/IMHandle.h>
#import <IMCore/IMServiceImpl.h>
#import <IMFoundation/FZMessage.h>

NSString *prefsPath;
NSBundle *bundle;
NSStatusItem *statusItem;
NSImage *typingIcon;
NSImage *readIcon;

NSUInteger typingIndicators = 0;

BOOL inverted = NO;
NSTimeInterval duration = 0;

#pragma mark - Constants

typedef NS_ENUM(NSUInteger, HBTSStatusBarType) {
	HBTSStatusBarTypeTyping,
	HBTSStatusBarTypeRead,
	HBTSStatusBarTypeEmpty
};

static NSString *const kHBTSPrefsLastVersion = @"LastVersion";
static NSString *const kHBTSPrefsInvertedKey = @"Inverted";
static NSString *const kHBTSPrefsDurationKey = @"OverlayDuration";

static NSTimeInterval const kHBTSTypingTimeout = 60;

#pragma mark - Contact names

NSString *HBTSNameForHandle(NSString *address) {
	IMAccount *account = IMPreferredSendingAccountForAddressesWithFallbackService(@[ address ], [IMServiceImpl iMessageService]);

	if (!account._isUsableForSending) {
		return address;
	}

	IMHandle *handle = [account imHandleWithID:address];
	return handle._displayNameWithAbbreviation ?: address;
}

#pragma mark - Status item stuff

void HBTSSetStatus(HBTSStatusBarType type, NSString *handle) {
	switch (type) {
		case HBTSStatusBarTypeTyping:
			statusItem.image = typingIcon;
			break;

		case HBTSStatusBarTypeRead:
			statusItem.image = readIcon;
			break;

		case HBTSStatusBarTypeEmpty:
			statusItem.length = 0;
			statusItem.attributedTitle = nil;
			return;
			break;
	}

	statusItem.length = -1;
	statusItem.attributedTitle = [[[NSAttributedString alloc] initWithString:HBTSNameForHandle(handle) attributes:@{
		NSFontAttributeName: [NSFont menuBarFontOfSize:0],
		NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:inverted ? 0.7490196078f : 0 alpha:1]
	}] autorelease];
}

#pragma mark - Typing detection

%hook IMChatRegistry

- (void)_processMessageForAccount:(id)account chat:(id)chat style:(unsigned char)style chatProperties:(id)properties message:(FZMessage *)message {
	%orig;

	if (message.flags == 4104) {
		typingIndicators++;

		HBTSSetStatus(HBTSStatusBarTypeTyping, message.handle);

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kHBTSTypingTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			HBTSSetStatus(HBTSStatusBarTypeEmpty, nil);
		});
	} else {
		if (typingIndicators == 0) {
			return;
		}

		typingIndicators--;

		if (typingIndicators == 0) {
			HBTSSetStatus(HBTSStatusBarTypeEmpty, nil);
		}
	}
}

%end


%hook FZMessage

- (void)setTimeRead:(NSDate *)timeRead {
	%orig;

	if (!self.sender && [[NSDate date] timeIntervalSinceDate:self.timeRead] < 1) {
		HBTSSetStatus(HBTSStatusBarTypeRead, self.handle);

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			HBTSSetStatus(HBTSStatusBarTypeEmpty, nil);
		});
	}
}

%end

#pragma mark - First run

void HBTSLoadPrefs();

void HBTSShowFirstRunAlert() {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	alert.messageText = @"Welcome to TypeStatus";
	alert.informativeText = @"This is a preview of TypeStatus for Mac. Please send bug reports and feedback to support@hbang.ws.";
	alert.showsSuppressionButton = YES;
	alert.suppressionButton.title = @"I use a dark menu bar theme";
	[alert runModal];

	[@{
		kHBTSPrefsLastVersion: @"1.0~beta2",
		kHBTSPrefsInvertedKey: @(alert.suppressionButton.state == NSOnState)
	} writeToFile:prefsPath atomically:YES];

	HBTSLoadPrefs();
}

#pragma mark - Preferences

void HBTSLoadPrefs() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:prefsPath];

	[typingIcon release];
	[readIcon release];

	inverted = GET_BOOL(kHBTSPrefsInvertedKey, NO);
	duration = GET_FLOAT(kHBTSPrefsDurationKey, 5);

	typingIcon = [[bundle imageForResource:inverted ? @"TypingInverted.png" : @"Typing.png"] retain];
	readIcon = [[bundle imageForResource:inverted ? @"ReadInverted.png" : @"Read.png"] retain];

	typingIcon.size = CGSizeMake(22.f, 22.f);
	readIcon.size = CGSizeMake(22.f, 22.f);

	if (!prefs) {
		HBTSShowFirstRunAlert();
	}
}

#pragma mark - Updates

void HBTSCheckUpdate() {
	NSString *currentVersion = bundle.infoDictionary[@"CFBundleShortVersionString"];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSData *data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://cdn.hbang.ws/updates/typestatusmac.json?version=%@", currentVersion]] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30] returningResponse:nil error:nil];

		if (!data || !data.length) {
			NSLog(@"update check failed - no data received");
			return;
		}

		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];

		if (!json) {
			NSLog(@"json deserialization failed");
			return;
		}

		if (![json[@"version"] isEqualToString:currentVersion]) {
			dispatch_async(dispatch_get_main_queue(), ^{
				NSAlert *alert = [[[NSAlert alloc] init] autorelease];
				alert.messageText = @"A TypeStatus update is available";
				alert.informativeText = [NSString stringWithFormat:@"The new version is %@. You have version %@.", json[@"version"], currentVersion];
				[alert addButtonWithTitle:@"Install"];
				[alert addButtonWithTitle:@"No Thanks"];

				if ([alert runModal] == NSAlertFirstButtonReturn) {
					[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:json[@"url"]]];
				}
			});
		}
	});
}

#pragma mark - Constructor

%ctor {
	%init;

	prefsPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/ws.hbang.typestatusmac.plist"] retain];
	bundle = [[NSBundle bundleWithIdentifier:@"ws.hbang.typestatus.mac"] retain];

	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];

	HBTSLoadPrefs();
	HBTSCheckUpdate();
}
