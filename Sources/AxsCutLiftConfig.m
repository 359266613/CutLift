#import "AxsCutLiftConfig.h"
#import "AxsCutLiftPreferences.h"

@interface AxsCutLiftConfig ()
@property (atomic, copy) NSDictionary *snapshot;
@property (nonatomic, strong) dispatch_queue_t reloadQueue;
@end

static void axs_cutlift_preferencesDidChange(CFNotificationCenterRef center, void *observer,
                                          CFStringRef name, const void *object, CFDictionaryRef info) {
    AxsCutLiftConfig *config = (__bridge AxsCutLiftConfig *)observer;
    dispatch_async(config.reloadQueue, ^{
        [config axs_cutlift_reload];
    });
}

@implementation AxsCutLiftConfig

+ (instancetype)axs_cutlift_shared {
    static AxsCutLiftConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reloadQueue = dispatch_queue_create("com.axs.cutlift.preferences", DISPATCH_QUEUE_SERIAL);
        [self axs_cutlift_reload];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self, axs_cutlift_preferencesDidChange,
            (__bridge CFStringRef)AxsCutLiftPreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        // Close the window between the first read and observer registration.
        dispatch_async(_reloadQueue, ^{ [self axs_cutlift_reload]; });
    }
    return self;
}

- (void)axs_cutlift_reload {
    self.snapshot = axs_cutlift_readPreferences();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:AxsCutLiftPreferencesChanged object:self];
    });
}

- (id)axs_cutlift_valueForKey:(NSString *)key defaultValue:(id)defaultValue {
    return self.snapshot[key] ?: defaultValue;
}

- (BOOL)axs_cutlift_isEnabled {
    id value = [self axs_cutlift_valueForKey:@"enabled" defaultValue:@(NO)];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

- (void)dealloc {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (__bridge const void *)self);
}

@end
