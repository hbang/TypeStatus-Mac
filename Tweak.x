@import Cocoa;
#import <IMCore/IMAccount.h>
#import <IMCore/IMChat.h>
#import <IMCore/IMHandle.h>
#import <IMCore/IMServiceImpl.h>
#import <IMFoundation/FZMessage.h>
#import <version.h>

static NSBundle *bundle;
static NSStatusItem *statusItem;
static NSUserDefaults *userDefaults;

static NSUInteger typingIndicators = 0;
static NSMutableSet *acknowledgedReadReceipts;
static NSString *currentSenderGUID;

#pragma mark - Contact names

static NSString *nameForHandle(NSString *address) {
	IMAccount *account = IMPreferredSendingAccountForAddressesWithFallbackService(@[ address ], [IMServiceImpl iMessageService]);

	if (!account._isUsableForSending) {
		return address;
	}

	IMHandle *handle = [account imHandleWithID:address];
	return handle._displayNameWithAbbreviation ?: address;
}

#pragma mark - DND support

static BOOL isDNDActive() {
	// the notification center do not disturb state is stored in NotificationCenterUI’s prefs
	CFTypeRef value = CFPreferencesCopyValue(CFSTR("doNotDisturb"), CFSTR("com.apple.notificationcenterui"), kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	NSNumber *objcValue = (NSNumber *)CFBridgingRelease(value);
	return objcValue && objcValue.boolValue;
}

#pragma mark - Status item stuff

static void setStatus(HBTSStatusBarType type, NSString *handle, NSString *guid) {
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

	// if this is an empty alert (notification ended), or DND is active, clear out the item and return
	if (type == HBTSStatusBarTypeEmpty || isDNDActive()) {
		statusItem.length = 0;
		statusItem.title = nil;
		statusItem.attributedTitle = nil;
		currentSenderGUID = nil;
		return;
	}

	// set the appropriate icon
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

	if (!guid) {
		// if the guid is nil, just take a guess
		// TODO: this could be smarter?
		guid = [NSString stringWithFormat:@"iMessage;-;%@", handle];
	}

	// set all our parameters. length -1 means auto-size
	currentSenderGUID = guid;
	statusItem.title = nameForHandle(handle);
	statusItem.length = -1;
}

@interface HBTSStatusBarHandler : NSObject

@end

@implementation HBTSStatusBarHandler

+ (void)statusBarItemClicked {
	NSURLComponents *url = [NSURLComponents componentsWithString:@"ichat:openchat"];
	url.queryItems = @[ [NSURLQueryItem queryItemWithName:@"guid" value:currentSenderGUID] ];
	[[NSWorkspace sharedWorkspace] openURL:url.URL];
}

@end

#pragma mark - Typing detection

%hook IMChatRegistry

- (void)_processMessageForAccount:(id)account chat:(IMChat *)chat style:(unsigned char)style chatProperties:(id)properties message:(FZMessage *)message {
	%orig;

	if (message.flags == (IMMessageItemFlags)4104) {
		typingIndicators++;

		setStatus(HBTSStatusBarTypeTyping, message.handle, chat.guid);

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kHBTSTypingTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			setStatus(HBTSStatusBarTypeEmpty, nil, nil);
		});
	} else {
		if (typingIndicators == 0) {
			return;
		}

		typingIndicators--;

		if (typingIndicators == 0) {
			setStatus(HBTSStatusBarTypeEmpty, nil, nil);
		}
	}
}

- (void)_account:(id)account chat:(IMChat *)chat style:(unsigned char)style chatProperties:(id)properties messagesUpdated:(NSArray <FZMessage *> *)messages {
	%orig;

	BOOL hasRead = NO;

	// loop over the updated messages. if we see one that isRead and hasn’t yet been seen, add it to
	// our set and show an alert
	for (FZMessage *message in messages) {
		if (message.isRead && ![acknowledgedReadReceipts containsObject:message.guid]) {
			hasRead = YES;
			[acknowledgedReadReceipts addObject:message.guid];
			setStatus(HBTSStatusBarTypeRead, message.handle, chat.guid);
		}
	}

	// if we got one, do our timeout to unset the alert
	if (hasRead) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([userDefaults doubleForKey:kHBTSPreferencesDurationKey] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			setStatus(HBTSStatusBarTypeEmpty, nil, nil);
		});
	}
}

%end

#pragma mark - Constructor

%ctor {
	%init;

	bundle = [NSBundle bundleWithIdentifier:@"ws.hbang.typestatus.mac"];
	acknowledgedReadReceipts = [NSMutableSet set];
	currentSenderGUID = nil;

	userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kHBTSPreferencesSuiteName];
	[userDefaults registerDefaults:@{
		kHBTSPreferencesDurationKey: @5.0,
		kHBTSPreferencesInvertedKey: @NO
	}];

	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	statusItem.button.target = HBTSStatusBarHandler.class;
	statusItem.button.action = @selector(statusBarItemClicked);
}
