//
// UIScrollView+SVInfiniteScrolling.h
//
// Created by Sam Vermette on 23.04.12.
// Copyright (c) 2012 samvermette.com. All rights reserved.
//
// https://github.com/samvermette/SVPullToRefresh
//

#import <UIKit/UIKit.h>

@class SVInfiniteScrollingView;

typedef NS_ENUM(NSInteger, SVInfiniteScrollingDirection) {
    SVInfiniteScrollingDirectionVertical = 0,
    SVInfiniteScrollingDirectionBottom = 0,
    SVInfiniteScrollingDirectionTop = 1,
    SVInfiniteScrollingDirectionHorizontal = 2,
    SVInfiniteScrollingDirectionLeft = 2,
    SVInfiniteScrollingDirectionRight = 3
};

@interface UIScrollView (SVInfiniteScrolling)

- (void)addInfiniteScrollingWithActionHandler:(void (^)(void))actionHandler;
/** 
@warning If you use SVInfiniteScrollingDirectionTop in UITableView you shouldnt use animation for cells actions (it)
 */
- (void)addInfiniteScrollingWithScrollingDiretion:(SVInfiniteScrollingDirection)direction actionHandler:(void (^)(void))actionHandler;
- (void)triggerInfiniteScrolling;
- (SVInfiniteScrollingView *)infiniteScrollingViewAtDirection:(SVInfiniteScrollingDirection)direction;
- (void)setShowsInfiniteScrolling:(BOOL)showsInfiniteScrolling atDirection:(SVInfiniteScrollingDirection)direction;

@property (nonatomic, strong, readonly) SVInfiniteScrollingView *infiniteScrollingView;
@property (nonatomic, assign) BOOL showsInfiniteScrolling;

@end


enum {
	SVInfiniteScrollingStateStopped = 0,
    SVInfiniteScrollingStateTriggered,
    SVInfiniteScrollingStateLoading,
    SVInfiniteScrollingStateAll = 10
};

typedef NSUInteger SVInfiniteScrollingState;

@interface SVInfiniteScrollingView : UIView

@property (nonatomic, readwrite) UIActivityIndicatorViewStyle activityIndicatorViewStyle;
@property (nonatomic, readonly) SVInfiniteScrollingState state;
@property (nonatomic, readonly) SVInfiniteScrollingDirection direction;
@property (nonatomic, readwrite) BOOL enabled;

- (void)setCustomView:(UIView *)view forState:(SVInfiniteScrollingState)state;

- (void)startAnimating;
- (void)stopAnimating;

@end
