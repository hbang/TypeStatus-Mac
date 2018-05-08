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
