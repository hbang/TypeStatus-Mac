#import <AppKit/AppKit.h>
#import <IMCore/IMAccount.h>
#import <IMCore/IMHandle.h>
#import <IMCore/IMServiceImpl.h>
#import <IMFoundation/FZMessage.h>
#import <version.h>

NSBundle *bundle;
NSStatusItem *statusItem;
NSUserDefaults *userDefaults;

NSUInteger typingIndicators = 0;

#pragma mark - Constants

typedef NS_ENUM(NSUInteger, HBTSStatusBarType) {
	HBTSStatusBarTypeTyping,
	HBTSStatusBarTypeRead,
	HBTSStatusBarTypeEmpty
};

static NSString *const kHBTSPreferencesSuiteName = @"ws.hbang.typestatusmac";
static NSString *const kHBTSPreferencesLastVersionKey = @"LastVersion";
static NSString *const kHBTSPreferencesInvertedKey = @"Inverted";
static NSString *const kHBTSPreferencesDurationKey = @"OverlayDuration";

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

#pragma mark - Tint image

NSImage *HBTSTintImageWithColor(NSImage *image, NSColor *color) {
	// https://stackoverflow.com/a/16138027/709376
	NSImage *newImage = [[image copy] autorelease];
	[newImage lockFocus];
	[color set];
	NSRectFillUsingOperation((NSRect){ NSZeroPoint, newImage.size }, NSCompositeSourceAtop);
	[newImage unlockFocus];
	return newImage;
}

#pragma mark - Status item stuff

void HBTSSetStatus(HBTSStatusBarType type, NSString *handle) {
	static NSImage *TypingIcon;
	static NSImage *TypingIconInverted;
	static NSImage *ReadIcon;
	static NSImage *ReadIconInverted;
	static NSImage *EmptyIcon;
	static NSImage *EmptyIconInverted;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		TypingIcon = [[bundle imageForResource:@"Typing.tiff"] retain];
		[TypingIcon setTemplate:YES]; // eugh. dot notation doesn't work for this.
		TypingIcon.size = CGSizeMake(22.f, 22.f);

		ReadIcon = [[bundle imageForResource:@"Read.tiff"] retain];
		[ReadIcon setTemplate:YES];
		ReadIcon.size = CGSizeMake(22.f, 22.f);

		EmptyIcon = [[bundle imageForResource:@"Empty.tiff"] retain];
		[EmptyIcon setTemplate:YES];
		EmptyIcon.size = CGSizeMake(22.f, 22.f);

		if (!IS_OSX_OR_NEWER(10_10)) {
			TypingIconInverted = [HBTSTintImageWithColor(TypingIcon, [NSColor whiteColor]) retain];
			ReadIconInverted = [HBTSTintImageWithColor(ReadIcon, [NSColor whiteColor]) retain];
			EmptyIconInverted = [HBTSTintImageWithColor(EmptyIcon, [NSColor whiteColor]) retain];
		}
	});

	BOOL inverted = !IS_OSX_OR_NEWER(10_10) && [userDefaults boolForKey:kHBTSPreferencesInvertedKey];

	if (type == HBTSStatusBarTypeEmpty) {
		statusItem.length = -1;
		statusItem.title = nil;
		statusItem.attributedTitle = nil;
		statusItem.image = inverted ? EmptyIconInverted : EmptyIcon;
		return;
	}

	NSString *name = HBTSNameForHandle(handle);

	if (IS_OSX_OR_NEWER(10_10)) {
		statusItem.title = name; // It Just Works(tm)
	} else {
		statusItem.attributedTitle = [[[NSAttributedString alloc] initWithString:name attributes:@{
			NSFontAttributeName: [NSFont menuBarFontOfSize:0],
			NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:inverted ? 0.7490196078f : 0 alpha:1]
		}] autorelease];
	}

	switch (type) {
		case HBTSStatusBarTypeTyping:
			statusItem.image = inverted ? TypingIconInverted : TypingIcon;
			break;

		case HBTSStatusBarTypeRead:
			statusItem.image = inverted ? ReadIconInverted : ReadIcon;
			break;

		case HBTSStatusBarTypeEmpty:
			break;
	}

	statusItem.length = -1;
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

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([userDefaults doubleForKey:kHBTSPreferencesDurationKey] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			HBTSSetStatus(HBTSStatusBarTypeEmpty, nil);
		});
	}
}

%end

#pragma mark - First run

void HBTSShowFirstRunAlert() {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	alert.messageText = @"Welcome to TypeStatus";
	alert.informativeText = @"You’ll now see subtle notifications in your menu bar when someone is typing an iMessage to you or reads an iMessage you sent.\nIf you like TypeStatus, don’t forget to let your friends know about it!";

	if (!IS_OSX_OR_NEWER(10_10)) {
		alert.showsSuppressionButton = YES;
		alert.suppressionButton.title = @"I use a dark menu bar theme";
	}

	[alert runModal];

	[userDefaults setObject:bundle.infoDictionary[@"CFBundleVersion"] forKey:kHBTSPreferencesLastVersionKey];
	[userDefaults setBool:alert.suppressionButton.state == NSOnState forKey:kHBTSPreferencesInvertedKey];
}

#pragma mark - Updates

void HBTSCheckUpdate() {
	NSString *currentVersion = bundle.infoDictionary[@"CFBundleShortVersionString"];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSData *data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://cdn.hbang.ws/updates/typestatusmac.json?version=%@", currentVersion]] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30] returningResponse:nil error:nil];

		if (!data || !data.length) {
			NSLog(@"TypeStatus: update check failed - no data received");
			return;
		}

		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];

		if (!json) {
			NSLog(@"TypeStatus: json deserialization failed");
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

	bundle = [[NSBundle bundleWithIdentifier:@"ws.hbang.typestatus.mac"] retain];
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kHBTSPreferencesSuiteName];
	[userDefaults registerDefaults:@{
		kHBTSPreferencesDurationKey: @5.0,
		kHBTSPreferencesInvertedKey: @NO
	}];

	if (![userDefaults objectForKey:kHBTSPreferencesLastVersionKey]) {
		HBTSShowFirstRunAlert();
	}
	HBTSSetStatus(HBTSStatusBarTypeEmpty, nil);
	HBTSCheckUpdate();
}
