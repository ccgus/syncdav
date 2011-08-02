//
//  BSNSStringAdditions.h
//  BlogShop
//
//  Created by August Mueller on Fri May 09 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef is
#define is ==
#endif

@interface NSString (FMNSStringAdditions) 

- (int) numberOfOcurrencesOfChar:(char) c;    
- (NSString *) escapeForHTMLString;
//- (NSString *) encodeAsHTML; // this uses cf libs, which is horribly broken on 10.3

- (NSString *) trim;
- (NSString *) fmStringByReplacingPercentEscapes;
- (NSString *) fmStringByAddingPercentEscapesWithExceptions:(NSString*)ex;
- (NSString *) fmStringByAddingPercentEscapes;
- (NSString *) fmFilenameFriendlyString;
- (NSString *) commonPathPrefixWithString:(NSString *)s;
- (NSArray*) paragraphsForRange:(NSRange)r;
- (int) countOfWhitespacePrefixCharacters;

#if !TARGET_OS_IPHONE
- (NSData *) fmGetRTFDWithDefaultFont:(NSFont*) theFont;
- (OSStatus) pathToFSRef:(FSRef *)outRef;
- (NSString*) stringByResolvingFinderAlias;
- (NSString *)stringByRunningShellScript: (NSString *)scriptPath;
#endif

- (unsigned int) hexValue;

- (BOOL)hasSuffixFromArray:(NSArray*)ar;

- (BOOL)containsCharacter:(char)c;
- (BOOL)containsUnichar:(unichar)c;


- (NSString*) fmlower;
+ (id) stringWithData:(NSData *)data;
- (NSData*) data;
+ (id) stringWithUUID;

+ (id) stringWithContentsOfUTF8File:(NSString*)path;

@end

@interface NSMutableString (FMNSMutableStringAdditions) 
- (void)normalizeStringEndings;
- (void)normalizeStringEndingsInRange:(NSRange)r;
- (void)replace:(NSString*)searchingFor with:(NSString*)replaceWith;
@end
