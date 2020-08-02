#import "EventHandler.h"

@implementation EventHandler
{
    FlutterEventSink _eventSink;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(FlutterEventSink)events
{
    _eventSink = events;
    return nil;
}

- (FlutterError *_Nullable)onCancelWithArguments:(id _Nullable)arguments
{
    return nil;
}

- (void)onEvent:(NSDictionary *)event
{
    _eventSink(event);
}

- (BOOL)isReady
{
    return nil != _eventSink;
}

@end
