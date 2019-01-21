//
//  SHLogUploadMgr.h
//  AFNetworking
//  这里对文件上传做一个简单的管理， 借用AFNetworking的上传接口进行文件上传
//  上传串行处理 ， 等成功，失败后再进行下一个
//  Created by genobili on 5/20/18.
//

#import <Foundation/Foundation.h>
#import "SHLogType.h"

@interface SHLogUploader : NSObject

//本地文件路径
@property (nonatomic, copy, readonly) NSString* filePath;
//上传的目标服务器
@property (nonatomic, copy, readonly) NSString* serverURL;
//上传完是否删除文件
@property (nonatomic, assign, readonly) BOOL  deleteFileAfterUploaded;

//文件大小
@property (nonatomic, assign) UInt64 sourceSize;
//已传大小
@property (nonatomic, assign) UInt64 uplaodedSize;

-(id)initWithFilePath:(NSString*)filePath serverURL:(NSString*)serverURL sourceSize:(UInt64)sourceSize deleteFileAfterUploaded:(BOOL)deleteFile;

@end

@interface SHLogUploadMgr : NSObject

+(instancetype)sharedInstance;


/**
 将上传文件

 @param uploadItem 上传文件添加到队列
 */
-(void)addUploadTaskWithItem:(SHLogUploader*)uploadItem;


/**
  取消所有的上传任务， 未上传的从队列清理， 正在上传的取消
 */
-(void)cancelAllTasks;


/**
 取消指定的上传任务， 如在等待传送从队列清除， 正在传输执行取消操作

 @param uploader 上传信息
 */
-(void)cancelTask:(SHLogUploader*)uploader;

/**
 执行上传任务，非队列执行
 
 @param uploadItem 上传信息
 @param complete   上传完成回调
 */
-(void)uploadTaskWithItem:(SHLogUploader*)uploadItem complete:(SHUploadCompleteBlock)complete;

@end
