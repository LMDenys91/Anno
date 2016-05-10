//
//  AnnoFilter.m
//  Anno
//
//  Copyright (c) 2016 Lucas. All rights reserved.
//

#import "AnnoFilter.h"
#import "OsiriXAPI/browserController.h"
#import "DCMObject.h"
#import "DCMAttribute.h"
#import "DCMAttributeTag.h"

@implementation AnnoFilter

- (void) initPlugin
{
}

- (long) filterImage:(NSString*) menuName
{
    self.studyIndex = 1;
    self.amountOfStudies = [[[BrowserController currentBrowser] databaseSelection] count];
    [self loadJSONDictionary];
    [NSBundle loadNibNamed:@"Annotator"
                     owner:self];
   // [NSApp beginSheet: window
      // modalForWindow:[NSApp keyWindow]
     //   modalDelegate:self
       //didEndSelector:nil
         // contextInfo:nil];
    [self loadUI];
    return 0;
}

- (IBAction)annotateNormal:(id)sender
{
    [self annotateStudy: 0
                withComment:self.commentsText.stringValue];
}

- (IBAction)annotateAbnormal:(id)sender {
    [self annotateStudy: 1
                withComment:self.commentsText.stringValue];
}

- (IBAction)annotateSkipped:(id)sender {
    [self annotateStudy: 2
            withComment:self.commentsText.stringValue];
}

- (void) annotateStudy:(int) anno withComment:(NSString*)comment
{
    NSString *type = @"";
    switch(anno) {
        case 0:
            type = @"normal";
            break;
        case 1:
            type = @"abnormal";
            break;
        case 2:
            type = @"skipped";
            break;
        default:
            [self reportMessage:[NSString stringWithFormat:@"Corrupted annotation."]];
    }
    NSLog(@"Annotation: %@", type);
    NSLog(@"Comments: %@", comment);
    [self writeJSONforAnnotation:type andComments:comment];
    [self createJSON];
    [self loadPatient:1];
 }

- (void) loadPatient: (int) direction
{
    NSArray* displayedViewers = [ViewerController getDisplayed2DViewers];
    if ([displayedViewers count] > 0) viewerController = displayedViewers[0];
    if(direction > 0 && self.studyIndex>=self.amountOfStudies) {
        NSLog(@"The last patient has been annotated.");
        [self reportMessage:[NSString stringWithFormat:@"All studies have been annotated. You can still go back and make changes, or stop the annotation process."]];
    }
    else if(direction < 0 && self.studyIndex <= 1) NSLog(@"You can't go back, this is the first patient.");
    else {
        [[BrowserController currentBrowser] loadNextPatient:viewerController.fileList[0]
                                                           :direction
                                                           :viewerController
                                                           :YES
                                              keyImagesOnly: TRUE];
        self.studyIndex += direction;
        //[NSThread sleepForTimeInterval:2.0f];
        NSLog(@"Patient ID after: %@ %*s", self.patientId, 120, "*");
        [self loadUI];
        [window makeKeyAndOrderFront:self];
    }
}

- (IBAction)back:(id)sender {
    [self loadPatient:-1];
}

- (IBAction)stop:(id)sender {
    // Write the annotations dictionary to the JSON
    [self createJSON];
    [window orderOut:sender];
    [NSApp endSheet:window
         returnCode:[sender tag]];
}

- (NSString*) getValueForTag: (NSString*) dicomTag {
    NSArray* displayedViewers = [ViewerController getDisplayed2DViewers];
    if ([displayedViewers count] > 0) viewerController = displayedViewers[0];
    NSArray         *pixList = [viewerController pixList: 0];
    long            curSlice = [[viewerController imageView] curImage];
    DCMPix          *curPix = [pixList objectAtIndex: curSlice];
    NSString        *file_path = [curPix sourceFile];
    DCMObject       *dcmObj = [DCMObject objectWithContentsOfFile:file_path
                                                decodingPixelData:NO];
    DCMAttributeTag *tag = [DCMAttributeTag tagWithName:dicomTag];
    if (!tag) tag = [DCMAttributeTag tagWithTagString:dicomTag];
    NSString        *val = @"empty";
    DCMAttribute    *attr;
    if (tag && tag.group && tag.element)
    {
        attr = [dcmObj attributeForTag:tag];
        val = [[attr value] description];
    }
    if (!val) return [NSString stringWithFormat:@"Unknown %@, %lu", dicomTag, self.studyIndex];
    return val;
}

- (void) loadUI {
    if(self.studyIndex == 1)[self.backButton setTransparent:YES];
    else [self.backButton setTransparent:NO];
    [self loadMetaData];
    self.patientProgress.stringValue = [NSString stringWithFormat:@"%lu / %lu", self.studyIndex, self.amountOfStudies];
    self.patientIdLabel.stringValue = [NSString stringWithString:self.patientId];
    self.patientNameLabel.stringValue = [NSString stringWithString:self.patientName];
    self.studyIdLabel.stringValue = [NSString stringWithString:self.studyId];
    NSMutableDictionary * annotations = self.dict;
    if ([[annotations objectForKey:self.patientId] objectForKey:self.studyId]) {
        NSMutableDictionary * thisPatient = [annotations objectForKey:self.patientId];
        NSMutableDictionary * thisStudy = [thisPatient objectForKey:self.studyId];
        self.currentAnnotation.stringValue = [thisStudy objectForKey:@"annotation"];
        self.commentsText.stringValue = [thisStudy objectForKey:@"comments"];
    }
    else {
        self.currentAnnotation.stringValue = @"Not labeled";
        self.commentsText.stringValue = @"";
    }
}

- (void) loadMetaData {
    self.patientId = [self getValueForTag:@"PatientID"];
    self.patientName = [self getValueForTag:@"PatientsName"];
    self.studyId = [self getValueForTag:@"StudyInstanceUID"];
}

- (void) loadJSONDictionary {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [@"~/Desktop/annotations.json" stringByStandardizingPath];
    NSError *error = nil;
    if ([fileManager fileExistsAtPath: filePath] == NO) {
        self.dict = [NSMutableDictionary new];
        [self reportMessage:@"Created new JSON" atFilePath:filePath];
    }
    else {
        // Load the file into an NSData object called JSONData
        NSData *JSONData = [NSData dataWithContentsOfFile:filePath
                                                  options:NSDataReadingMappedIfSafe
                                                    error:&error];
        // Create an Objective-C object from JSON Data
        id JSONObject = [NSJSONSerialization JSONObjectWithData:JSONData
                                                        options:NSJSONReadingAllowFragments
                                                          error:&error];
        if(error) {
            [self reportJSONerror:error atFilePath:filePath];
        }
        if([JSONObject isKindOfClass:[NSDictionary class]])
        {
            self.dict = [[NSMutableDictionary dictionaryWithDictionary:JSONObject] mutableCopy];
            [self reportMessage:@"Writing to existing JSON" atFilePath:filePath];
        }
        else
        {
            [self reportJSONerror:error atFilePath:filePath];
            NSLog(@"Not a dictionary");
        }
    }
}

- (void) writeJSONforAnnotation: (NSString*)type andComments:(NSString*) comments {
    // If the patient doesn't exist yet, add an entry for the patient
    if (![self.dict objectForKey:[NSString stringWithString:self.patientId]]) {
        [self.dict setObject:[[NSMutableDictionary dictionaryWithDictionary:@{@"patientName": [NSString stringWithString:self.patientName],
                                                                               [NSString stringWithString:self.studyId]:
                                                                                   [[NSMutableDictionary dictionaryWithDictionary:@{@"annotation": type,
                                                                                                                                   @"comments": [NSString stringWithString:comments]
                                                                                                                                   }
                                                                                     ] mutableCopy]
                                                                               }
                                ] mutableCopy]
                        forKey:[NSString stringWithString:self.patientId]];
    }
    // If the patient exists already, add/overwrite the entry for this study
    else {
        [self.dict setObject:[[self.dict objectForKey:[NSString stringWithString:self.patientId]] mutableCopy]
                      forKey:[NSString stringWithString:self.patientId]];
         [[self.dict objectForKey:[NSString stringWithString:self.patientId]] setObject:[[NSMutableDictionary dictionaryWithDictionary:@{@"annotation": type,
                                                                                                                                         @"comments": [NSString stringWithString:comments]
                                                                                                                                         }
                                                                                          ] mutableCopy]
                                                                                 forKey:[NSString stringWithString:self.studyId]];
         }
}

- (void) createJSON {
    NSString *filePath = [@"~/Desktop/annotations.json" stringByStandardizingPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:[self.dict mutableCopy]
                                                       options:NSJSONReadingAllowFragments
                                                         error:&error];
    if(error) {
        [self reportJSONerror:error atFilePath:filePath];
    }
    [fileManager createFileAtPath: filePath
                         contents: jsonData
                       attributes: nil];
}

- (void) reportJSONerror: (NSError*) error atFilePath: (NSString*) filePath {
    [self reportMessage:[NSString stringWithFormat:@"Corrupted JSON: %@", error] atFilePath:filePath];
}

- (void) reportMessage: (NSString*) msg atFilePath: (NSString*) filePath {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: msg];
    NSString* info = [NSString stringWithFormat:@"At filepath: %@", filePath];
    [alert setInformativeText:info];
    [alert addButtonWithTitle:@"Ok"];
    [alert runModal];
}

- (void) reportMessage: (NSString*) msg {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: msg];
    [alert addButtonWithTitle:@"Ok"];
    [alert runModal];
}

@end
