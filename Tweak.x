#import <AppKit/AppKit.h>
#import <IMCore/IMAccount.h>
#import <IMCore/IMHandle.h>
#import <IMCore/IMServiceImpl.h>
#import <IMFoundation/FZMessage.h>
#import <version.h>

static NSBundle *bundle;
static NSStatusItem *statusItem;
static NSUserDefaults *userDefaults;

static NSUInteger typingIndicators = 0;
static NSMutableSet *acknowledgedReadReceipts;

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

static NSString *nameForHandle(NSString *address) {
	IMAccount *account = IMPreferredSendingAccountForAddressesWithFallbackService(@[ address ], [IMServiceImpl iMessageService]);

	if (!account._isUsableForSending) {
		return address;
	}

	IMHandle *handle = [account imHandleWithID:address];
	return handle._displayNameWithAbbreviation ?: address;
}

#pragma mark - Status item stuff

static void setStatus(HBTSStatusBarType type, NSString *handle) {
	static NSImage *TypingIcon;
	static NSImage *ReadIcon;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		TypingIcon = [bundle imageForResource:@"Typing.tiff"];
		[TypingIcon setTemplate:YES]; // eugh. dot notation doesn’t work for this
		TypingIcon.size = CGSizeMake(22.f, 22.f);

		ReadIcon = [bundle imageForResource:@"Read.tiff"];
		[ReadIcon setTemplate:YES];
		ReadIcon.size = CGSizeMake(22.f, 22.f);
	});

	if (type == HBTSStatusBarTypeEmpty) {
		statusItem.length = 0;
		statusItem.title = nil;
		statusItem.attributedTitle = nil;
		return;
	}

	statusItem.title = HBTSNameForHandle(handle);

	switch (type) {
		case HBTSStatusBarTypeTyping:
			statusItem.image = TypingIcon;
			break;

		case HBTSStatusBarTypeRead:
			statusItem.image = ReadIcon;
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

	if (message.flags == (IMMessageItemFlags)4104) {
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

- (void)_account:(id)arg1 chat:(id)arg2 style:(unsigned char)arg3 chatProperties:(id)arg4 messagesUpdated:(NSArray <FZMessage *> *)messages {
	%orig;

	BOOL hasRead = NO;

	for (FZMessage *message in messages) {
		if (message.isRead && ![acknowledgedReadReceipts containsObject:message.guid]) {
			hasRead = YES;
			[acknowledgedReadReceipts addObject:message.guid];
			HBTSSetStatus(HBTSStatusBarTypeRead, message.handle);
		}
	}

	if (hasRead) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([userDefaults doubleForKey:kHBTSPreferencesDurationKey] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			HBTSSetStatus(HBTSStatusBarTypeEmpty, nil);
		});
	}
}

%end

#pragma mark - First run

static void showFirstRunAlert() {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = @"Welcome to TypeStatus";
	alert.informativeText = @"You’ll now see subtle notifications in your menu bar when someone is typing an iMessage to you or reads an iMessage you sent.\nIf you like TypeStatus, don’t forget to let your friends know about it!";

	[alert runModal];

	[userDefaults setObject:bundle.infoDictionary[@"CFBundleVersion"] forKey:kHBTSPreferencesLastVersionKey];
	[userDefaults setBool:alert.suppressionButton.state == NSOnState forKey:kHBTSPreferencesInvertedKey];
}

#pragma mark - Updates

static void checkUpdate() {
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
				NSAlert *alert = [[NSAlert alloc] init];
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

	bundle = [NSBundle bundleWithIdentifier:@"ws.hbang.typestatus.mac"];
	acknowledgedReadReceipts = [NSMutableSet set];

	userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kHBTSPreferencesSuiteName];
	[userDefaults registerDefaults:@{
		kHBTSPreferencesDurationKey: @5.0,
		kHBTSPreferencesInvertedKey: @NO
	}];

	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

	if (![userDefaults objectForKey:kHBTSPreferencesLastVersionKey]) {
		showFirstRunAlert();
	}

	checkUpdate();
}
