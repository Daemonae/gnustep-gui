/* 
   NSColorWell.h

   NSControl for selecting and display a single color value.

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 1996
   
   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/ 

#ifndef _GNUstep_H_NSColorWell
#define _GNUstep_H_NSColorWell

#include <AppKit/NSControl.h>

@class NSColor;

@interface NSColorWell : NSControl <NSCoding>

{
  // Attributes
  NSColor *_the_color;
  BOOL _is_active;
  BOOL _is_bordered;
  NSRect _wellRect;
  id _target;
  SEL _action;
}

//
// Drawing
//
- (void)drawWellInside:(NSRect)insideRect;

//
// Activating 
//
- (void)activate:(BOOL)exclusive;
- (void)deactivate;
- (BOOL)isActive;

//
// Managing Color 
//
- (NSColor *)color;
- (void)setColor:(NSColor *)color;
- (void)takeColorFrom:(id)sender;

//
// Managing Borders 
//
- (BOOL)isBordered;
- (void)setBordered:(BOOL)bordered;

//
// NSCoding protocol
//
- (void)encodeWithCoder: (NSCoder *)aCoder;
- initWithCoder: (NSCoder *)aDecoder;

@end

#endif // _GNUstep_H_NSColorWell