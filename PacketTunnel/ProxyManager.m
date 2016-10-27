//
//  ProxyManager.m
//  Potatso
//
//  Created by LEI on 2/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import "ProxyManager.h"
#import <ShadowPath/ShadowPath.h>
#import <netinet/in.h>
#import "PotatsoBase.h"
#import "MMWormhole.h"

@interface ProxyManager ()
@property (nonatomic) BOOL socksProxyRunning;
@property (nonatomic) int socksProxyPort;
@property (nonatomic) BOOL httpProxyRunning;
@property (nonatomic) int httpProxyPort;
@property (nonatomic) BOOL shadowsocksProxyRunning;
@property (nonatomic) int shadowsocksProxyPort;
@property (nonatomic, copy) SocksProxyCompletion socksCompletion;
@property (nonatomic, copy) HttpProxyCompletion httpCompletion;
@property (nonatomic, copy) ShadowsocksProxyCompletion shadowsocksCompletion;
- (void)onSocksProxyCallback: (int)fd;
- (void)onHttpProxyCallback: (int)fd;
- (void)onShadowsocksCallback:(int)fd;

@property (nonatomic) MMWormhole *wormhole;

@end

void http_proxy_handler(int fd, void *udata) {
    ProxyManager *provider = (__bridge ProxyManager *)udata;
    [provider onHttpProxyCallback:fd];
}

void shadowsocks_handler(int fd, void *udata) {
    ProxyManager *provider = (__bridge ProxyManager *)udata;
    [provider onShadowsocksCallback:fd];
}

int sock_port (int fd) {
    struct sockaddr_in sin;
    socklen_t len = sizeof(sin);
    if (getsockname(fd, (struct sockaddr *)&sin, &len) < 0) {
        NSLog(@"getsock_port(%d) error: %s",
              fd, strerror (errno));
        return 0;
    }else{
        return ntohs(sin.sin_port);
    }
}

@implementation ProxyManager

+ (ProxyManager *)sharedManager {
    static dispatch_once_t onceToken;
    static ProxyManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [ProxyManager new];
        [manager setupWormhole];
    });
    return manager;
}

- (void)startSocksProxy:(SocksProxyCompletion)completion {
    self.socksCompletion = [completion copy];
    char *path = strdup([[[NSBundle mainBundle] pathForResource:@"test" ofType:@"xml"] UTF8String]);
    NSString *confContent = [NSString stringWithCString:path encoding:NSUTF8StringEncoding];
//    NSString *confContent = [NSString stringWithContentsOfURL:[Potatso sharedSocksConfUrl] encoding:NSUTF8StringEncoding error:nil];
    NSData *data = [[NSData alloc] initWithContentsOfFile:confContent];
    confContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    confContent = [confContent stringByReplacingOccurrencesOfString:@"${ssport}" withString:[NSString stringWithFormat:@"%d", [self shadowsocksProxyPort]]];
    NSLog(@"%@",confContent);
    int fd = [[AntinatServer sharedServer] startWithConfig:confContent];
    [self onSocksProxyCallback:fd];
}

- (void)stopSocksProxy {
    [[AntinatServer sharedServer] stop];
    self.socksProxyRunning = NO;
}

- (void)onSocksProxyCallback:(int)fd {
    NSError *error;
    if (fd > 0) {
        self.socksProxyPort = sock_port(fd);
        self.socksProxyRunning = YES;
    }else {
        error = [NSError errorWithDomain:@"com.touchingapp.potatso" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Fail to start socks proxy"}];
    }
    if (self.socksCompletion) {
        self.socksCompletion(self.socksProxyPort, error);
    }
}

# pragma mark - Shadowsocks

- (void)startShadowsocks: (ShadowsocksProxyCompletion)completion {
    self.shadowsocksCompletion = [completion copy];
    [NSThread detachNewThreadSelector:@selector(_startShadowsocks) toTarget:self withObject:nil];
}

- (void)_startShadowsocks {
    NSString *confContent = [NSString stringWithContentsOfURL:[Potatso sharedProxyConfUrl] encoding:NSUTF8StringEncoding error:nil];
    NSDictionary *json = [confContent jsonDictionary];
    NSString *host = json[@"host"];
    host = @"vpnmanager.com";
    NSNumber *port = json[@"port"];
    port = [NSNumber numberWithInteger:0];
    NSString *password = json[@"password"];
    password = @"12345";
    NSString *authscheme = json[@"authscheme"];
    authscheme = @"bf-cfb";
    NSString *protocol = json[@"protocol"];
    NSString *obfs = json[@"obfs"];
    NSString *obfs_param = json[@"obfs_param"];
    BOOL ota = [json[@"ota"] boolValue];
    ota = 0;
    if (host && port && password && authscheme) {
        profile_t profile;
        memset(&profile, 0, sizeof(profile_t));
        profile.remote_host = strdup([host UTF8String]);
        profile.remote_port = [port intValue];
        profile.password = strdup([password UTF8String]);
        profile.method = strdup([authscheme UTF8String]);
        profile.local_addr = "127.0.0.1";
        profile.local_port = 0;
        profile.timeout = 600;
        profile.auth = ota;
        if (protocol.length > 0) {
            profile.protocol = strdup([protocol UTF8String]);
        }
        if (obfs.length > 0) {
            profile.obfs = strdup([obfs UTF8String]);
        }
        if (obfs_param.length > 0) {
            profile.obfs_param = strdup([obfs_param UTF8String]);
        }
        int nRet = start_ss_local_server(profile, shadowsocks_handler, (__bridge void *)self);
        int k = 1;
    }else {
        if (self.shadowsocksCompletion) {
            self.shadowsocksCompletion(0, nil);
        }
        return;
    }
}

- (void)stopShadowsocks {
    // Do nothing
}

- (void)onShadowsocksCallback:(int)fd {
    NSError *error;
    if (fd > 0) {
        self.shadowsocksProxyPort = sock_port(fd);
        self.shadowsocksProxyRunning = YES;
    }else {
        error = [NSError errorWithDomain:@"com.touchingapp.potatso" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Fail to start http proxy"}];
    }
    if (self.shadowsocksCompletion) {
        self.shadowsocksCompletion(self.shadowsocksProxyPort, error);
    }
}

# pragma mark - Http Proxy

- (void)startHttpProxy:(HttpProxyCompletion)completion {
    self.httpCompletion = [completion copy];
    [NSThread detachNewThreadSelector:@selector(_startHttpProxy:) toTarget:self withObject:[Potatso sharedHttpProxyConfUrl]];
}

- (void)_startHttpProxy: (NSURL *)confURL {
    struct forward_spec *proxy = NULL;
    if (self.shadowsocksProxyPort > 0) {
        proxy = (malloc(sizeof(struct forward_spec)));
        memset(proxy, 0, sizeof(struct forward_spec));
        proxy->type = SOCKS_5;
        proxy->gateway_host = "127.0.0.1";
        proxy->gateway_port = self.shadowsocksProxyPort;
    }
    // Do any additional setup after loading the view, typically from a nib.
    char *path = strdup([[[NSBundle mainBundle] pathForResource:@"config" ofType:@""] UTF8String]);
 /*
    confdir /private/var/mobile/Containers/Shared/AppGroup/472DA619-6EF3-4996-A166-90812A725111/httpconf
    keep-alive-timeout 5
    toggle 1
    socket-timeout 300
    enable-proxy-authentication-forwarding 0
    mmdbpath /private/var/mobile/Containers/Shared/AppGroup/472DA619-6EF3-4996-A166-90812A725111/GeoLite2-Country.mmdb
    logdir /private/var/mobile/Containers/Shared/AppGroup/472DA619-6EF3-4996-A166-90812A725111/log
    global-mode 0
    tolerate-pipelining 1
    actionsfile /private/var/mobile/Containers/Shared/AppGroup/472DA619-6EF3-4996-A166-90812A725111/httpconf/potatso.action
    templdir /private/var/mobile/Containers/Shared/AppGroup/472DA619-6EF3-4996-A166-90812A725111/httptemplate
    listen-address 127.0.0.1:0
    buffer-limit 512
    split-large-forms 0
    enable-remote-http-toggle 0
    accept-intercepted-requests 0
    allow-cgi-request-crunching 0
    enable-edit-actions 0
    */
    NSLog(@"_startHttpProxy path=%s", path);
    shadowpath_main(path, proxy, http_proxy_handler, (__bridge void *)self);
}

- (void)stopHttpProxy {
    //    polipoExit();
    //    self.httpProxyRunning = NO;
}

- (void)onHttpProxyCallback:(int)fd {
    NSError *error;
    if (fd > 0) {
        self.httpProxyPort = sock_port(fd);
        self.httpProxyRunning = YES;
    }else {
        error = [NSError errorWithDomain:@"com.touchingapp.potatso" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Fail to start http proxy"}];
    }
    if (self.httpCompletion) {
        self.httpCompletion(self.httpProxyPort, error);
    }
}

- (void)setupWormhole {
    NSLog(@"test setupWormhole begin");
    self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:@"group.360.freewifi" optionalDirectory:@"wormhole"];
    __weak typeof(self) weakSelf = self;
    [self.wormhole listenForMessageWithIdentifier:@"getTunnelStatus" listener:^(id  _Nullable messageObject) {
        [weakSelf.wormhole passMessageObject:@"ok" identifier:@"tunnelStatus"];
    }];
    [self.wormhole listenForMessageWithIdentifier:@"stopTunnel" listener:^(id  _Nullable messageObject) {
//        [weakSelf stop];
    }];
    [self.wormhole listenForMessageWithIdentifier:@"getTunnelConnectionRecords" listener:^(id  _Nullable messageObject) {
        NSMutableArray *records = [NSMutableArray array];
          struct log_client_states *p = log_clients;
         while (p) {
         struct client_state *client = p->csp;
         NSMutableDictionary *d = [NSMutableDictionary dictionary];
         char *url = client->http->url;
         if (url ==  NULL) {
         p = p->next;
         continue;
         }
         d[@"url"] = [NSString stringWithCString:url encoding:NSUTF8StringEncoding];
         d[@"method"] = @(client->http->gpc);
         for (int i=0; i < STATUS_COUNT; i++) {
         d[[NSString stringWithFormat:@"time%d", i]] = @(client->timestamp[i]);
         }
         d[@"version"] = @(client->http->ver);
         if (client->rule && client->rule->rule) {
         d[@"rule"] = [NSString stringWithCString:client->rule->rule encoding:NSUTF8StringEncoding];
         }
         d[@"global"] = @(global_mode);
         //            if (p->headers) {
         //                d[@"headers"] = [NSString stringWithCString:p->headers->string encoding:NSUTF8StringEncoding];
         //            }
         //            if (p->rule) {
         //                d[@"ruleType"] = @(p->rule->type),
         //                d[@"ruleAction"] = @(p->rule->action),
         //                d[@"ruleValue"] = [NSString stringWithCString:p->rule->value encoding:NSUTF8StringEncoding];
         //            }
         
         d[@"responseCode"] = @(client->http->status);
         [records addObject:d];
         p = p->next;
         }
        NSString *result = [records jsonString];
        NSLog(@"testMMWormhole result=%@",result);
        [weakSelf.wormhole passMessageObject:result identifier:@"tunnelConnectionRecords"];
    }];
    NSLog(@"test setupWormhole end");
}

@end

