//
// Created by Sander Bruggeman on 24-07-18.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

@interface EventHandler : NSObject <FlutterStreamHandler>

- (void)onEvent:(NSDictionary *)event;
- (BOOL)isReady;

@end
