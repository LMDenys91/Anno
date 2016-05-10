//
//  AnnoFilter.h
//  Anno
//
//  Copyright (c) 2016 Lucas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OsiriXAPI/PluginFilter.h>

@interface AnnoFilter : PluginFilter {

    IBOutlet NSWindow *window;
    
}

- (long) filterImage:(NSString*) menuName;

- (IBAction)annotateNormal:(id)sender;

- (IBAction)annotateAbnormal:(id)sender;

- (IBAction)annotateSkipped:(id)sender;

- (void) annotateStudy:(int) normal withComment:(NSString*) comment;

- (void) loadPatient: (int) direction;

- (IBAction)back:(id)sender;

- (IBAction)stop:(id)sender;

- (NSString*) getValueForTag: (NSString*) dicomTag;

- (void) loadUI;

- (void) loadMetaData;

- (void) loadJSONDictionary;

- (void) writeJSONforAnnotation: (NSString*)type andComments:(NSString*) comments;

- (void) createJSON;

- (void) reportJSONerror: (NSError*) error atFilePath: (NSString*) filePath;

- (void) reportMessage: (NSString*) msg atFilePath: (NSString*) filePath;

- (void) reportMessage: (NSString*) msg;

@property (atomic) long studyIndex;
@property (atomic) long amountOfStudies;
@property (atomic, strong) NSString* patientId;
@property (atomic, strong) NSString* patientName;
@property (atomic, strong) NSString* studyId;
@property (atomic, strong) NSMutableDictionary* dict;

@property (assign) IBOutlet NSButton *normalButton;
@property (assign) IBOutlet NSButton *abnormalButton;
@property (assign) IBOutlet NSTextField *commentsText;
@property (assign) IBOutlet NSTextField *patientIdLabel;
@property (assign) IBOutlet NSTextField *patientNameLabel;
@property (assign) IBOutlet NSTextField *studyIdLabel;
@property (assign) IBOutlet NSTextField *patientProgress;
@property (assign) IBOutlet NSTextField *currentAnnotation;
@property (assign) IBOutlet NSButton *backButton;
@property (assign) IBOutlet NSButton *stopButton;
@property (assign) IBOutlet NSButton *skipButton;

@end
