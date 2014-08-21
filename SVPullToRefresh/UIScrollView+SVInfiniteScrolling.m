//
// UIScrollView+SVInfiniteScrolling.m
//
// Created by Sam Vermette on 23.04.12.
// Copyright (c) 2012 samvermette.com. All rights reserved.
//
// https://github.com/samvermette/SVPullToRefresh
//

#import <QuartzCore/QuartzCore.h>
#import "UIScrollView+SVInfiniteScrolling.h"


static CGFloat const SVInfiniteScrollingViewHeight = 60;
static CGFloat const SVInfiniteScrollingViewWidth = 60;

@interface SVInfiniteScrollingDotView : UIView

@property (nonatomic, strong) UIColor *arrowColor;

@end

@interface SVInfiniteScrollingView ()

@property (nonatomic, copy) void (^infiniteScrollingHandler)(void);

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, readwrite) SVInfiniteScrollingState state;
@property (nonatomic, readwrite) SVInfiniteScrollingDirection direction;
@property (nonatomic, strong) NSMutableArray *viewForState;
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, readwrite) CGFloat originalBottomInset;
@property (nonatomic, readwrite) CGFloat originalTopInset;
@property (nonatomic, readwrite) CGFloat originalLeftInset;
@property (nonatomic, readwrite) CGFloat originalRightInset;
@property (nonatomic, assign) BOOL wasTriggeredByUser;
@property (nonatomic, assign) BOOL isObserving;
@property (nonatomic, assign) BOOL wasRecentlyTriggered;
@property (nonatomic) CGFloat lastContentOffsetY;

- (void)resetScrollViewContentInset;
- (void)resetScrollViewContentInsetAnimated:(BOOL)animated;
- (void)setScrollViewContentInsetForInfiniteScrolling;
- (void)setScrollViewContentInsetForInfiniteScrollingAnimated:(BOOL)animated;
- (void)setScrollViewContentInset:(UIEdgeInsets)insets;

@end



#pragma mark - UIScrollView (SVInfiniteScrollingView)
#import <objc/runtime.h>

static int SVInfiniteScrollingViewObservationContext;
static char UIScrollViewInfiniteScrollingView;
static char UIScrollViewInfiniteScrollingViewsDictionary;
UIEdgeInsets scrollViewOriginalContentInsets;

@interface UIScrollView()

@property (nonatomic, strong) NSMutableDictionary *infiniteScrollingViewsDictionary;

@end

@implementation UIScrollView (SVInfiniteScrolling)

@dynamic infiniteScrollingView;

-(SVInfiniteScrollingView *)infiniteScrollingViewAtDirection:(SVInfiniteScrollingDirection)direction{
    return self.infiniteScrollingViewsDictionary[@(direction)];
}

- (void)addInfiniteScrollingWithActionHandler:(void (^)(void))actionHandler {
    [self addInfiniteScrollingWithScrollingDiretion:SVInfiniteScrollingDirectionBottom actionHandler:actionHandler];
}

- (void)addInfiniteScrollingWithScrollingDiretion:(SVInfiniteScrollingDirection)direction actionHandler:(void (^)(void))actionHandler {
    
    if(!self.infiniteScrollingViewsDictionary){
        self.infiniteScrollingViewsDictionary = [NSMutableDictionary dictionary];
    }
    
    if(![self infiniteScrollingViewAtDirection:direction]) {
        CGFloat yOrigin = 0;
        CGFloat xOrigin = 0;
        switch (direction) {
            case SVInfiniteScrollingDirectionBottom:
                yOrigin = self.contentSize.height;
                break;
            case SVInfiniteScrollingDirectionTop:
                yOrigin = -SVInfiniteScrollingViewHeight;
                break;
            case SVInfiniteScrollingDirectionRight:
                xOrigin = self.contentSize.width;
                break;
            case SVInfiniteScrollingDirectionLeft:
                xOrigin = -SVInfiniteScrollingViewWidth;
        }
        SVInfiniteScrollingView *view = [[SVInfiniteScrollingView alloc]
                                         initWithFrame:CGRectMake(xOrigin, yOrigin,
                                                                  (direction < SVInfiniteScrollingDirectionHorizontal) ? self.bounds.size.width : SVInfiniteScrollingViewWidth,
                                                                  (direction >= SVInfiniteScrollingDirectionHorizontal) ? self.bounds.size.height : SVInfiniteScrollingViewHeight)];
        view.infiniteScrollingHandler = actionHandler;
        view.scrollView = self;
        view.direction = direction;
        [self addSubview:view];
        
        view.originalTopInset = self.contentInset.top;
        view.originalBottomInset = self.contentInset.bottom;
        view.originalLeftInset = self.contentInset.left;
        view.originalRightInset = self.contentInset.right;
        self.infiniteScrollingViewsDictionary[@(direction)] = view;
        [self setShowsInfiniteScrolling:YES atDirection:direction animated:NO];
    }
}

- (void)triggerInfiniteScrolling {
    [self triggerInfiniteScrollingAtDirection:SVInfiniteScrollingDirectionBottom];
}

- (void)triggerInfiniteScrollingAtDirection:(SVInfiniteScrollingDirection)direction {
    [self infiniteScrollingViewAtDirection:direction].state = SVInfiniteScrollingStateTriggered;
    [[self infiniteScrollingViewAtDirection:direction] startAnimating];
}

- (void)setInfiniteScrollingViewsDictionary:(NSMutableDictionary *)infiniteScrollingViewsDictionary{
    objc_setAssociatedObject(self, &UIScrollViewInfiniteScrollingViewsDictionary,
                             infiniteScrollingViewsDictionary,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)infiniteScrollingViewsDictionary{
    return objc_getAssociatedObject(self, &UIScrollViewInfiniteScrollingViewsDictionary);
}

- (void)setInfiniteScrollingView:(SVInfiniteScrollingView *)infiniteScrollingView {
    [self willChangeValueForKey:@"UIScrollViewInfiniteScrollingView"];
    if(infiniteScrollingView){
        self.infiniteScrollingViewsDictionary[@(SVInfiniteScrollingDirectionBottom)] = infiniteScrollingView;
    }
    else{
        [self.infiniteScrollingViewsDictionary removeObjectForKey:@(SVInfiniteScrollingDirectionBottom)];
    }
    [self didChangeValueForKey:@"UIScrollViewInfiniteScrollingView"];
}

- (SVInfiniteScrollingView *)infiniteScrollingView {
    return self.infiniteScrollingViewsDictionary[@(SVInfiniteScrollingDirectionBottom)];//objc_getAssociatedObject(self, &UIScrollViewInfiniteScrollingView);
}

- (void)setShowsInfiniteScrolling:(BOOL)showsInfiniteScrolling{
    [self setShowsInfiniteScrolling:showsInfiniteScrolling atDirection:SVInfiniteScrollingDirectionBottom];
}

- (void)setShowsInfiniteScrolling:(BOOL)showsInfiniteScrolling atDirection:(SVInfiniteScrollingDirection)direction{
    [self setShowsInfiniteScrolling:showsInfiniteScrolling atDirection:direction animated:YES];
}

- (void)setShowsInfiniteScrolling:(BOOL)showsInfiniteScrolling atDirection:(SVInfiniteScrollingDirection)direction animated:(BOOL)animated{
    SVInfiniteScrollingView *view = [self infiniteScrollingViewAtDirection:direction];
    
    view.hidden = !showsInfiniteScrolling;
    
    if(!showsInfiniteScrolling) {
        if (view.isObserving) {
            [self removeObserver:view forKeyPath:@"contentOffset" context:&SVInfiniteScrollingViewObservationContext];
            [self removeObserver:view forKeyPath:@"contentSize" context:&SVInfiniteScrollingViewObservationContext];
            [view resetScrollViewContentInsetAnimated:animated];
            view.isObserving = NO;
        }
    }
    else {
        if (!view.isObserving) {
            [self addObserver:view forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:&SVInfiniteScrollingViewObservationContext];
            [self addObserver:view forKeyPath:@"contentSize" options:NSKeyValueObservingOptionOld context:&SVInfiniteScrollingViewObservationContext];
            [view setScrollViewContentInsetForInfiniteScrollingAnimated:animated];
            view.isObserving = YES;
            
            [view setNeedsLayout];
            CGFloat yOrigin = 0;
            CGFloat xOrigin = 0;
            switch (view.direction) {
                case SVInfiniteScrollingDirectionBottom:
                    yOrigin = self.contentSize.height;
                    break;
                case SVInfiniteScrollingDirectionTop:
                    yOrigin = -SVInfiniteScrollingViewHeight;
                    break;
                case SVInfiniteScrollingDirectionLeft:
                    xOrigin = -SVInfiniteScrollingViewWidth;
                    break;
                case SVInfiniteScrollingDirectionRight:
                    xOrigin = self.contentSize.width;
                    break;
            }
            view.frame = CGRectMake(xOrigin, yOrigin, view.bounds.size.width, view.bounds.size.height);
        }
    }
}

- (BOOL)showsInfiniteScrolling {
    return [self showsInfiniteScrollingAtDirection:SVInfiniteScrollingDirectionBottom];
}

- (BOOL)showsInfiniteScrollingAtDirection:(SVInfiniteScrollingDirection)direction{
    return ![self infiniteScrollingViewAtDirection:direction].hidden;
}

@end


#pragma mark - SVInfiniteScrollingView
@implementation SVInfiniteScrollingView

// public properties
@synthesize infiniteScrollingHandler, activityIndicatorViewStyle;

@synthesize state = _state;
@synthesize scrollView = _scrollView;
@synthesize activityIndicatorView = _activityIndicatorView;


- (id)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        
        // default styling values
        self.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.state = SVInfiniteScrollingStateStopped;
        self.enabled = YES;
        
        self.viewForState = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", nil];
    }
    
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (self.superview && newSuperview == nil) {
        UIScrollView *scrollView = (UIScrollView *)self.superview;
        if (scrollView.showsInfiniteScrolling) {
          if (self.isObserving) {
            [scrollView removeObserver:self forKeyPath:@"contentOffset" context:&SVInfiniteScrollingViewObservationContext];
            [scrollView removeObserver:self forKeyPath:@"contentSize" context:&SVInfiniteScrollingViewObservationContext];
            self.isObserving = NO;
          }
        }
    }
}

- (void)layoutSubviews {
    self.activityIndicatorView.center = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
}

#pragma mark - Scroll View

- (void)resetScrollViewContentInsetAnimated:(BOOL)animated{
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    switch (self.direction) {
        case SVInfiniteScrollingDirectionBottom:
            currentInsets.bottom = self.originalBottomInset;
            break;
        case SVInfiniteScrollingDirectionTop:
            currentInsets.top = self.originalTopInset;
            break;
        case SVInfiniteScrollingDirectionLeft:
            currentInsets.left = self.originalLeftInset;
            break;
        case SVInfiniteScrollingDirectionRight:
            currentInsets.right = self.originalRightInset;
            break;
    }
    [self setScrollViewContentInset:currentInsets animated:animated];
}

- (void)resetScrollViewContentInset {
    [self resetScrollViewContentInsetAnimated:YES];
}

- (void)setScrollViewContentInsetForInfiniteScrollingAnimated:(BOOL)animated{
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    switch (self.direction) {
        case SVInfiniteScrollingDirectionBottom:
            currentInsets.bottom = self.originalBottomInset + SVInfiniteScrollingViewHeight;
            break;
        case SVInfiniteScrollingDirectionTop:
            currentInsets.top = self.originalTopInset + SVInfiniteScrollingViewHeight;
            break;
        case SVInfiniteScrollingDirectionLeft:
            currentInsets.left = self.originalLeftInset + SVInfiniteScrollingViewWidth;
            break;
        case SVInfiniteScrollingDirectionRight:
            currentInsets.right = self.originalRightInset + SVInfiniteScrollingViewWidth;
            break;
    }
    [self setScrollViewContentInset:currentInsets animated:animated];
}

- (void)setScrollViewContentInsetForInfiniteScrolling{
    [self setScrollViewContentInsetForInfiniteScrollingAnimated:YES];
}

- (void)setScrollViewContentInset:(UIEdgeInsets)contentInset animated:(BOOL)animated{
    if(animated){
        [UIView animateWithDuration:0.3
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.scrollView.contentInset = contentInset;
                         }
                         completion:NULL];
    }
    else{
         self.scrollView.contentInset = contentInset;
    }
}

- (void)setScrollViewContentInset:(UIEdgeInsets)contentInset{
    [self setScrollViewContentInsetForInfiniteScrollingAnimated:YES];
}

#pragma mark - Observing

- (void)setLastContentOffsetY:(CGFloat)lastContentOffsetY
{
    _lastContentOffsetY = lastContentOffsetY >= 0 ? lastContentOffsetY : 0;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if([keyPath isEqualToString:@"contentOffset"]) {
        [self scrollViewDidScroll:[[change valueForKey:NSKeyValueChangeNewKey] CGPointValue]];
    }
    else if([keyPath isEqualToString:@"contentSize"]) {
        CGPoint currentContentOffset = self.scrollView.contentOffset;
        if (currentContentOffset.y < self.lastContentOffsetY) {
            self.lastContentOffsetY = currentContentOffset.y;
        }
        
        [self layoutSubviews];
        CGSize oldSize = [[change valueForKey:NSKeyValueChangeOldKey] CGSizeValue];
        CGSize newSize = self.scrollView.contentSize;
        CGFloat yOrigin = 0;
        CGFloat xOrigin = 0;
        switch (self.direction) {
            case SVInfiniteScrollingDirectionBottom:
                yOrigin = self.scrollView.contentSize.height;
                break;
            case SVInfiniteScrollingDirectionTop:
                yOrigin = -SVInfiniteScrollingViewHeight;
                if(self.wasRecentlyTriggered){
                    self.scrollView.contentOffset = (oldSize.height != 0) ? CGPointMake(self.scrollView.contentOffset.x, self.scrollView.contentOffset.y + newSize.height - oldSize.height) : self.scrollView.contentOffset;
                }
                break;
            case SVInfiniteScrollingDirectionLeft:
                xOrigin = -SVInfiniteScrollingViewWidth;
                break;
            case SVInfiniteScrollingDirectionRight:
                xOrigin = self.scrollView.contentSize.width;
                if(self.wasRecentlyTriggered){
                    self.scrollView.contentOffset = (oldSize.width != 0) ? CGPointMake(self.scrollView.contentOffset.x, self.scrollView.contentOffset.y + newSize.width - oldSize.width) : self.scrollView.contentOffset;
                }
                break;
        }
        self.frame = CGRectMake(xOrigin, yOrigin, self.bounds.size.width, self.bounds.size.height);
        self.wasRecentlyTriggered = NO;
    }
}

- (void)scrollViewDidScroll:(CGPoint)contentOffset {
    if(self.state != SVInfiniteScrollingStateLoading && self.enabled) {
        CGFloat scrollViewContentHeight = self.scrollView.contentSize.height;
        CGFloat scrollViewContentWidth = self.scrollView.contentSize.width;
        CGFloat scrollOffsetThreshold = 0;
        switch (self.direction) {
            case SVInfiniteScrollingDirectionBottom:
                scrollOffsetThreshold = scrollViewContentHeight-self.scrollView.bounds.size.height;
                break;
            case SVInfiniteScrollingDirectionTop:
                scrollOffsetThreshold = 0;
                break;
            case SVInfiniteScrollingDirectionLeft:
                scrollOffsetThreshold = 0;
                break;
            case SVInfiniteScrollingDirectionRight:
                scrollOffsetThreshold = scrollViewContentWidth-self.scrollView.bounds.size.width;
                break;
        }

        BOOL couldTrigger = self.state == SVInfiniteScrollingStateStopped && self.scrollView.isDragging;
        BOOL couldStop = self.state != SVInfiniteScrollingStateStopped;
        BOOL shouldLoading = !self.scrollView.isDragging && self.state == SVInfiniteScrollingStateTriggered;
        
        if(shouldLoading)
            self.state = SVInfiniteScrollingStateLoading;
        else if(couldTrigger){
            if((contentOffset.y > scrollOffsetThreshold && self.direction == SVInfiniteScrollingDirectionBottom) ||
               (contentOffset.x > scrollOffsetThreshold && self.direction == SVInfiniteScrollingDirectionRight)){
                
                if (!self.lastContentOffsetY) {
                    self.lastContentOffsetY = contentOffset.y;
                }
                else if (self.lastContentOffsetY < contentOffset.y) {
                    self.lastContentOffsetY = contentOffset.y;
                    self.state = SVInfiniteScrollingStateTriggered;
                }
            }
            else if((contentOffset.y < scrollOffsetThreshold && self.direction == SVInfiniteScrollingDirectionTop) ||
                   (contentOffset.x < scrollOffsetThreshold && self.direction == SVInfiniteScrollingDirectionLeft)){
                self.state = SVInfiniteScrollingStateTriggered;
            }
        }
        else if(couldStop){
            if((contentOffset.y < scrollOffsetThreshold && self.direction == SVInfiniteScrollingDirectionBottom) ||
               (contentOffset.x < scrollOffsetThreshold && self.direction == SVInfiniteScrollingDirectionRight)){
                self.state = SVInfiniteScrollingStateStopped;
            }
            else if((contentOffset.y > scrollOffsetThreshold && self.direction == SVInfiniteScrollingDirectionTop) ||
                    (contentOffset.x > scrollOffsetThreshold && self.direction == SVInfiniteScrollingDirectionLeft)){
                self.state = SVInfiniteScrollingStateStopped;
            }
        }
    }
}

#pragma mark - Getters

- (UIActivityIndicatorView *)activityIndicatorView {
    if(!_activityIndicatorView) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activityIndicatorView.hidesWhenStopped = YES;
        [self addSubview:_activityIndicatorView];
    }
    return _activityIndicatorView;
}

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle {
    return self.activityIndicatorView.activityIndicatorViewStyle;
}

#pragma mark - Setters

- (void)setCustomView:(UIView *)view forState:(SVInfiniteScrollingState)state {
    id viewPlaceholder = view;
    
    if(!viewPlaceholder)
        viewPlaceholder = @"";
    
    if(state == SVInfiniteScrollingStateAll)
        [self.viewForState replaceObjectsInRange:NSMakeRange(0, 3) withObjectsFromArray:@[viewPlaceholder, viewPlaceholder, viewPlaceholder]];
    else
        [self.viewForState replaceObjectAtIndex:state withObject:viewPlaceholder];
    
    self.state = self.state;
}

- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)viewStyle {
    self.activityIndicatorView.activityIndicatorViewStyle = viewStyle;
}

#pragma mark -

- (void)triggerRefresh {
    self.state = SVInfiniteScrollingStateTriggered;
    self.state = SVInfiniteScrollingStateLoading;
}

- (void)startAnimating{
    self.state = SVInfiniteScrollingStateLoading;
}

- (void)stopAnimating {
    self.state = SVInfiniteScrollingStateStopped;
}

- (void)setState:(SVInfiniteScrollingState)newState {
    
    if(_state == newState)
        return;
    
    SVInfiniteScrollingState previousState = _state;
    _state = newState;
    
    for(id otherView in self.viewForState) {
        if([otherView isKindOfClass:[UIView class]])
            [otherView removeFromSuperview];
    }
    
    id customView = [self.viewForState objectAtIndex:newState];
    BOOL hasCustomView = [customView isKindOfClass:[UIView class]];
    
    if(hasCustomView) {
        [self addSubview:customView];
        CGRect viewBounds = [customView bounds];
        CGPoint origin = CGPointMake(roundf((self.bounds.size.width-viewBounds.size.width)/2), roundf((self.bounds.size.height-viewBounds.size.height)/2));
        [customView setFrame:CGRectMake(origin.x, origin.y, viewBounds.size.width, viewBounds.size.height)];
    }
    else {
        CGRect viewBounds = [self.activityIndicatorView bounds];
        CGPoint origin = CGPointMake(roundf((self.bounds.size.width-viewBounds.size.width)/2), roundf((self.bounds.size.height-viewBounds.size.height)/2));
        [self.activityIndicatorView setFrame:CGRectMake(origin.x, origin.y, viewBounds.size.width, viewBounds.size.height)];
        
        switch (newState) {
            case SVInfiniteScrollingStateStopped:
                [self.activityIndicatorView stopAnimating];
                break;
            case SVInfiniteScrollingStateTriggered:
                [self.activityIndicatorView startAnimating];
                break;
            case SVInfiniteScrollingStateLoading:
                [self.activityIndicatorView startAnimating];
                self.wasRecentlyTriggered = YES;
                break;
        }
    }
    
    if(previousState == SVInfiniteScrollingStateTriggered && newState == SVInfiniteScrollingStateLoading && self.infiniteScrollingHandler && self.enabled)
        self.infiniteScrollingHandler();
}

@end
