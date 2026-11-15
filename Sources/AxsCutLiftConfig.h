#pragma once

#import <Foundation/Foundation.h>

@interface AxsCutLiftConfig : NSObject
+ (instancetype)axs_cutlift_shared;
- (BOOL)axs_cutlift_isEnabled;
- (id)axs_cutlift_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (void)axs_cutlift_reload;
@end
