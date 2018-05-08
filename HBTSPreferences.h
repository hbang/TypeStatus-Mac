@interface HBTSPreferences : NSObject

+ (instancetype)sharedInstance;

@property (readonly) NSTimeInterval displayDuration;
@property (nonatomic, strong) NSString *lastVersion;

@end
