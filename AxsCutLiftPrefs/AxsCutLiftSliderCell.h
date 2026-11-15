#pragma once

#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>
#include <math.h>

@protocol AxsCutLiftSliderCellHandler <NSObject>
- (double)axs_cutlift_sliderValueForSpecifier:(PSSpecifier *)specifier;
- (void)axs_cutlift_setSliderValue:(double)value specifier:(PSSpecifier *)specifier;
@end

@interface AxsCutLiftSliderCell : PSTableCell
@property (nonatomic, weak) id<AxsCutLiftSliderCellHandler> handler;
- (void)axs_cutlift_reloadState;
@end
