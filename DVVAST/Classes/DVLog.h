//
//  DVLog.h
//  DVVASTSample
//
//  Created by Manuel "StuFF mc" Carrasco Molina on 21.02.13.
//  Copyright (c) 2013 DENIVIP Media. All rights reserved.
//

#if defined DEBUG && defined VAST_LOG && VAST_LOG
    #define VLog(fmt, ...)      NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
    #define VLogC()             VLog(@"");
    #define VLogV(var)          NSLog(@"%s [Line %d] <%p> " #var ": %@", __PRETTY_FUNCTION__, __LINE__, self, var)
    #define VLogR(rect)         VLogV(NSStringFromRect(rect))
    #define VLogS(size)         VLogV(NSStringFromSize(size))
    #define VLogI(var)          NSLog(@"%s [Line %d] " #var ": %d", __PRETTY_FUNCTION__, __LINE__, var)
    #define VLogF(var)          NSLog(@"%s [Line %d] " #var ": %f", __PRETTY_FUNCTION__, __LINE__, var)
    #define VLogB(var)          NSLog(@"%s [Line %d] " #var ": %@", __PRETTY_FUNCTION__, __LINE__, var ? @"YES" : @"NO")
#else
    #define VLog(...)
    #define VLogC()
    #define VLogV(var)
    #define VLogR(rect)
    #define VLogS(size)
    #define VLogI(var)
    #define VLogF(var)
    #define VLogB(var)
#endif