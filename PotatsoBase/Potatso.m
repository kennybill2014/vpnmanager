//
//  PotatsoManager.m
//  Potatso
//
//  Created by LEI on 4/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import "Potatso.h"

NSString *sharedGroupIdentifier = @"group.360.freewifi";

@implementation Potatso

+ (NSURL *)sharedUrl {
//    return [NSURL URLWithString:@"http://www.baidu.com"];
    return [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
//    return [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:sharedGroupIdentifier];
}

+ (NSURL *)sharedDatabaseUrl {
    return [[self sharedUrl] URLByAppendingPathComponent:@"potatso.realm"];
}

+ (NSUserDefaults *)sharedUserDefaults {
    return [[NSUserDefaults alloc] initWithSuiteName:sharedGroupIdentifier];
}

+ (NSURL * _Nonnull)sharedGeneralConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"general.xxx"];
}

+ (NSURL *)sharedSocksConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"socks.xxx"];
}

+ (NSURL *)sharedProxyConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"proxy.xxx"];
}

+ (NSURL *)sharedHttpProxyConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"http.xxx"];
}

+ (NSURL * _Nonnull)sharedLogUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"tunnel.log"];
}

@end
