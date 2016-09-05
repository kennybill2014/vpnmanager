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

@interface ViewController ()

@property(strong,nonatomic) NETunnelProviderManager *manager;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self checkXML];

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
    [self checkXML];
    
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
