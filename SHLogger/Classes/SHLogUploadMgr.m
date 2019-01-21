//
//  SHLogUploadMgr.m
//  AFNetworking
//
//  Created by genobili on 5/20/18.
//

#import "SHLogUploadMgr.h"
#import "AFNetworking.h"
#import "SHBaseLogger.h"

@implementation SHLogUploader

-(id)initWithFilePath:(NSString*)filePath serverURL:(NSString*)serverURL sourceSize:(UInt64)sourceSize deleteFileAfterUploaded:(BOOL)deleteFile {
    if( [super init] ) {
        _filePath = filePath;
        _serverURL = serverURL;
        _deleteFileAfterUploaded = deleteFile;
        _sourceSize = sourceSize;
    }
    return self;
}


-(BOOL)isEqual:(SHLogUploader*)object {
    if( object == nil ){
        return NO;
    }
    if( [self.filePath isEqualToString:object.filePath] && [self.serverURL isEqualToString:object.serverURL] ) {
        return YES;
    }
    return NO;
}

-(NSUInteger)hash {
    NSString* str = [NSString stringWithFormat:@"%@_%@", _filePath, _serverURL];
    return [str hash];
}

@end


@interface SHLogUploadMgr() {
    NSMutableArray* _uploadItemArray;
    NSMutableDictionary* _uploadTaskDic;
    AFURLSessionManager* _sessionManager;
}
@end

@implementation SHLogUploadMgr

+(id)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

+(instancetype)sharedInstance {
    static SHLogUploadMgr* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance= [[super allocWithZone:nil] init];
    });
    return instance;
}

-(instancetype)init {
    if( self = [super init] ) {
        _uploadItemArray = [NSMutableArray new];
        _uploadTaskDic = [NSMutableDictionary new];
        _sessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        AFHTTPResponseSerializer* responseSerializer = [AFHTTPResponseSerializer serializer];
        NSSet* set = [NSSet setWithObjects:@"text/plain", @"application/json", @"text/json", nil];
        responseSerializer.acceptableContentTypes = set;
        _sessionManager.responseSerializer = responseSerializer;
    }
    return self;
}

-(void)addUploadTaskWithItem:(SHLogUploader *)uploadItem {
    if( uploadItem.filePath.length == 0 || uploadItem.serverURL.length == 0 ) {
        return;
    }
    __weak typeof(self) wself = self;
    dispatch_main_async_safe( ^ {
        __strong typeof(wself) sself = wself;
        if(  !sself ) {
            return;
        }
        if( [sself->_uploadItemArray containsObject:uploadItem] ) {
            return;
        }
        [sself->_uploadItemArray addObject:uploadItem];
        [sself startNextTaskIfNecessary];
    });
}

-(void)cancelAllTasks{
    __weak typeof(self) wself = self;
    dispatch_main_async_safe( ^{
        __strong typeof (wself) sself = wself;
        if( !sself ) {
            return;
        }
        for( NSInteger i = sself->_uploadItemArray.count - 1; i >= 0; i--  ) {
            SHLogUploader* uploader = [sself->_uploadItemArray objectAtIndex:i];
            NSURLSessionUploadTask* uploadTask = [sself->_uploadTaskDic objectForKey:@([uploader hash])];
            if( uploadTask ) {
                [uploadTask cancel];
            }else{
                [sself->_uploadItemArray removeObjectAtIndex:i];
            }
        }
    });
}


-(void)cancelTask:(SHLogUploader*)uploader{
    if( !uploader ){
        return;
    }
    NSUInteger hash = [uploader hash];
    __weak typeof(self) wself = self;
    dispatch_main_async_safe( ^{
        __strong typeof (wself) sself = wself;
        if( !sself ) {
            return;
        }
        NSURLSessionUploadTask* uploadTask = [sself->_uploadTaskDic objectForKey:@(hash)];
        if( !uploadTask ) {
            return;
        }
        [uploadTask cancel];
    });
}

-(void)startNextTaskIfNecessary {
    if( self->_uploadItemArray.count == 0 ) {
        return;
    }
    //判断是否文件正在上传
    if(  _uploadTaskDic.count > 0 ) {
        return;
    }
    SHLogUploader* uploadItem = [self->_uploadItemArray objectAtIndex:0];
    [self uploadTaskWithItem:uploadItem bQueue:true complete:nil];
}

-(void)uploadTaskWithItem:(SHLogUploader*)uploadItem complete:(SHUploadCompleteBlock)complete{
    [self uploadTaskWithItem:uploadItem bQueue:false complete:complete];
}

-(void)uploadTaskWithItem:(SHLogUploader*)uploadItem bQueue:(BOOL)isQueue complete:(SHUploadCompleteBlock)complete{
    NSString* fileName = [uploadItem.filePath lastPathComponent];
//    NSString* name = [fileName stringByDeletingPathExtension];
//    NSString* ext = [fileName pathExtension];
    UInt64 fileSize = uploadItem.sourceSize;
    NSString* filePath = [NSString stringWithFormat:@"%@", uploadItem.filePath];
    BOOL deleteFile = uploadItem.deleteFileAfterUploaded;
    AFHTTPRequestSerializer* requestSerializer = [AFHTTPRequestSerializer serializer];
    NSMutableURLRequest *request = [requestSerializer multipartFormRequestWithMethod:@"POST" URLString:[uploadItem.serverURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
//        NSString* mimeType = @"application/octet-stream";
//        if( [LOGSAFESTRING(ext) caseInsensitiveCompare:@"zip"] == NSOrderedSame ){
//            mimeType = @"application/zip";
//        }
//        [formData appendPartWithFileURL:[NSURL fileURLWithPath:filePath] name:name fileName:fileName mimeType:mimeType error:nil];
        //每次都重新传， 暂不支持断点续传
        NSInputStream* inputStream = [[NSInputStream alloc] initWithFileAtPath:filePath];
        [inputStream setProperty:[NSNumber numberWithUnsignedLongLong:0] forKey:NSStreamFileCurrentOffsetKey];
        [formData appendPartWithInputStream:inputStream name:@"file" fileName:fileName length:fileSize mimeType:@"application/octet-stream"];
    } error:nil];
    
    NSURLSessionUploadTask *uploadTask;
    uploadTask = [_sessionManager
                  uploadTaskWithStreamedRequest:request
                  progress:nil
                  completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                      if (error) {
                          if(error.code ==  NSURLErrorCancelled ) {
                              NSLog(@"task canceled!");
                          }
                      } else {
                          NSString* strResponse = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                          NSLog(@"resposne = %@", strResponse);
                      }
                      
                      if (isQueue) {
                          if( self->_uploadItemArray.count > 0 ){
                              [self->_uploadItemArray removeObjectAtIndex:0];
                          }
                          [self->_uploadTaskDic removeObjectForKey:@(uploadItem.hash)];
                          [self startNextTaskIfNecessary];
                      }
                      
                      if( deleteFile ) {
                          NSError* err = nil;
                          [[NSFileManager defaultManager] removeItemAtPath:filePath error:&err];
                      }
                      
                      dispatch_async(dispatch_get_main_queue(), ^{
                          if (complete) {
                              complete(responseObject, error);
                          }
                      });
                  }];
    [uploadTask resume];
    
    if (isQueue) {
        [_uploadTaskDic setObject:uploadTask forKey:@(uploadItem.hash)];
    }
}



@end
