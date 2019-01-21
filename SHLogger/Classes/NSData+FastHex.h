//
//  NSData+FastHex.h
//  Pods
//
//  Created by Jonathon Mah on 2015-05-13.
//
//

#import <Foundation/Foundation.h>


@interface NSData (FastHex)

+ (instancetype _Nullable )dataWithHexString:(NSString *_Nullable)hexString;

- (nullable instancetype)initWithHexString:(NSString *_Nullable)hexString ignoreOtherCharacters:(BOOL)ignoreOtherCharacters;

- (NSString *_Nullable)hexStringRepresentation;
-(NSData*_Nullable)hexDataRepresentation;

- (NSString *_Nullable)hexStringRepresentationUppercase:(BOOL)uppercase;
- (NSData*_Nullable)hexDataRepresentationUppdercase:(BOOL)uppercase;

@end

