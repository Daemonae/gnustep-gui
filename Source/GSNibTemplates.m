/** <title>GSNibTemplates</title>

   <abstract>Contains all of the private classes used in .gorm files.</abstract>

   Copyright (C) 2003 Free Software Foundation, Inc.

   Author: Gregory John Casamento
   Date: July 2003.
   
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
   License along with this library;
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/ 

// #include "gnustep/gui/config.h"
#include <Foundation/NSClassDescription.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSException.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSKeyValueCoding.h>
#include "AppKit/NSMenu.h"
#include "AppKit/NSControl.h"
#include "AppKit/NSImage.h"
#include "AppKit/NSSound.h"
#include "AppKit/NSView.h"
#include "AppKit/NSTextView.h"
#include "AppKit/NSWindow.h"
#include <AppKit/NSNibLoading.h>
#include <AppKit/NSNibConnector.h>
#include <AppKit/NSApplication.h>
#include <GNUstepBase/GSObjCRuntime.h>
#include <GNUstepGUI/GSNibTemplates.h>

static const int currentVersion = 1; // GSNibItem version number...

@interface NSApplication (GSNibContainer)
- (void)_deactivateVisibleWindow: (NSWindow *)win;
@end

@implementation NSApplication (GSNibContainer)
/* Since awakeWithContext often gets called before the the app becomes
   active, [win -orderFront:] requests get ignored, so we add the window
   to the inactive list, so it gets sent an -orderFront when the app
   becomes active. */
- (void) _deactivateVisibleWindow: (NSWindow *)win
{
  if (_inactive)
    [_inactive addObject: win];
}
@end

/*
 *	The GSNibContainer class manages the internals of a nib file.
 */
@implementation GSNibContainer

+ (void) initialize
{
  if (self == [GSNibContainer class])
    {
      [self setVersion: GNUSTEP_NIB_VERSION];
    }
}

- (void) awakeWithContext: (NSDictionary*)context
{
  if (_isAwake == NO)
    {
      NSEnumerator	*enumerator;
      NSNibConnector	*connection;
      NSString		*key;
      NSArray		*visible;
      NSMenu		*menu;

      _isAwake = YES;
      /*
       *	Add local entries into name table.
       */
      if ([context count] > 0)
	{
	  [nameTable addEntriesFromDictionary: context];
	}

      /*
       *	Now establish all connections by taking the names
       *	stored in the connection objects, and replaciong them
       *	with the corresponding values from the name table
       *	before telling the connections to establish themselves.
       */
      enumerator = [connections objectEnumerator];
      while ((connection = [enumerator nextObject]) != nil)
	{
	  id	val;

	  val = [nameTable objectForKey: [connection source]];
	  [connection setSource: val];
	  val = [nameTable objectForKey: [connection destination]];
	  [connection setDestination: val];
	  [connection establishConnection];
	  // release the connections, now that they have been established.
	  RELEASE(connection); 
	}

      /*
       * Now tell all the objects that they have been loaded from
       * a nib.
       */
      enumerator = [nameTable keyEnumerator];
      while ((key = [enumerator nextObject]) != nil)
	{
	  if ([context objectForKey: key] == nil || 
	      [key isEqualToString: @"NSOwner"]) // we want to send the message to the owner
	    {
	      id	o;

	      o = [nameTable objectForKey: key];
	      if ([o respondsToSelector: @selector(awakeFromNib)])
		{
		  [o awakeFromNib];
		}
	    }
	}
    
      /*
       * See if there are objects that should be made visible.
       */
      visible = [nameTable objectForKey: @"NSVisible"];
      if (visible != nil
	&& [visible isKindOfClass: [NSArray class]] == YES)
	{
	  unsigned	pos = [visible count];

	  while (pos-- > 0)
	    {
	      NSWindow *win = [visible objectAtIndex: pos];
	      if ([NSApp isActive])
		[win orderFront: self];
	      else
		[NSApp _deactivateVisibleWindow: win];
	    }
	}

      /*
       * See if there is a main menu to be set.
       */
      menu = [nameTable objectForKey: @"NSMenu"];
      if (menu != nil && [menu isKindOfClass: [NSMenu class]] == YES)
	{
	  [NSApp setMainMenu: menu];
	}

      /*
       * Now remove any objects added from the context dictionary.
       */
      if ([context count] > 0)
	{
	  [nameTable removeObjectsForKeys: [context allKeys]];
	}
    }
}

- (NSMutableArray*) connections
{
  return connections;
}

- (void) dealloc
{
  RELEASE(nameTable);
  RELEASE(connections);
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeObject: nameTable];
  [aCoder encodeObject: connections];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      nameTable = [[NSMutableDictionary alloc] initWithCapacity: 8];
      connections = [[NSMutableArray alloc] initWithCapacity: 8];
    }
  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  int version = [aCoder versionForClassName: @"GSNibContainer"]; 
  
  if(version == GNUSTEP_NIB_VERSION)
    {
      [aCoder decodeValueOfObjCType: @encode(id) at: &nameTable];
      [aCoder decodeValueOfObjCType: @encode(id) at: &connections];
    }

  return self;
}

- (NSMutableDictionary*) nameTable
{
  return nameTable;
}
@end

// The first standin objects here are for views and normal objects like controllers
// or data sources.
@implementation	GSNibItem
+ (void) initialize
{
  if (self == [GSNibItem class])
    {
      [self setVersion: currentVersion];
    }
}

- (void) dealloc
{
  RELEASE(theClass);
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeObject: theClass];
  [aCoder encodeRect: theFrame];
  [aCoder encodeValueOfObjCType: @encode(unsigned int) 
	  at: &autoresizingMask];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  int version = [aCoder versionForClassName: 
			  NSStringFromClass([self class])];

  if (version == 1)
    {
      id		obj;
      Class		cls;
      unsigned int      mask;
      
      [aCoder decodeValueOfObjCType: @encode(id) at: &theClass];
      theFrame = [aCoder decodeRect];
      [aCoder decodeValueOfObjCType: @encode(unsigned int) 
	      at: &mask];
      
      cls = NSClassFromString(theClass);
      if (cls == nil)
	{
	  [NSException raise: NSInternalInconsistencyException
		       format: @"Unable to find class '%@'", theClass];
	}
      
      obj = [cls allocWithZone: [self zone]];
      if (theFrame.size.height > 0 && theFrame.size.width > 0)
	obj = [obj initWithFrame: theFrame];
      else
	obj = [obj init];

      if ([obj respondsToSelector: @selector(setAutoresizingMask:)])
	{
	  [obj setAutoresizingMask: mask];
	}
      
      RELEASE(self);
      return obj;
    }
  else if (version == 0)
    {
      id		obj;
      Class		cls;
      
      [aCoder decodeValueOfObjCType: @encode(id) at: &theClass];
      theFrame = [aCoder decodeRect];
      
      cls = NSClassFromString(theClass);
      if (cls == nil)
	{
	  [NSException raise: NSInternalInconsistencyException
		       format: @"Unable to find class '%@'", theClass];
	}
      
      obj = [cls allocWithZone: [self zone]];
      if (theFrame.size.height > 0 && theFrame.size.width > 0)
	obj = [obj initWithFrame: theFrame];
      else
	obj = [obj init];
      
      RELEASE(self);
      return obj;
    }
  else
    {
      NSLog(@"no initWithCoder for this version");
      RELEASE(self);
      return nil;
    }
}

@end

@implementation	GSCustomView
+ (void) initialize
{
  if (self == [GSCustomView class])
    {
      [self setVersion: currentVersion];
    }
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [super encodeWithCoder: aCoder];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  return [super initWithCoder: aCoder];
}
@end

/*
  These stand-ins are here for use by GUI elements within Gorm.   Since each gui element
  has it's own "designated initializer" it's important to provide a division between these
  so that when they are loaded, the application will call the correct initializer. 
  
  Some "tricks" are employed in this code.   For instance the use of initWithCoder and
  encodeWithCoder directly as opposed to using the encodeObjC..  methods is the obvious
  standout.  To understand this it's necessary to explain a little about how encoding itself
  works.

  When the model is saved by the Interface Builder (whether Gorm or another 
  IB equivalent) these classes should be used to substitute for the actual classes.  The actual
  classes are encoded as part of it, but since they are being replaced we can't use the normal
  encode methods to do it and must encode it directly.

  Also, the reason for encoding the superclass itself is that by doing so the unarchiver knows
  what version is referred to by the encoded object.  This way we can replace the object with
  a substitute class which will allow it to create itself as the custom class when read it by
  the application, and using the encoding system to do it in a clean way.
*/
@implementation GSClassSwapper
+ (void) initialize
{
  if (self == [GSClassSwapper class]) 
    { 
      [self setVersion: GSSWAPPER_VERSION];
    }
}

- (id) initWithObject: (id)object className: (NSString *)className superClassName: (NSString *)superClassName
{
  if((self = [self init]) != nil)
    {
      NSDebugLog(@"Created template %@ -> %@",NSStringFromClass([self class]), className);
      ASSIGN(_object, object);
      ASSIGN(_className, [className copy]);
      NSAssert(![className isEqualToString: superClassName], NSInvalidArgumentException);
      _superClass = NSClassFromString(superClassName);
      if(_superClass == nil)
	{
	  [NSException raise: NSInternalInconsistencyException
		       format: @"Unable to find class '%@'", superClassName];
	}
    }
  return self;
}

- init
{
  if((self = [super init]) != nil)
    {
      _className = nil;
      _superClass = nil;
      _object = nil;
    } 
  return self;
}

- (void) setClassName: (NSString *)name
{
  ASSIGN(_className, [name copy]);
}

- (NSString *)className
{
  return _className;
}

- (id) initWithCoder: (NSCoder *)coder
{
  id obj = nil;
  int version = [coder versionForClassName: @"GSClassSwapper"];
  if(version == 0)
    {
      if((self = [super init]) != nil)
	{
	  // decode class/superclass...
	  [coder decodeValueOfObjCType: @encode(id) at: &_className];  
	  [coder decodeValueOfObjCType: @encode(Class) at: &_superClass];

	  // if we are living within the interface builder app, then don't try to 
	  // morph into the subclass.
	  if([self respondsToSelector: @selector(isInInterfaceBuilder)])
	    {
	      obj = [[_superClass alloc] initWithCoder: coder]; // unarchive the object...
	    }
	  else
	    {
	      Class aClass = NSClassFromString(_className);
	      if(aClass == 0)
		{
		  [NSException raise: NSInternalInconsistencyException
			       format: @"Unable to find class '%@'", _className];
		}
	  
	      // Initialize the object...  dont call decode, since this wont 
	      // allow us to instantiate the class we want. 
	      obj = [[aClass alloc] initWithCoder: coder]; // unarchive the object...
	    }
	}
    }

  // Do this here since we are not using decode to do this.
  // Normally decode does a retain, so we must do it here.
  RETAIN(obj); 

  // change the class of the instance to the one we want to see...
  return obj;
}

- (void) encodeWithCoder: (NSCoder *)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(id) at: &_className];  
  [aCoder encodeValueOfObjCType: @encode(Class) at: &_superClass];

  if(_object != nil)
    {
      // Don't call encodeValue, the way templates are used will prevent
      // it from being saved correctly.  Just call encodeWithCoder directly.
      [_object encodeWithCoder: aCoder]; 
    }
}
@end

@implementation GSWindowTemplate
+ (void) initialize
{
  if (self == [GSWindowTemplate class]) 
    { 
      [self setVersion: GSWINDOWT_VERSION];
    }
}

- (BOOL)deferFlag
{
  return _deferFlag;
}

- (void)setDeferFlag: (BOOL)flag
{
  _deferFlag = flag;
}

// NSCoding...
- (id) initWithCoder: (NSCoder *)coder
{
  id obj = [super initWithCoder: coder];
  if(obj != nil)
    {
      NSView *contentView = nil;

      // decode the defer flag...
      [coder decodeValueOfObjCType: @encode(BOOL) at: &_deferFlag];      

      if(![self respondsToSelector: @selector(isInInterfaceBuilder)])
      {
	if(GSGetInstanceMethodNotInherited([obj class], @selector(initWithContentRect:styleMask:backing:defer:)) != NULL)
	  {
	    // if we are not in interface builder, call 
	    // designated initializer per spec...
	    contentView = [obj contentView];
	    obj = [obj initWithContentRect: [obj frame]
		       styleMask: [obj styleMask]
		       backing: [obj backingType]
		       defer: _deferFlag];
	    
	    // set the content view back
	    [obj setContentView: contentView];
	  }
      }
      RELEASE(self);
    }
  return obj;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  [coder encodeValueOfObjCType: @encode(BOOL) at: &_deferFlag];      
}
@end

@implementation GSViewTemplate
+ (void) initialize
{
  if (self == [GSViewTemplate class]) 
    {
      [self setVersion: GSVIEWT_VERSION];
    }
}

- (id) initWithCoder: (NSCoder *)coder
{
  id obj = [super initWithCoder: coder];
  if(obj != nil)
    {
      if(![self respondsToSelector: @selector(isInInterfaceBuilder)])
      {
	if(GSGetInstanceMethodNotInherited([obj class],@selector(initWithFrame:)) != NULL)
	  {
	    NSRect theFrame = [obj frame];
	    obj =  [obj initWithFrame: theFrame];
	  }
      }
      RELEASE(self);
    }
  return obj;
}
@end

// Template for any classes which derive from NSText
@implementation GSTextTemplate
+ (void) initialize
{
  if (self == [GSTextTemplate class]) 
    {
      [self setVersion: GSTEXTT_VERSION];
    }
}

- (id) initWithCoder: (NSCoder *)coder
{
  id     obj = [super initWithCoder: coder];
  if(obj != nil)
    {
      if(![self respondsToSelector: @selector(isInInterfaceBuilder)])
      {
	if(GSGetInstanceMethodNotInherited([obj class],@selector(initWithFrame:)) != NULL)
	  {
	    NSRect theFrame = [obj frame]; 
	    obj = [obj initWithFrame: theFrame];
	  }
      }
      RELEASE(self);
    }
  return obj;
}
@end

// Template for any classes which derive from GSTextView
@implementation GSTextViewTemplate
+ (void) initialize
{
  if (self == [GSTextViewTemplate class]) 
    {
      [self setVersion: GSTEXTVIEWT_VERSION];
    }
}

- (id) initWithCoder: (NSCoder *)coder
{
  id     obj = [super initWithCoder: coder];
  if(obj != nil)
    {
      if(![self respondsToSelector: @selector(isInInterfaceBuilder)])
      {
	if(GSGetInstanceMethodNotInherited([obj class],@selector(initWithFrame:textContainer:)) != NULL)
	  {
	    NSRect theFrame = [obj frame];
	    id textContainer = [obj textContainer];
	    obj = [obj initWithFrame: theFrame 
		       textContainer: textContainer];
	  }
      }
      RELEASE(self);
    }
  return obj;
}
@end

// Template for any classes which derive from NSMenu.
@implementation GSMenuTemplate
+ (void) initialize
{
  if (self == [GSMenuTemplate class]) 
    {
      [self setVersion: GSMENUT_VERSION];
    }
}

- (id) initWithCoder: (NSCoder *)coder
{
  id     obj = [super initWithCoder: coder];
  if(obj != nil)
    {
      if(![self respondsToSelector: @selector(isInInterfaceBuilder)])
      {
	if(GSGetInstanceMethodNotInherited([obj class],@selector(initWithTitle:)) != NULL)
	  {
	    NSString *theTitle = [obj title]; 
	    obj = [obj initWithTitle: theTitle];
	  }
      }
      RELEASE(self);
    }
  return obj;
}
@end


// Template for any classes which derive from NSControl
@implementation GSControlTemplate
+ (void) initialize
{
  if (self == [GSControlTemplate class]) 
    {
      [self setVersion: GSCONTROLT_VERSION];
    }
}

- (id) initWithCoder: (NSCoder *)coder
{
  id     obj = [super initWithCoder: coder];
  if(obj != nil)
    {
      if(![self respondsToSelector: @selector(isInInterfaceBuilder)])
      {
	if(GSGetInstanceMethodNotInherited([obj class],@selector(initWithFrame:)) != NULL)
	  {
	    NSRect theFrame = [obj frame]; 
	    obj = [obj initWithFrame: theFrame];
	  }
      }
      RELEASE(self);
    }
  return obj;
}
@end

@implementation GSObjectTemplate
+ (void) initialize
{
  if (self == [GSObjectTemplate class]) 
    {
      [self setVersion: GSOBJECTT_VERSION];
    }
}

- (id) initWithCoder: (NSCoder *)coder
{
  id     obj = [super initWithCoder: coder];
  if(obj != nil)
    {
      if(![self respondsToSelector: @selector(isInInterfaceBuilder)])
      {
	if(GSGetInstanceMethodNotInherited([obj class],@selector(init)) != NULL)
	  {
	    obj = [self init];
	  }
      }
      RELEASE(self);
    }
  return obj;
}
@end

@interface NSObject (NibInstantiation)
- (id) nibInstantiate;
@end

@implementation NSObject (NibInstantiation)
- (id) nibInstantiate
{
  // default implementation of nibInstantiate
  return self;
}
@end

// Order in this factory method is very important.  Which template to create must be determined
// in sequence because of the class hierarchy.
@implementation GSTemplateFactory
+ (id) templateForObject: (id) object 
	   withClassName: (NSString *)className
      withSuperClassName: (NSString *)superClassName
{
  id template = nil;
  if(object != nil)
    {
      // NSData *objectData = nil;
      // [archiver encodeRootObject: object];
      // objectData = [archiver archiverData];
      if ([object isKindOfClass: [NSWindow class]])
	{
	  template = [[GSWindowTemplate alloc] initWithObject: object
					       className: className 
					       superClassName: superClassName];
	}
      else if ([object isKindOfClass: [NSTextView class]])
	{
	  template = [[GSTextViewTemplate alloc] initWithObject: object
						 className: className 
						 superClassName: superClassName];
	}
      else if ([object isKindOfClass: [NSText class]])
	{
	  template = [[GSTextTemplate alloc] initWithObject: object
					     className: className 
					     superClassName: superClassName];
	}
      else if ([object isKindOfClass: [NSControl class]])
	{
	  template = [[GSControlTemplate alloc] initWithObject: object
						className: className 
						superClassName: superClassName];
	}
      else if ([object isKindOfClass: [NSView class]])
	{
	  template = [[GSViewTemplate alloc] initWithObject: object
					     className: className 
					     superClassName: superClassName];
	}
      else if ([object isKindOfClass: [NSMenu class]])
	{
	  template = [[GSMenuTemplate alloc] initWithObject: object
					     className: className 
					     superClassName: superClassName];
	}
      else if ([object isKindOfClass: [NSObject class]]) // for gui elements derived from NSObject
	{
	  template = [[GSObjectTemplate alloc] initWithObject: object
					       className: className 
					       superClassName: superClassName];
	}
    }
  return template;
}
@end

//////////////////////////////////////////////////////////////////////////////////////////
////////////////// DEPRECATED TEMPLATES ----- THESE SHOULD NOT BE USED  //////////////////
//////////////////////////////////////////////////////////////////////////////////////////

/*
  These templates are from the old system, which had some issues.  Currently I believe
  that NSWindowTemplate was the only one seeing use, so it is the only one included.
  if any more are needed they will be added back.   
  
  As these classes are deprecated, they should disappear from the gnustep distribution
  in the next major release.
*/

@implementation NSWindowTemplate
+ (void) initialize
{
  if (self == [NSWindowTemplate class]) 
    { 
      [self setVersion: 0];
    }
}

- (void) dealloc
{
  RELEASE(_parentClassName);
  RELEASE(_className);
  [super dealloc];
}

- init
{
  [super init];

  // Start initially with the highest level class...
  ASSIGN(_className, NSStringFromClass([super class]));
  ASSIGN(_parentClassName, NSStringFromClass([super class]));

  // defer flag...
  _deferFlag = NO;

  return self;
}

- (id) initWithCoder: (NSCoder *)aCoder
{
  [aCoder decodeValueOfObjCType: @encode(id) at: &_className];  
  [aCoder decodeValueOfObjCType: @encode(id) at: &_parentClassName];  
  [aCoder decodeValueOfObjCType: @encode(BOOL) at: &_deferFlag];  
  return [super initWithCoder: aCoder];
}

- (void) encodeWithCoder: (NSCoder *)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(id) at: &_className];  
  [aCoder encodeValueOfObjCType: @encode(id) at: &_parentClassName];  
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &_deferFlag];  
  [super encodeWithCoder: aCoder];
}

- (id) awakeAfterUsingCoder: (NSCoder *)coder
{
  if([self respondsToSelector: @selector(isInInterfaceBuilder)])
    {
      // if we live in the interface builder, give them an instance of
      // the parent, not the child..
      [self setClassName: _parentClassName];
    }
  
  return [self instantiateObject: coder];
}

- (id) instantiateObject: (NSCoder *)coder
{
  id obj = nil;
  Class aClass = NSClassFromString(_className);      
  
  if (aClass == nil)
    {
	[NSException raise: NSInternalInconsistencyException
		     format: @"Unable to find class '%@'", _className];
    }
  
  obj = [[aClass allocWithZone: [self zone]] 
	    initWithContentRect: [self frame]
	    styleMask: [self styleMask]
	    backing: [self backingType]
	    defer: _deferFlag];
    
    // fill in actual object from template...
  [obj setBackgroundColor: [self backgroundColor]];
  [(NSWindow*)obj setContentView: [self contentView]];
  [obj setFrameAutosaveName: [self frameAutosaveName]];
  [obj setHidesOnDeactivate: [self hidesOnDeactivate]];
  [obj setInitialFirstResponder: [self initialFirstResponder]];
  [obj setAutodisplay: [self isAutodisplay]];
  [obj setReleasedWhenClosed: [self isReleasedWhenClosed]];
  [obj _setVisible: [self isVisible]];
  [obj setTitle: [self title]];
  [obj setFrame: [self frame] display: NO];
  
  RELEASE(self);
  return obj;
}

// setters and getters...
- (void) setClassName: (NSString *)name
{
  ASSIGN(_className, name);
}

- (NSString *)className
{
  return _className;
}

- (BOOL)deferFlag
{
  return _deferFlag;
}

- (void)setDeferFlag: (BOOL)flag
{
  _deferFlag = flag;
}
@end