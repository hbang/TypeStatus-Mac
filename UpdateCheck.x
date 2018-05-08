@import Cocoa;

static NSUserDefaults *userDefaults;

#pragma mark - First run

static void showFirstRunAlert() {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = @"Welcome to TypeStatus";
	alert.informativeText = @"You’ll now see subtle notifications in your menu bar when someone is typing an iMessage to you or reads an iMessage you sent.\nIf you like TypeStatus, don’t forget to let your friends know about it!";
	[alert runModal];
}

#pragma mark - Updates

static void checkUpdate() {
	NSBundle *bundle = [NSBundle bundleWithIdentifier:@"ws.hbang.typestatus.mac"];

	[userDefaults setObject:bundle.infoDictionary[@"CFBundleVersion"] forKey:kHBTSPreferencesLastVersionKey];

	NSString *currentVersion = bundle.infoDictionary[@"CFBundleShortVersionString"];
	NSString *messagesVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];

	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://cdn.hbang.ws/updates/typestatusmac.json?version=%@", currentVersion]] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30];
	
	NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (!data || !data.length) {
			HBLogWarn(@"update check failed — no data received");
			return;
		}

		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];

		if (!json) {
			HBLogWarn(@"json deserialization failed");
			return;
		}

		// if the version we got back is newer, and can be installed on this version of messages, show
		// our update prompt
		if ([json[@"version"] compare:currentVersion options:NSNumericSearch] == NSOrderedDescending
			&& [json[@"minimumMessagesVersion"] compare:messagesVersion options:NSNumericSearch] != NSOrderedAscending) {
			dispatch_async(dispatch_get_main_queue(), ^{
				NSAlert *alert = [[NSAlert alloc] init];
				alert.messageText = @"A TypeStatus update is available";
				alert.informativeText = [NSString stringWithFormat:@"The new version is %@. You have version %@.", json[@"version"], currentVersion];
				[alert addButtonWithTitle:@"Install"];
				[alert addButtonWithTitle:@"No Thanks"];

				// if the user selected the first button (install), open the url we got
				if ([alert runModal] == NSAlertFirstButtonReturn) {
					[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:json[@"url"]]];
				}
			});
		}
	}];

	[task resume];
}

#pragma mark - Constructor

%ctor {
	userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kHBTSPreferencesSuiteName];
	[userDefaults registerDefaults:@{
		kHBTSPreferencesDurationKey: @5.0,
		kHBTSPreferencesInvertedKey: @NO
	}];

	if (![userDefaults objectForKey:kHBTSPreferencesLastVersionKey]) {
		showFirstRunAlert();
	}

	checkUpdate();
}
