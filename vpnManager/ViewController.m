//
//  ViewController.m
//  vpnManager
//
//  Created by lijinwei on 16/7/19.
//  Copyright © 2016年 ljw. All rights reserved.
//

#import "ViewController.h"
#import <NetworkExtension/NetworkExtension.h>
#import <ShadowPath/ShadowPath.h>
#include "expat.h"
#include <stdio.h>
#include <string.h>
// 判断网络状态
#include <ifaddrs.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#import <arpa/inet.h>
#include <net/if.h>

#import "MMWormhole.h"

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IOS_VPN         @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"
#define IP_MASK_IPv4    @"mask_ipv4"
#define IP_MASK_IPv6    @"mask_ipv6"

@interface ViewController ()

@property(strong,nonatomic) NETunnelProviderManager *manager;
@property (nonatomic) MMWormhole *wormhole;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self checkXML];
    self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:@"group.360.freewifi" optionalDirectory:@"wormhole"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)checkXML {
    
    char *path = strdup([[[NSBundle mainBundle] pathForResource:@"test1" ofType:@"xml"] UTF8String]);
    NSString *confContent = [NSString stringWithCString:path encoding:NSUTF8StringEncoding];
    //    NSString *confContent = [NSString stringWithContentsOfURL:[Potatso sharedSocksConfUrl] encoding:NSUTF8StringEncoding error:nil];
    NSData *data = [[NSData alloc] initWithContentsOfFile:confContent];
    confContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    confContent = [confContent stringByReplacingOccurrencesOfString:@"${ssport}" withString:[NSString stringWithFormat:@"%d", 8088]];
    
    XML_Parser parser;
    if( !( parser = XML_ParserCreate( NULL ) ) )
    {
        printf( "bad praser\n" );
    };
    XML_SetElementHandler( parser, href_begin_handler, NULL );
    if ( XML_STATUS_ERROR ==  XML_Parse( parser, confContent.UTF8String, (int)confContent.length, 0 ) )
    {
        NSLog(@"failed to parser: %s( line:%lu, column:%lu )\n", XML_ErrorString( XML_GetErrorCode( parser ) ),
              XML_GetCurrentLineNumber( parser ), XML_GetCurrentColumnNumber( parser ));
    }
}

- (IBAction)onBtnAction:(id)sender {
//    [self checkXML];
    
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray* newManagers, NSError *error) {
        NSLog(@"Managers %@", newManagers);
        if(newManagers.count>0) {
            _manager = [newManagers objectAtIndex:0];
        }
        else {
            _manager = [[NETunnelProviderManager alloc] init];
            _manager.protocolConfiguration = [[NETunnelProviderProtocol alloc] init];
            _manager.localizedDescription = @"Demo VPN";
            _manager.protocolConfiguration.serverAddress = @"test12";
            _manager.protocolConfiguration.proxySettings = nil;
            _manager.enabled = YES;
        }
        [_manager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            NSLog(@"saveToPreferencesWithCompletionHandler:%@",error);
            [_manager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                NSLog(@"%@",error);
                NETunnelProviderSession *session = (NETunnelProviderSession*) _manager.connection;
                NSData* msgData = [[NSString stringWithFormat:@"Hello Provider"] dataUsingEncoding:NSUTF8StringEncoding];
                [session sendProviderMessage:msgData returnError:nil responseHandler:^(NSData * _Nullable responseData) {
                    NSString* responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                    NSLog(@"%@",responseString);
                    NSError *error;
                    [_manager.connection startVPNTunnelAndReturnError:&error];
                }];
            }];
        }];
    }];

}


- (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
            
            const struct sockaddr_in *netmask = (const struct sockaddr_in *)interface->ifa_netmask;
            if(netmask && (netmask->sin_family == AF_INET || netmask->sin_family == AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type = nil;
                if (netmask->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &netmask->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_MASK_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *netmask = (const struct sockaddr_in6 *)interface->ifa_netmask;
                    if(inet_ntop(AF_INET6, &netmask->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_MASK_IPv6;
                    }
                }
                if (type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String: addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

- (IBAction)getiplist:(id)sender {
//    NSDictionary* ipList = [self getIPAddresses];
//    NSLog(@"%@",ipList);
//    wormhole.passMessageObject("", identifier: "getTunnelConnectionRecords")
    [self.wormhole passMessageObject:@"" identifier:@"getTunnelConnectionRecords"];

}

static char strhtml[] = {"<?xml version=\"1.0\" encoding=\"UTF-8\"?><antinatconfig><interface><value>\"172.0.0.1\"</value></interface></antinatconfig>"};
static  void href_begin_handler (void *userData, const XML_Char *name, const XML_Char **atts)
{
    int index = 0;
    if (strcmp( name, "a" ) == 0 )
    {
        printf( " I get the node a " );
        while ( atts[index] )
        {
            if ( strcmp( atts[index], "href" ) == 0 )
            {
                printf( "this auch link to:  %s\n", atts[index+1] );
                break;
            }
            index +=2;
        }
    }
    return ;
}
/*
int main()
{

    return 0;
}
*/
@end
