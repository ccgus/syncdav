//
//  BSNSStringAdditions.m
//  BlogShop
//
//  Created by August Mueller on Fri May 09 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "FMNSStringAdditions.h"

@implementation NSString (FMNSStringAdditions)

- (BOOL)containsCharacter:(char)c; {
    
    int len = [self length];
    const char *word = [self UTF8String];
    
    if (!word) {
        return NO; // whoa, this can happen.
    }
    
    int i = 0;
    for (; i < len; i++) {
        if (word[i] == c) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)containsUnichar:(unichar)c {
    
    int len = [self length];
    int i = 0;
    
    while (i < len) {
        
        if ([self characterAtIndex:i] == c) {
            return YES;
        }
        
        i++;
    }
    
    return NO;
}

- (BOOL)hasSuffixFromArray:(NSArray*)ar; {
    
    NSEnumerator *enumerator = [ar objectEnumerator];
    id object;

    while ((object = [enumerator nextObject])) {
    	if ([self hasSuffix:object]) {
            return YES;
        }
    }
    
    return NO;
    
}


- (NSString *) commonPathPrefixWithString:(NSString *)s {
    
    NSMutableString *ret = [NSMutableString string];
    int i = 0;
    int lastSeperator = 0;
    
    int maxLen = [self length];
    if ([s length] < maxLen) {
        maxLen = [s length];
    }
    
    maxLen--;
    
    while ([self characterAtIndex:i] == [s characterAtIndex:i] && (i < maxLen)) {
        [ret appendFormat:@"%c", [self characterAtIndex:i]];
        
        if ([s characterAtIndex:i] == '/') {
            lastSeperator = i;
        }
        i++;
    }
    
    // well, me maxed out on one of them, so the full path has gotta be good.
    if (i == maxLen) {
        
        debug(@"maxed out at: %@", ret);
        
        if ([ret hasSuffix:@"/"]) {
            debug(@"deleting the trailing /");
            [ret deleteCharactersInRange:NSMakeRange([ret length] - 1, 1)];
        }
        
        
        return ret;
    }
    
    if (lastSeperator > 0) {
        [ret deleteCharactersInRange:NSMakeRange(lastSeperator, [ret length] - lastSeperator)];
    }
    
    if ([@"/" isEqualToString:ret]) {
        return @"";
    }
    
    return ret;
    
}

- (NSString*) escapeForHTMLString {
    NSMutableString *ms = [NSMutableString stringWithString:self];
    
    [ms replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [ms length])];
    [ms replaceOccurrencesOfString:@"<" withString:@"&lt;"  options:0 range:NSMakeRange(0, [ms length])];
    [ms replaceOccurrencesOfString:@">" withString:@"&gt;"  options:0 range:NSMakeRange(0, [ms length])];
    
    //silly hack to make it legal.
    // I need to replace this nicer...
    [ms replaceOccurrencesOfString:@"\f" withString:@" "  options:0 range:NSMakeRange(0, [ms length])];
    
    return [NSString stringWithString:ms];
    
}

#if !TARGET_OS_IPHONE
- (NSString *) encodeAsHTML; {
	return [(NSString *)CFXMLCreateStringByEscapingEntities(NULL,(CFStringRef)self,NULL) autorelease];
}

#endif


- (int) numberOfOcurrencesOfChar:(char) c {
    const char *uchar = [self UTF8String];
    
    if (!uchar) {
        return 0;
    }
    
    int count = 0;
    int i = 0;
    int len = [self length];
    while (i < len) {
        if (uchar[i] == c) {
            count++;
        }
        i++;
    }
    
    return count;
}

- (NSString*) trim {
    
    // this is done to get around a bug in 10.2
    // http://developer.apple.com/qa/qa2001/qa1202.html
    
    /*
    NSMutableString *bah = [NSMutableString stringWithString:self];
    
    CFStringTrimWhitespace((CFMutableStringRef)bah);
    
    return [NSString stringWithString:bah];
    
    //debug(@"at trim i'm: '%@'", self);
    //debug(@"[self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]: %@", [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
    */
    
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

/*
- (NSString*) htmlFileify {
    
    NSMutableString *bah = [NSMutableString stringWithString:self];
    
    // ä
    [bah replaceOccurrencesOfString:[NSString stringWithFormat:@"%C", 0xC3A4] withString:@"ae" options:nil range:NSMakeRange(0, [bah length])];
    
    // ü
    [bah replaceOccurrencesOfString:[NSString stringWithFormat:@"%C", 0xC3BC] withString:@"ue" options:nil range:NSMakeRange(0, [bah length])]; 
    
    // ö
    [bah replaceOccurrencesOfString:[NSString stringWithFormat:@"%C", 0xC3B6] withString:@"oe" options:nil range:NSMakeRange(0, [bah length])]; 
    
    // ß
    [bah replaceOccurrencesOfString:[NSString stringWithFormat:@"%C", 0xC39F] withString:@"ss" options:nil range:NSMakeRange(0, [bah length])]; 
    [bah replaceOccurrencesOfString:@" " withString:@"_"  options:nil range:NSMakeRange(0, [bah length])];
    
    return [NSString stringWithString:bah];
}
*/

- (NSString *) fmStringByAddingPercentEscapesb
{
	return [(NSString *) CFURLCreateStringByAddingPercentEscapes(
		NULL, (CFStringRef) self, (CFStringRef) @"%+#", NULL,
		kCFStringEncodingUTF8) autorelease];
}

- (NSString*) fmStringByAddingPercentEscapes; {
    //NSMutableString *escaped = [NSMutableString stringWithString:(NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)self, NULL, NULL, kCFStringEncodingUTF8)];
    NSMutableString *escaped = [NSMutableString stringWithString:[self fmStringByAddingPercentEscapesb]];
    
    [escaped replaceOccurrencesOfString:@":" withString:@"%3a"  options:0 range:NSMakeRange(0, [escaped length])];
    [escaped replaceOccurrencesOfString:@" " withString:@"_"    options:0 range:NSMakeRange(0, [escaped length])];
    [escaped replaceOccurrencesOfString:@"%" withString:@"_"    options:0 range:NSMakeRange(0, [escaped length])];
    
    // notice this is the same thing that fmFilenameFriendlyString does
    [escaped replaceOccurrencesOfString:@"/" withString:@"_"  options:0 range:NSMakeRange(0, [escaped length])];
    
    
    return escaped;
}

- (NSString *) fmStringByAddingPercentEscapesWithExceptions:(NSString*)ex; {
	return [(NSString *) CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef) self, (CFStringRef)ex, NULL, kCFStringEncodingUTF8) autorelease];
}

- (NSString *) fmStringByReplacingPercentEscapes; {
    return [(NSString*) CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef) self, CFSTR("")) autorelease];
}

- (NSString*) fmFilenameFriendlyString; {
    NSMutableString *s = [NSMutableString stringWithString:self];
    
    [s replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0, [s length])];
    
    return s;
}

#if !TARGET_OS_IPHONE
- (NSData*) fmGetRTFDWithDefaultFont:(NSFont*) theFont {
    
    NSMutableAttributedString *a = [[[NSMutableAttributedString alloc] initWithString:self] autorelease];
    
    if (theFont) {
        [a addAttribute:NSFontAttributeName value:theFont range:NSMakeRange(0, [a length])];
    }
    
    return [a RTFDFromRange:NSMakeRange(0, [self length]) documentAttributes:nil];
}
#endif


- (NSArray*) paragraphsForRange:(NSRange)r {
    
    debug(@"r: %@", NSStringFromRange(r));
    /*
     what about these for the newline chars?
     U+000D (\r or CR)
     U+000 A (\n or LF)
     U+2028 (Unicode line separator)
     U+2029 (Unicode paragraph separator) \r\n , in that order (also known as CRLF)
     */
    
    NSMutableArray *ranges = [NSMutableArray array];
    NSString *srange;
    
    unichar c;
    int startLocation   = r.location;
    int lastLocation    = startLocation;
    int i               = startLocation;
    int end             = r.location + r.length;
    BOOL lastWasNewline = NO;
    
    while (i < end) {
        
        c = [self characterAtIndex:i++];
        
        if (c == '\r' || c == '\n') {
            NSRange lineRange = NSMakeRange(lastLocation, (i - 1) - lastLocation);
            srange = NSStringFromRange(lineRange);
            [ranges addObject:srange];
            
            while ((i < end) &&
                   ([self characterAtIndex:i] == '\r' ||
                    [self characterAtIndex:i] == '\n'))
            {
                i++;
            }
            
            lastWasNewline  = YES;
            
            lastLocation = i;
        }
        else {
            lastWasNewline = NO;
        }
    }
    
    if (!lastWasNewline) {
        NSRange lineRange = NSMakeRange(lastLocation, i - lastLocation);
        srange = NSStringFromRange(lineRange);
        [ranges addObject:srange];
        //debug(@"did we forget about '%@'?", );
    }
    
    return ranges;
}

- (int) countOfWhitespacePrefixCharacters {
    
    int i = 0;
    unichar c;
    while (i < [self length] &&
           (c = [self characterAtIndex:i]) &&
           (c is ' ' || c is '\t'))
    {
        i++;
    }
    
    return i;
}


#if !TARGET_OS_IPHONE
- (OSStatus) pathToFSRef:(FSRef *)outRef
{
    CFURLRef	tempURL = NULL;
    Boolean	gotRef = false;
    
    tempURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)self,
                                            kCFURLPOSIXPathStyle, false);
    
    //debug(@"inPath: %@", inPath);
    
    if (tempURL == NULL) {
        debug(@"Can't find inPath: %@", self);
        return fnfErr;
    }
    
    gotRef = CFURLGetFSRef(tempURL, outRef);
    
    CFRelease(tempURL);
    
    if (gotRef == false) {
        debug(@"CFURLGetFSRef returned false.");
        return fnfErr;
    }
    
    return noErr;
}
#endif


- (unsigned int) hexValue {
    
    const char *cptr = [self UTF8String];
    
    unsigned int i, j = 0;
    
    while (cptr && *cptr && isxdigit(*cptr))
    {
        i = *cptr++ - '0';
        if (9 < i)
            i -= 7;
        j <<= 4;
        j |= (i & 0x0f);
    }
    
    return(j);
}

#if !TARGET_OS_IPHONE
// fraser spears wrote this, and even though I have no use for it right now, it's nice to have around.
// http://www.livejournal.com/users/fraserspeirs/775920.html
- (NSString *)stringByRunningShellScript: (NSString *)scriptPath {
    NSString *filePath = nil;
    
    do { // Find a unique non-existing file name in /tmp
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        NSString *uuidString = (NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
        CFRelease(uuid);
        filePath = [NSString stringWithFormat: @"/tmp/%@.txt", uuidString];
        [uuidString release];
    }
    while([[NSFileManager defaultManager] fileExistsAtPath: filePath]);
    
    NSError *err = nil;
    // Write self into that file
    [self writeToFile: filePath atomically: YES encoding:NSUTF8StringEncoding error:&err];
    
    // Create task and args.  The technique here is that
    // we write the file as above and then call the task
    // passing the path to the file as $1.
    NSPipe *outPipe = [NSPipe pipe];
    NSFileHandle *outFileHandle = [outPipe fileHandleForReading];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath: scriptPath];
    [task setArguments: [NSArray arrayWithObject: filePath]];
    [task setStandardOutput: outPipe];
    
    // Launch and do this synchronously
    [task launch];
    [task waitUntilExit];
    
    // Delete the temp file
    [[NSFileManager defaultManager] removeItemAtPath:filePath error: nil];
    
    // Check for an error
    if([task terminationStatus] != 0) {
        // Problem with the script, so just return a copy of ourselves.
        // Maybe an NSException should be thrown instead.
        [task release];
        return [[self copy] autorelease];
    }
    else {
        // Success, so suck out the stdout and return it as an autoreleased string.
        NSData *data = [outFileHandle readDataToEndOfFile];
        [task release];
        return [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
    }
}
#endif


+ (id) stringWithData:(NSData *)data; {
    id s = [[self alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [s autorelease];
}

- (NSData*) data {
    return [self dataUsingEncoding:NSUTF8StringEncoding];
}

+ (id) stringWithContentsOfUTF8File:(NSString*)path {
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}



- (NSString*) fmlower {
    
    int len = [self length];
    unichar *c = malloc((sizeof(unichar) * len) + 1);
    
    [self getCharacters:c];
    int x = 0;
    
    // FIXME - this exact code is in VPMarkup as well.  refactor this.
    
    for (x = 0; x < len; x++) {
        
        if (c[x] > 64 && c[x] < 91) {
            c[x] += 32;
        }
        else if (c[x] > 191 && c[x] < 221) {
            // this will be faster the more special conditions we get in here.
            
            // FIXME - refactor this with VPMarkup
            // FIXME - add a bunch more in here... look them up in bbedit.
            // FIXME - use a case statment 
            
            if (c[x] == 192) {
                c[x] = 224;
            }
            else if (c[x] == 193) {
                c[x] = 225;
            }
            else if (c[x] == 194) {
                c[x] = 226;
            }
            else if (c[x] == 195) { // Ã
                c[x] = 227;
            }
            
            else if (c[x] == 196) { // Ä
                c[x] = 228;
            }
            else if (c[x] == 209) { // Ñ
                c[x] = 241;
            } 
            else if (c[x] == 214) { // Ö
                c[x] = 246;
            } 
            else if (c[x] == 220) { // cap umlaut
                c[x] = 252;
            }
            
        }
    }
    
    NSString *s = [[[NSString alloc] initWithCharacters:c length:len] autorelease];
    
    free(c);
    
    return s;
}


+ (id) stringWithUUID {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = (NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    [uuidString autorelease];
    return [uuidString lowercaseString];
}

#if !TARGET_OS_IPHONE
// apple sample code
// http://developer.apple.com/documentation/Cocoa/Conceptual/LowLevelFileMgmt/Tasks/ResolvingAliases.html
- (NSString*) stringByResolvingFinderAlias; {
    NSString *resolvedPath = nil;
    CFURLRef url;
    
    url = CFURLCreateWithFileSystemPath(NULL /*allocator*/, (CFStringRef)self,
                                        kCFURLPOSIXPathStyle, NO /*isDirectory*/);
    if (url != NULL) {
        
        FSRef fsRef;
        if (CFURLGetFSRef(url, &fsRef)) {
            
            Boolean targetIsFolder, wasAliased;
            if (FSResolveAliasFile (&fsRef, true /*resolveAliasChains*/, 
                                    &targetIsFolder, &wasAliased) == noErr && wasAliased)
            {
                CFURLRef resolvedUrl = CFURLCreateFromFSRef(NULL, &fsRef);
                if (resolvedUrl != NULL) {
                    resolvedPath = [(NSString*)
                    CFURLCopyFileSystemPath(resolvedUrl,
                                            kCFURLPOSIXPathStyle) autorelease];
                    CFRelease(resolvedUrl);
                }
            }
        }
        CFRelease(url);
    }
    
    if (resolvedPath == nil) {
        return [NSString stringWithString:self];
    }
    
    return resolvedPath;
}
#endif

@end


@implementation NSMutableString (FMNSMutableStringAdditions)

- (void)normalizeStringEndings {
    [self replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:0 range:NSMakeRange(0, [self length])];
    [self replaceOccurrencesOfString:@"\r"   withString:@"\n" options:0 range:NSMakeRange(0, [self length])];
}

- (void)normalizeStringEndingsInRange:(NSRange)r {
    [self replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:0 range:r];
    [self replaceOccurrencesOfString:@"\r"   withString:@"\n" options:0 range:r];
}


- (void)replace:(NSString*)searchingFor with:(NSString*)replaceWith {
    [self replaceOccurrencesOfString:searchingFor
                          withString:replaceWith
                             options:0
                               range:NSMakeRange(0, [self length])];
}

@end
