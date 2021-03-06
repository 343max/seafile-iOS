//
//  SeafAvatar.m
//  seafilePro
//
//  Created by Wang Wei on 4/11/14.
//  Copyright (c) 2014 Seafile. All rights reserved.
//

#import "SeafAvatar.h"
#import "SeafAppDelegate.h"

#import "ExtentedString.h"
#import "Utils.h"
#import "Debug.h"


static NSMutableDictionary *avatarAttrs = nil;


@interface SeafAvatar()
@property SeafConnection *connection;
@property NSString *avatarUrl;
@property NSString *path;
@end

@implementation SeafAvatar

- (id)initWithConnection:(SeafConnection *)aConnection from:(NSString *)url toPath:(NSString *)path
{
    self = [super init];
    self.connection = aConnection;
    self.avatarUrl = url;
    self.path = path;
    return self;
}

+ (NSMutableDictionary *)avatarAttrs
{
    if (avatarAttrs == nil) {
        NSString *attrsFile = [[[Utils applicationDocumentsDirectory] stringByAppendingPathComponent:@"avatars"] stringByAppendingPathComponent:@"avatars.plist"];
        avatarAttrs = [[NSMutableDictionary alloc] initWithContentsOfFile:attrsFile];
        if (!avatarAttrs)
            avatarAttrs = [[NSMutableDictionary alloc] init];
    }
    return avatarAttrs;
}
+ (void)saveAvatarAttrs
{
    NSString *attrsFile = [[[Utils applicationDocumentsDirectory] stringByAppendingPathComponent:@"avatars"] stringByAppendingPathComponent:@"avatars.plist"];
    [[SeafAvatar avatarAttrs] writeToFile:attrsFile atomically:YES];
}

+ (void)clearCache
{
    [Utils clearAllFiles:[[Utils applicationDocumentsDirectory] stringByAppendingPathComponent:@"avatars"]];
    avatarAttrs = [[NSMutableDictionary alloc] init];
}

- (NSMutableDictionary *)attrs
{
    NSMutableDictionary *dict = [[SeafAvatar avatarAttrs] objectForKey:self.path];
    return dict;
}
- (void)saveAttrs:(NSMutableDictionary *)dict
{
    [[SeafAvatar avatarAttrs] setObject:dict forKey:self.path];
}
- (BOOL)modified:(long long)timestamp
{
    NSMutableDictionary *attr = [[SeafAvatar avatarAttrs] objectForKey:self.path];
    if (!attr)
        return YES;
    if ([[attr objectForKey:@"mtime"] integerValue:0] < timestamp)
        return YES;
    return NO;
}
- (void)download
{
    [SeafAppDelegate incDownloadnum];
    [self.connection sendRequest:self.avatarUrl success:
     ^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON, NSData *data) {
         if (![JSON isKindOfClass:[NSDictionary class]]) {
             [SeafAppDelegate finishDownload:self result:NO];
             return;
         }
         NSString *url = [JSON objectForKey:@"url"];
         if (!url) {
             [SeafAppDelegate finishDownload:self result:NO];
             return;
         }
         if([[JSON objectForKey:@"is_default"] integerValue]) {
             if ([[SeafAvatar avatarAttrs] objectForKey:self.path])
                 [[SeafAvatar avatarAttrs] removeObjectForKey:self.path];
             [SeafAppDelegate finishDownload:self result:YES];
             return;
         }
         if (![self modified:[[JSON objectForKey:@"mtime"] integerValue:0]]) {
             Debug("avatar not modified\n");
             [SeafAppDelegate finishDownload:self result:YES];
             return;
         }
         url = [[url stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] escapedUrlPath];;
         NSURLRequest *downloadRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
         AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:downloadRequest];
         NSString *tmppath = [self.path stringByAppendingString:@"-tmp"];
         operation.outputStream = [NSOutputStream outputStreamToFileAtPath:tmppath append:NO];
         [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
             Debug("Successfully downloaded avatar");
             [[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
             [[NSFileManager defaultManager] moveItemAtPath:tmppath toPath:self.path error:nil];
             NSMutableDictionary *attr = [[SeafAvatar avatarAttrs] objectForKey:self.path];
             if (!attr)
                 attr = [[NSMutableDictionary  alloc] init];
             [attr setObject:[JSON objectForKey:@"mtime"] forKey:@"mtime"];
             [[SeafAvatar avatarAttrs] setObject:attr forKey:self.path];
             [SeafAvatar saveAvatarAttrs];
             [SeafAppDelegate finishDownload:self result:YES];
         } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
             Debug("url=%@, error=%@",downloadRequest.URL, [error localizedDescription]);
             [SeafAppDelegate finishDownload:self result:NO];
         }];
         [self.connection handleOperation:operation];
     }
              failure:
     ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
         Warning("Failed to download avatar from %@, error=%@", request.URL, error);
         [SeafAppDelegate finishDownload:self result:NO];
     }];
}
@end


@implementation SeafUserAvatar
- (id)initWithConnection:(SeafConnection *)aConnection username:(NSString *)username
{

    NSString *url = [NSString stringWithFormat:API_URL"/avatars/user/%@/resized/%d/", username, 80];
    NSString *path = [SeafUserAvatar pathForAvatar:aConnection username:username];
    self = [super initWithConnection:aConnection from:url toPath:path];
    return self;
}

+ (NSString *)pathForAvatar:(SeafConnection *)conn username:(NSString *)username
{
    NSString *filename = [NSString stringWithFormat:@"%@-%@.jpg", conn.host, username];
    NSString *path = [[[Utils applicationDocumentsDirectory]stringByAppendingPathComponent:@"avatars"] stringByAppendingPathComponent:filename];
    return path;
}

@end


@implementation SeafGroupAvatar
- (id)initWithConnection:(SeafConnection *)aConnection group:(NSString *)group_id
{
    NSString *url = [NSString stringWithFormat:API_URL"/avatars/group/%@/resized/%d/", group_id, 80];
    NSString *path = [SeafGroupAvatar pathForAvatar:aConnection group:group_id];
    self = [super initWithConnection:aConnection from:url toPath:path];
    return self;
}

+ (NSString *)pathForAvatar:(SeafConnection *)conn group:(NSString *)group_id
{
    NSString *filename = [NSString stringWithFormat:@"%@-%@.jpg", conn.host, group_id];
    NSString *path = [[[Utils applicationDocumentsDirectory]stringByAppendingPathComponent:@"avatars"] stringByAppendingPathComponent:filename];
    return path;
}

@end

