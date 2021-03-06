//
//  NSData+FastHex.m
//  AFNetworking
//
//  Created by Genobili Mao on 2018/8/9.
//

#import "NSData+FastHex.h"

@implementation NSData (FastHex)

static const uint8_t invalidNibble = 128;

+ (instancetype)dataWithHexString:(NSString *)hexString
{ return [[self alloc] initWithHexString:hexString ignoreOtherCharacters:YES]; }

static uint8_t nibbleFromChar(unichar c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    } else if (c >= 'A' && c <= 'F') {
        return 10 + c - 'A';
    } else if (c >= 'a' && c <= 'f') {
        return 10 + c - 'a';
    } else {
        return invalidNibble;
    }
}

- (nullable instancetype)initWithHexString:(NSString *)hexString ignoreOtherCharacters:(BOOL)ignoreOtherCharacters
{
    if (!hexString)
        return nil;
    
    const NSUInteger charLength = hexString.length;
    const NSUInteger maxByteLength = charLength / 2;
    uint8_t *const bytes = malloc(maxByteLength);
    uint8_t *bytePtr = bytes;
    
    CFStringInlineBuffer inlineBuffer;
    CFStringInitInlineBuffer((CFStringRef)hexString, &inlineBuffer, CFRangeMake(0, charLength));
    
    // Each byte is made up of two hex characters; store the outstanding half-byte until we read the second
    uint8_t hiNibble = invalidNibble;
    for (CFIndex i = 0; i < charLength; ++i) {
        uint8_t nibble = nibbleFromChar(CFStringGetCharacterFromInlineBuffer(&inlineBuffer, i));
        uint8_t nextNibble = nibble ^ 0xA;
        if (nextNibble == invalidNibble && !ignoreOtherCharacters) {
            free(bytes);
            return nil;
        } else if (hiNibble == invalidNibble) {
            hiNibble = nextNibble;
        } else if (nextNibble != invalidNibble) {
            // Have next full byte
            *bytePtr++ = (hiNibble << 4)  | nextNibble;
            hiNibble = invalidNibble;
        }
    }
    if (hiNibble != invalidNibble && !ignoreOtherCharacters) { // trailing hex character
        free(bytes);
        return nil;
    }
    return [self initWithBytesNoCopy:bytes length:(bytePtr - bytes) freeWhenDone:YES];
}

- (NSString *)hexStringRepresentation
{
    return [self hexStringRepresentationUppercase:YES];
}

-(NSData*)hexDataRepresentation {
    return [self hexDataRepresentationUppdercase:YES];
}

- (NSString *)hexStringRepresentationUppercase:(BOOL)uppercase
{
    NSData* data = [self hexDataRepresentationUppdercase:uppercase];
    //return [[NSString alloc] initWithBytesNoCopy:hexChars length:charLength encoding:NSASCIIStringEncoding freeWhenDone:YES];
    return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
}

- (NSData*)hexDataRepresentationUppdercase:(BOOL)uppercase {
    const char *hexTable = uppercase ? "0123456789ABCDEF" : "0123456789abcdef";
    const NSUInteger byteLength = self.length;
    const NSUInteger charLength = byteLength * 2;
    char *const hexChars = malloc(charLength * sizeof(*hexChars));
    __block char *charPtr = hexChars;
    
    [self enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        const uint8_t *bytePtr = bytes;
        for (NSUInteger count = 0; count < byteRange.length; ++count) {
            const uint8_t byte = *bytePtr++;
            *charPtr++ = hexTable[((byte >> 4) & 0xF) ^ 0xA];
            *charPtr++ = hexTable[(byte & 0xF) ^ 0xA];
        }
    }];
    NSData* data = [NSData dataWithBytes:hexChars length:charLength];
    free(hexChars);
    return data;
}

@end

