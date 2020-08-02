#import "ZeroconfPlugin.h"
#import "RNNetServiceSerializer.h"
#import "EventHandler.h"


@interface ZeroconfPlugin ()

@property(nonatomic, strong) NSMutableArray *resolvingServices;
@property(nonatomic, strong) NSNetServiceBrowser *serviceBrowser;
@property(nonatomic, strong) EventHandler *eventHandler;

@end


@implementation ZeroconfPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar
{
    FlutterMethodChannel* channel = [FlutterMethodChannel methodChannelWithName:@"ca.michaux.peter.zeroconf"
                                                          binaryMessenger:[registrar messenger]];
    ZeroconfPlugin* plugin = [[ZeroconfPlugin alloc] init];

    plugin.eventHandler = [[EventHandler alloc] init];
    FlutterEventChannel *serviceResolved =
      [[FlutterEventChannel alloc] initWithName:@"ca.michaux.peter.zeroconf.events"
                                binaryMessenger:registrar.messenger
                                          codec:[FlutterStandardMethodCodec sharedInstance]];
    [serviceResolved setStreamHandler:plugin.eventHandler];

    [registrar addMethodCallDelegate:plugin channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call
                  result:(FlutterResult)result
{
    NSString *method = call.method;
    if ([@"startScan" isEqualToString:method]) {
        [self handleStartScan:call result:result];
    }
    else if ([@"stopScan" isEqualToString:method]) {
        [self handleStopScan:call result:result];
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)handleStartScan:(FlutterMethodCall*)call
                 result:(FlutterResult)result
{
    [self startScanType:call.arguments[@"type"]];
    result([NSNull null]);
}

- (void)startScanTimerFinished:(NSTimer *)timer
{
    [self startScanType:timer.userInfo];
}

- (void)startScanType:(NSString*)type
{
    // Sometimes Flutter needs a few moments before the eventSink set
    // in the event handler, we'll just check once every 100ms if
    // Flutter is ready yet...
    if (!self.eventHandler.isReady) {
        [NSTimer scheduledTimerWithTimeInterval:0.1f
                                        target:self
                                      selector:@selector(startScanTimerFinished:)
                                      userInfo:type
                                        repeats:NO];
        return;
    }

    [self stopScan];

    if (self.serviceBrowser == nil) {
        self.serviceBrowser = [[NSNetServiceBrowser alloc] init];
        self.serviceBrowser.delegate = self;
    }
    if (self.resolvingServices == nil) {
        self.resolvingServices = [[NSMutableArray alloc] init];
    }

    [self.serviceBrowser searchForServicesOfType:type inDomain:@""];
}

- (void)handleStopScan:(FlutterMethodCall*)call
                result:(FlutterResult)result
{
    [self stopScan];
    result([NSNull null]);
}

- (void)stopScan
{
    [self.serviceBrowser stop];
    [self.resolvingServices removeAllObjects];
}

#pragma mark - NSNetServiceBrowserDelegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
           didFindService:(NSNetService *)service
               moreComing:(BOOL)moreComing
{
    // https://github.com/balthazar/react-native-zeroconf/issues/12
    if (service == nil) {
        return;
    }

    [self.eventHandler onEvent:@{
        @"type": @"ServiceFound",
        @"service": [RNNetServiceSerializer serializeServiceToDictionary:service resolved:NO]
    }];

    // Resolving services must be strongly referenced.
    // Otherwise they will be garbage collected, will never resolve, and will never timeout.
    // See: http://stackoverflow.com/a/16130535/2715
    //
    [self.resolvingServices addObject:service];
    service.delegate = self;
    [service resolveWithTimeout:5.0];
}

- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser
         didRemoveService:(NSNetService*)service
               moreComing:(BOOL)moreComing
{
    if (service == nil) {
        return;
    }
    [self.eventHandler onEvent:@{
        @"type": @"ServiceLost",
        @"service": [RNNetServiceSerializer serializeServiceToDictionary:service resolved:NO]
    }];
    service.delegate = nil;
    [self.resolvingServices removeObject:service];
}

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
    [self.eventHandler onEvent:@{@"type": @"ScanStarted"}];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
             didNotSearch:(NSDictionary *)errorDict
{
    [self.eventHandler onEvent:@{@"type": @"Error"}];
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser
{
    [self.eventHandler onEvent:@{@"type": @"ScanStopped"}];
}

#pragma mark - NSNetServiceDelegate

- (void)netService:(NSNetService *)service 
     didNotResolve:(NSDictionary<NSString *,NSNumber *> *)errorDict
{
    [self.eventHandler onEvent:@{
        @"type": @"ServiceNotResolved",
        @"service": [RNNetServiceSerializer serializeServiceToDictionary:service resolved:NO]
    }];
    service.delegate = nil;
    [self.resolvingServices removeObject:service];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service
{
    [self.eventHandler onEvent:@{
        @"type": @"ServiceResolved",
        @"service": [RNNetServiceSerializer serializeServiceToDictionary:service resolved:YES]
    }];
    service.delegate = nil;
    [self.resolvingServices removeObject:service];
}

@end
