//
//  HomeViewController.m
//  AppBox
//
//  Created by Vineet Choudhary on 29/08/16.
//  Copyright © 2016 Developer Insider. All rights reserved.
//

#import "HomeViewController.h"

static NSString *const UNIQUE_LINK_SHARED = @"uniqueLinkShared";
static NSString *const UNIQUE_LINK_SHORT = @"uniqueLinkShort";
static NSString *const FILE_NAME_UNIQUE_JSON = @"appinfo.json";

@implementation HomeViewController{
    XCProject *project;
    XCProject *repoProject;
    ScriptType scriptType;
    FileType fileType;
    NSArray *allTeamIds;
    NSBlockOperation *lastfailedOperation;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    project = [[XCProject alloc] init];
    allTeamIds = [KeychainHandler getAllTeamId];
    //Notification Handler
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initBuildRepoProcess:) name:abBuildRepoNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxLogoutHandler:) name:abDropBoxLoggedOutNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLoggedInNotification:) name:abDropBoxLoggedInNotification object:nil];
    
    //setup initial value
    [project setBuildDirectory: [UserData buildLocation]];
    
    //setup dropbox
    DBTransportDefaultConfig *transportConfig = [[DBTransportDefaultConfig alloc] initWithAppKey:abDbAppkey forceForegroundSession:YES];
    [DBClientsManager setupWithTransportConfigDesktop:transportConfig];
//    [DBClientsManager setupWithAppKeyDesktop:abDbAppkey];
    
    //update available memory
    [[NSApplication sharedApplication] updateDropboxUsage];
    
    //Start monitoring internet connection
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        [[AppDelegate appDelegate] setIsInternetConnected:!(status == AFNetworkReachabilityStatusNotReachable)];
        if ([AppDelegate appDelegate].processing){
            if (status == AFNetworkReachabilityStatusNotReachable){
                [self showStatus:abNotConnectedToInternet andShowProgressBar:YES withProgress:-1];
            }else{
                [self showStatus:abConnectedToInternet andShowProgressBar:NO withProgress:-1];
                //restart last failed operation
                if (lastfailedOperation){
                    [lastfailedOperation start];
                    lastfailedOperation = nil;
                }
            }
        }
    }];
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
}

- (void)viewWillAppear{
    [super viewWillAppear];
    [self updateMenuButtons];
    
    //Handle Dropbox Login
    if ([DBClientsManager authorizedClient] == nil) {
        [self performSegueWithIdentifier:@"DropBoxLogin" sender:self];
    }
    [[AppDelegate appDelegate] setIsReadyToBuild:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:abAppBoxReadyToBuildNotification object:self];
}


#pragma mark - Build Repo
- (void)initBuildRepoProcess:(NSNotification *)notification {
    if ([notification.object isKindOfClass:[XCProject class]]) {
        repoProject = notification.object;
        [tabView selectTabViewItem:tabView.tabViewItems.firstObject];
        [self initProjectBuildProcessForURL: repoProject.fullPath];
    }
}

#pragma mark - Controls Action Handler -
#pragma mark → Project / Workspace Controls Action
//Project Path Handler
- (IBAction)projectPathHandler:(NSPathControl *)sender {
    NSURL *projectURL = [sender.URL filePathURL];
    [self initProjectBuildProcessForURL: projectURL];
}

- (void)initProjectBuildProcessForURL:(NSURL *)projectURL {
    if (![project.fullPath isEqualTo:projectURL]){
        [self viewStateForProgressFinish:YES];
        [project setFullPath: projectURL];
        [pathProject setURL:projectURL];
        [self runGetSchemeScript];
    }
}

//Scheme Value Changed
- (IBAction)comboBuildSchemeValueChanged:(NSComboBox *)sender {
    [self updateViewState];
    [project setSelectedSchemes:sender.stringValue];
}

//Team Value Changed
- (IBAction)comboTeamIdValueChanged:(NSComboBox *)sender {
    NSString *teamId;
    if (sender.stringValue.length != 10 || [sender.stringValue containsString:@" "]){
        NSDictionary *team = [[allTeamIds filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.fullName LIKE %@",sender.stringValue]] firstObject];
        teamId = [team valueForKey:abTeamId];
        [project setTeamId: teamId];
    }else{
        [project setTeamId: sender.stringValue];
    }
    [self updateViewState];
}

//Build Type Changed
- (IBAction)comboBuildTypeValueChanged:(NSComboBox *)sender {
    if (![project.buildType isEqualToString:sender.stringValue]){
        [project setBuildType: sender.stringValue];
        if ([project.buildType isEqualToString:BuildTypeAppStore]){
            [self performSegueWithIdentifier:@"ITCLogin" sender:self];
        }
        [self updateViewState];
    }
}

#pragma mark → IPA File Controlles Actions
//IPA File Path Handler
- (IBAction)ipaFilePathHandle:(NSPathControl *)sender {
    if (![project.fullPath isEqual:sender.URL]){
        project.ipaFullPath = sender.URL.filePathURL;
        [self updateViewState];
    }
}

- (IBAction)buttonUniqueLinkTapped:(NSButton *)sender{
    
}

- (IBAction)buttonSameLinkHelpTapped:(NSButton *)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: abKeepSameLinkHelpTitle];
    [alert setInformativeText:abKeepSameLinkHelpMessage];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert addButtonWithTitle:@"Know More"];
    [alert addButtonWithTitle:@"Ok"];
    if ([alert runModal] == NSAlertFirstButtonReturn){
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:abKeepSameLinkReadMoreURL]];
        [Answers logCustomEventWithName:@"External Links" customAttributes:@{@"title":@"Keep Same Link"}];
    }
}


#pragma mark → Mail Controls Action
//Send mail option
- (IBAction)sendMailOptionValueChanged:(NSButton *)sender {
    [self enableMailField:(sender.state == NSOnState)];
}

//Shutdown mac option
- (IBAction)sendMailMacOptionValueChanged:(NSButton *)sender {
    //No action required
}

//email id text field
- (IBAction)textFieldMailValueChanged:(NSTextField *)sender {
    //removed spaces
    [sender setStringValue: [sender.stringValue stringByReplacingOccurrencesOfString:@" " withString:abEmptyString]];
    
    //check all mails vaild or not and setup mailed option based on this
    BOOL isAllMailVaild = sender.stringValue.length > 0 && [MailHandler isAllValidEmail:sender.stringValue];
    [buttonShutdownMac setEnabled:isAllMailVaild];
    if (isAllMailVaild){
        [project setEmails:sender.stringValue];
        
        //save user emails, if they doesn't have any
        if ([[UserData userEmail] isEqualToString:abEmptyString]){
            [UserData setUserEmail:sender.stringValue];
        }
    }else if (sender.stringValue.length > 0){
        [MailHandler showInvalidEmailAddressAlert];
    }
}

//developer message text field
- (IBAction)textFieldDevMessageValueChanged:(NSTextField *)sender {
    if (sender.stringValue.length > 0){
        if ([[UserData userMessage] isEqualToString:abEmptyString]) {
            [UserData setUserMessage:sender.stringValue];
        }
        [project setPersonalMessage:sender.stringValue];
    }
}

#pragma mark → Final Action Button (Build/IPA/CI)
//Build Button Action
- (IBAction)actionButtonTapped:(NSButton *)sender {
    if (buttonSendMail.state == NSOffState || (textFieldEmail.stringValue.length > 0 && [MailHandler isAllValidEmail:textFieldEmail.stringValue])){
        //set email
        [self enableMailField:buttonSendMail.state == NSOnState];
        
        //set processing flg
        [[AppDelegate appDelegate] setProcessing:true];
        [[textFieldEmail window] makeFirstResponder:self.view];
        
        if (project.fullPath && tabView.tabViewItems.firstObject.tabState == NSSelectedTab){
            [Answers logCustomEventWithName:@"Archive and Upload IPA" customAttributes:[self getBasicViewStateWithOthersSettings:@{@"Build Type" : comboBuildType.stringValue}]];
            [project setIsBuildOnly:NO];
            [self runBuildScript];
        }else if (project.ipaFullPath  && tabView.tabViewItems.lastObject.tabState == NSSelectedTab){
            [Answers logCustomEventWithName:@"Upload IPA" customAttributes:[self getBasicViewStateWithOthersSettings:nil]];
            [self getIPAInfoFromLocalURL:project.ipaFullPath];
        }
        [self viewStateForProgressFinish:NO];
    }else{
        [MailHandler showInvalidEmailAddressAlert];
    }
}

//Config CI
- (IBAction)buttonConfigCITapped:(NSButton *)sender {
    
}

#pragma mark - NSTask (Scheme, TeamId and Archive) -
#pragma mark → Task

- (void)runGetSchemeScript{
    [self showStatus:@"Getting project scheme..." andShowProgressBar:YES withProgress:-1];
    scriptType = ScriptTypeGetScheme;
    NSString *schemeScriptPath = [[NSBundle mainBundle] pathForResource:@"GetSchemeScript" ofType:@"sh"];
    [self runTaskWithLaunchPath:schemeScriptPath andArgument:@[project.rootDirectory]];
}

- (void)runTeamIDScript{
    [self showStatus:@"Getting project team id..." andShowProgressBar:YES withProgress:-1];
    scriptType = ScriptTypeTeamId;
    NSString *teamIdScriptPath = [[NSBundle mainBundle] pathForResource:@"TeamIDScript" ofType:@"sh"];
    [self runTaskWithLaunchPath:teamIdScriptPath andArgument:@[project.rootDirectory]];
}

- (void)runBuildScript{
    [self showStatus:@"Cleaning..." andShowProgressBar:YES withProgress:-1];
    scriptType = ScriptTypeBuild;
    
    //Create Export Option Plist
    if (![project createExportOptionPlist]){
        [Common showAlertWithTitle:@"Error" andMessage:@"Unable to create file in this directory."];
        return;
    }
    
    //Build Script
    NSString *buildScriptPath = [[NSBundle mainBundle] pathForResource:@"ProjectBuildScript" ofType:@"sh"];
    NSMutableArray *buildArgument = [[NSMutableArray alloc] init];
    
    //${1} Project Location
    [buildArgument addObject:project.rootDirectory];
    
    //${2} Project type workspace/scheme
    [buildArgument addObject:pathProject.URL.lastPathComponent];
    
    //${3} Build Scheme
    [buildArgument addObject:comboBuildScheme.stringValue];
    
    //${4} Archive Location
    [buildArgument addObject:[project.buildArchivePath.resourceSpecifier stringByRemovingPercentEncoding]];
    
    //${5} ipa Location
    [buildArgument addObject:[project.buildUUIDDirectory.resourceSpecifier stringByRemovingPercentEncoding]];
    
    //${6} export options plist Location
    [buildArgument addObject:[project.exportOptionsPlistPath.resourceSpecifier stringByRemovingPercentEncoding]];
    
    //Run Task
    [self runTaskWithLaunchPath:buildScriptPath andArgument:buildArgument];
}

- (void)runXcodePathScript{
    scriptType = ScriptTypeXcodePath;
    NSString *xcodePathSriptPath = [[NSBundle mainBundle] pathForResource:@"XCodePath" ofType:@"sh"];
    [self runTaskWithLaunchPath:xcodePathSriptPath andArgument:nil];
}

- (void)runALAppStoreScriptForValidation:(BOOL)isValidation{
    scriptType = isValidation ? ScriptTypeAppStoreValidation : ScriptTypeAppStoreUpload;
    [self showStatus:isValidation ? @"Validating IPA with AppStore..." : @"Uploading IPA on AppStore..." andShowProgressBar:YES withProgress:-1];
    NSString *alSriptPath = [[NSBundle mainBundle] pathForResource: @"ALAppStore" ofType:@"sh"];
    NSMutableArray *buildArgument = [[NSMutableArray alloc] init];

    
    //${1} Purpose
    NSString *purpose = isValidation ? abALValidateApp : abALUploadApp;
    [buildArgument addObject:purpose];
    
    //${2} AL Path
    [buildArgument addObject:project.alPath];
    
    //${3} Project Location
    [buildArgument addObject: [project.ipaFullPath.resourceSpecifier stringByRemovingPercentEncoding]];
    
    //${4} Project type workspace/scheme
    [buildArgument addObject:project.itcUserName];
    
    //${5} Build Scheme
    [buildArgument addObject:project.itcPasswod];
    
    [self runTaskWithLaunchPath:alSriptPath andArgument:buildArgument];
}


#pragma mark → Run and Capture task data

- (void)runTaskWithLaunchPath:(NSString *)launchPath andArgument:(NSArray *)arguments{
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = launchPath;
    task.arguments = arguments;
    [self captureStandardOutputWithTask:task];
    [task launch];
    if (scriptType == ScriptTypeTeamId){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [task terminate];
            [[AppDelegate appDelegate] addSessionLog:@"terminating task!!"];
        });
    }
}

- (void)captureStandardOutputWithTask:(NSTask *)task{
    NSPipe *outputPipe = [[NSPipe alloc] init];
    [task setStandardOutput:outputPipe];
    [task setStandardError:outputPipe];
    [outputPipe.fileHandleForReading waitForDataInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification object:outputPipe.fileHandleForReading queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        NSData *outputData =  outputPipe.fileHandleForReading.availableData;
        NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
        [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Task Output - %@\n",outputString]];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //Handle Project Scheme Response
            if (scriptType == ScriptTypeGetScheme){
                NSError *error;
                NSDictionary *buildList = [NSJSONSerialization JSONObjectWithData:outputData options:NSJSONReadingAllowFragments error:&error];
                if (buildList != nil){
                    [project setBuildListInfo:buildList];
                    [comboBuildScheme removeAllItems];
                    [comboBuildScheme addItemsWithObjectValues:project.schemes];
                    if (comboBuildScheme.numberOfItems > 0){
                        [comboBuildScheme selectItemAtIndex:0];
                        if (repoProject == nil) {
                            [self comboBuildSchemeValueChanged:comboBuildScheme];
                            
                            //Run Team Id Script
                            [self runTeamIDScript];
                        } else {
                            [RepoBuilder setProjectSettingFromProject:repoProject toProject:project];
                            [comboTeamId removeAllItems];
                            [comboTeamId addItemWithObjectValue:project.teamId];
                            [comboTeamId selectItemWithObjectValue:project.teamId];
                            [comboBuildType selectItemWithObjectValue:project.buildType];
                            [textFieldEmail setStringValue:project.emails];
                            [textFieldMessage setStringValue:project.personalMessage];
                            if (project.emails.length > 0){
                                [buttonSendMail setState:NSOnState];
                            }
                            [self actionButtonTapped:buttonAction];
                        }
                    }
                }else{
                    [self showStatus:@"Failed to load scheme information." andShowProgressBar:NO withProgress:-1];
                }
            }
            
            //Handle Team Id Response
            else if (scriptType == ScriptTypeTeamId){
                if ([outputString.lowercaseString containsString:@"development_team"]){
                    NSArray *outputComponent = [outputString componentsSeparatedByString:@"\n"];
                    NSString *devTeam = [[outputComponent filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF CONTAINS 'DEVELOPMENT_TEAM'"]] firstObject];
                    if (devTeam != nil) {
                        project.teamId = [[devTeam componentsSeparatedByString:@" = "] lastObject];
                        if (project.teamId != nil){
                            NSDictionary *team = [[allTeamIds filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.teamId LIKE %@",project.teamId]] firstObject];
                            if (team != nil){
                                [comboTeamId selectItemAtIndex:[allTeamIds indexOfObject:team]];
                            }else{
                                [comboTeamId addItemWithObjectValue:project.teamId];
                                [comboTeamId selectItemWithObjectValue:project.teamId];
                            }
                            [self updateViewState];
                            [self showStatus:@"Now please select ipa type (save for). You can view log from File -> View Log." andShowProgressBar:NO withProgress:-1];
                        }
                    }
                } else if ([outputString.lowercaseString containsString:@"endofteamidscript"] || outputString.lowercaseString.length == 0) {
                    [self showStatus:@"Can't able to find Team ID! Please select/enter manually!" andShowProgressBar:NO withProgress:-1];
                } else {
                    [outputPipe.fileHandleForReading waitForDataInBackgroundAndNotify];
                }
            }
            
            //Handle Build Response
            else if (scriptType == ScriptTypeBuild){
                if ([outputString.lowercaseString containsString:@"archive succeeded"]){
                    [self showStatus:@"Creating IPA..." andShowProgressBar:YES withProgress:-1];
                    [outputPipe.fileHandleForReading waitForDataInBackgroundAndNotify];
                } else if ([outputString.lowercaseString containsString:@"clean succeeded"]){
                    [self showStatus:@"Archiving..." andShowProgressBar:YES withProgress:-1];
                    [outputPipe.fileHandleForReading waitForDataInBackgroundAndNotify];
                } else if ([outputString.lowercaseString containsString:@"export succeeded"]){
                    //Check and Upload IPA File
                    if (project.isBuildOnly){
                        [self showStatus:[NSString stringWithFormat:@"Export Succeeded - %@",project.buildUUIDDirectory] andShowProgressBar:NO withProgress:-1];
                    }else{
                        [self showStatus:@"Export Succeeded" andShowProgressBar:YES withProgress:-1];
                        [self checkIPACreated];
                    }
                    
                } else if ([outputString.lowercaseString containsString:@"export failed"]){
                    [self showStatus:@"Export Failed" andShowProgressBar:NO withProgress:-1];
                    [Common showAlertWithTitle:@"Export Failed" andMessage:outputString];
                    [self viewStateForProgressFinish:YES];
                } else if ([outputString.lowercaseString containsString:@"archive failed"]){
                    [self showStatus:@"Archive Failed" andShowProgressBar:NO withProgress:-1];
                    if ([AppDelegate appDelegate].isInternetConnected){
                        [Common showAlertWithTitle:@"Archive Failed" andMessage:outputString];
                        [self viewStateForProgressFinish:YES];
                    }else{
                        lastfailedOperation = [NSBlockOperation blockOperationWithBlock:^{
                            [self runBuildScript];
                        }];
                    }
                } else {
                    [outputPipe.fileHandleForReading waitForDataInBackgroundAndNotify];
                }
            }
            
            //Handle Xcode Path Response
            else if (scriptType == ScriptTypeXcodePath){
                
            }
            
            //Handle AppStore Validation and Upload Response
            else if (scriptType == ScriptTypeAppStoreValidation || scriptType == ScriptTypeAppStoreUpload){
                [self appStoreScriptOutputHandlerWithOutput:outputString];
            }
        });
    }];
}

-(void)appStoreScriptOutputHandlerWithOutput:(NSString *)output{
    //parse application loader response
    ALOutput *alOutput = [ALOutputParser messageFromXMLString:output];
    [alOutput.messages enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self showStatus:obj andShowProgressBar:NO withProgress:-1];
    }];
    
    //check if response is valid or error
    if (alOutput.isValid){
        if (scriptType == ScriptTypeAppStoreValidation){
            //run appstore upload script
            [self runALAppStoreScriptForValidation:NO];
        }else if (scriptType == ScriptTypeAppStoreUpload){
            //show upload succeess message
            [self showStatus:@"App uploaded to AppStore." andShowProgressBar:NO withProgress:-1];
            [Common showAlertWithTitle:@"App uploaded to AppStore." andMessage:nil];
            [self viewStateForProgressFinish:YES];
            [Answers logCustomEventWithName:@"IPA Uploaded Success" customAttributes:[self getBasicViewStateWithOthersSettings:@{@"Uploaded to":@"AppStore"}]];
        }
    }else{
        //if internet is connected, show direct error
        if ([AppDelegate appDelegate].isInternetConnected){
            [Common showAlertWithTitle:@"Error" andMessage:[alOutput.messages componentsJoinedByString:@"\n\n"]];
            [self viewStateForProgressFinish:YES];
        }else{
            
            //if internet connection is lost, show watting message and start process again when connected
            [self showStatus:abNotConnectedToInternet andShowProgressBar:YES withProgress:-1];
            lastfailedOperation = [NSBlockOperation blockOperationWithBlock:^{
                if (scriptType == ScriptTypeAppStoreValidation){
                    [self runALAppStoreScriptForValidation:YES];
                }else if (scriptType == ScriptTypeAppStoreUpload){
                    [self runALAppStoreScriptForValidation:NO];
                }
            }];
        }
    }
}

#pragma mark - Get IPA Info and Upload -

-(void)checkIPACreated{
    NSString *ipaPath = [project.ipaFullPath.resourceSpecifier stringByRemovingPercentEncoding];
    if ([[NSFileManager defaultManager] fileExistsAtPath:ipaPath]){
        if ([comboBuildType.stringValue isEqualToString: BuildTypeAppStore]){
            //get required info and upload to appstore
            [self runALAppStoreScriptForValidation:YES];
        }else{
            //get ipa details and upload to dropbox
            [self getIPAInfoFromLocalURL:project.ipaFullPath];
        }
    }else{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self checkIPACreated];
        });
    }
}

- (void)getIPAInfoFromLocalURL:(NSURL *)ipaFileURL{
    NSString *ipaPath = [ipaFileURL.resourceSpecifier stringByRemovingPercentEncoding];
    if ([[NSFileManager defaultManager] fileExistsAtPath:ipaPath]) {
        [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"\n\n======\nUploading IPA - %@\n======\n\n",ipaPath]];
        //Unzip ipa
        __block NSString *payloadEntry;
        __block NSString *infoPlistPath;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [SSZipArchive unzipFileAtPath:ipaPath toDestination:NSTemporaryDirectory() overwrite:YES password:nil progressHandler:^(NSString * _Nonnull entry, unz_file_info zipInfo, long entryNumber, long total) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showStatus:@"Extracting files..." andShowProgressBar:YES withProgress:-1];
                    
                    //Get payload entry
                    if ((entry.lastPathComponent.length > 4) && [[entry.lastPathComponent substringFromIndex:(entry.lastPathComponent.length-4)].lowercaseString isEqualToString: @".app"]) {
                        [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Found payload at path = %@",entry]];
                        payloadEntry = entry;
                    }
                    
                    //Get Info.plist entry
                    NSString *mainInfoPlistPath = [NSString stringWithFormat:@"%@Info.plist",payloadEntry].lowercaseString;
                    if ([entry.lowercaseString isEqualToString:mainInfoPlistPath]) {
                        [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Found Info.plist at path = %@",mainInfoPlistPath]];
                        infoPlistPath = entry;
                    }
                    
                    //Get embedded mobile provision
                    if (project.buildType == nil){
                        NSString *mobileProvisionPath = [NSString stringWithFormat:@"%@embedded.mobileprovision",payloadEntry].lowercaseString;
                        if ([entry.lowercaseString isEqualToString:mobileProvisionPath]){
                            [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Found mobileprovision at path = %@",mobileProvisionPath]];
                            [project setBuildType:[MobileProvision buildTypeForProvisioning:[NSTemporaryDirectory() stringByAppendingPathComponent: mobileProvisionPath]]];
                        }
                    }
                    
                    //show status and log files entry
                    [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"%@-%@-%@",[NSNumber numberWithLong:entryNumber], [NSNumber numberWithLong:total], entry]];
                });
            } completionHandler:^(NSString * _Nonnull path, BOOL succeeded, NSError * _Nonnull error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        //show error and return
                        [Common showAlertWithTitle:@"AppBox - Error" andMessage:error.localizedDescription];
                        [self viewStateForProgressFinish:YES];
                        return;
                    }
                    
                    //get info.plist
                    [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Final Info.plist path = %@",infoPlistPath]];
                    [project setIpaInfoPlist: [NSDictionary dictionaryWithContentsOfFile:[NSTemporaryDirectory() stringByAppendingPathComponent:infoPlistPath]]];
                    
                    //show error if info.plist is nil or invalid
                    if (![project isValidProjectInfoPlist]) {
                        [Common showAlertWithTitle:@"AppBox - Error" andMessage:@"AppBox can't able to find Info.plist in you IPA."];
                        [self viewStateForProgressFinish:YES];
                        return;
                    }
                    
                    if ([AppDelegate appDelegate].isInternetConnected){
                        [self showStatus:@"Ready to upload..." andShowProgressBar:NO withProgress:-1];
                    }else{
                        [self showStatus:abNotConnectedToInternet andShowProgressBar:YES withProgress:-1];
                    }
                    
                    //prepare for upload and check ipa type
                    NSURL *ipaFileURL = ([project.ipaFullPath isFileURL]) ? project.ipaFullPath : [NSURL fileURLWithPath:ipaPath];
                    [project setIpaFullPath:ipaFileURL];
                    [self uploadIPAFileWithLocalURL:ipaFileURL];
                });
            }];
        });
    }else{
        [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"\n\n======\nFile Not Exist - %@\n======\n\n",ipaPath]];
        [Common showAlertWithTitle:@"IPA File Missing" andMessage:[NSString stringWithFormat:@"AppBox can't able to find ipa file at %@.",ipaFileURL.absoluteString]];
        [self viewStateForProgressFinish:YES];
    }
}

-(void)uploadIPAFileWithLocalURL:(NSURL *)ipaURL{
    if ([project.buildType isEqualToString: BuildTypeAppStore] && project.fullPath == nil){
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText: @"Please confirm"];
        [alert setInformativeText:@"AppBox found an AppStore provisioning profile in this IPA file. Do you want to upload this on AppStore?"];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert addButtonWithTitle:@"YES! Upload on AppStore."];
        [alert addButtonWithTitle:@"NO! Upload on Dropbox"];
        if ([alert runModal] == NSAlertFirstButtonReturn){
            [self performSegueWithIdentifier:@"ITCLogin" sender:self];
            return;
        }
    }

    [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"\n\n======\nIPA Info.plist\n======\n\n - %@",project.ipaInfoPlist]];
    
    //upload ipa
    fileType = FileTypeIPA;
    [self dbUploadFile:ipaURL.resourceSpecifier to:project.dbIPAFullPath.absoluteString mode:[[DBFILESWriteMode alloc] initWithOverwrite]];
    [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Temporaray folder %@",NSTemporaryDirectory()]];
}

#pragma mark - Dropbox Helper -
#pragma mark → Dropbox Notification Handler
- (void)handleLoggedInNotification:(NSNotification *)notification{
    [self updateMenuButtons];
    [self viewStateForProgressFinish:YES];
}

- (void)dropboxLogoutHandler:(id)sender{
    //handle dropbox logout for authorized users
    if ([DBClientsManager authorizedClient]){
        [DBClientsManager unlinkAndResetClients];
        [self viewStateForProgressFinish:YES];
        [self performSegueWithIdentifier:@"DropBoxLogin" sender:self];
    }
}

#pragma mark → Dropbox Upload Files
-(void)dbUploadFile:(NSString *)file to:(NSString *)path mode:(DBFILESWriteMode *)mode{
    //uploadUrl:path inputUrl:file
    [[[[DBClientsManager authorizedClient].filesRoutes uploadUrl:path mode:mode autorename:@NO clientModified:nil mute:@NO inputUrl:file]
      //Track response with result and error
      setResponseBlock:^(DBFILESFileMetadata * _Nullable response, DBFILESUploadError * _Nullable routeError, DBRequestError * _Nullable error) {
          if (response) {
              [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Uploaded file metadata = %@", response]];
              
              //AppInfo.json file uploaded and creating shared url
              if(fileType == FileTypeJson){
                  project.uniqueLinkJsonMetaData = response;
                  if(project.appShortShareableURL){
                      [self logAppUploadEventAndShareURLOnSlackChannel];
                      return;
                  }else{
                      //create shared url for appinfo.json
                      [self dbCreateSharedURLForFile:response.pathDisplay];
                  }
              }
              //IPA file uploaded and creating shared url
              else if (fileType == FileTypeIPA){
                  [Common showLocalNotificationWithTitle:@"AppBox" andMessage:@"IPA file uploaded."];
                  NSString *status = [NSString stringWithFormat:@"Creating Sharable Link for IPA"];
                  [self showStatus:status andShowProgressBar:YES withProgress:-1];
                  
                  //create shared url for ipa
                  [self dbCreateSharedURLForFile:response.pathDisplay];
              }
              //Manifest file uploaded and creating shared url
              else if (fileType == FileTypeManifest){
                  [Common showLocalNotificationWithTitle:@"AppBox" andMessage:@"Manifest file uploaded."];
                  NSString *status = [NSString stringWithFormat:@"Creating Sharable Link for Manifest"];
                  [self showStatus:status andShowProgressBar:YES withProgress:-1];
                  
                  //create shared url for manifest
                  [self dbCreateSharedURLForFile:response.pathDisplay];
              }
          }
          //unable to upload file, show error
          else {
              [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Upload DB Error - %@ \n Route Error - %@",error, routeError]];
              [Common showAlertWithTitle:@"Error" andMessage:error.nsError.localizedDescription];
              [self viewStateForProgressFinish:YES];
          }
      }]
     
     //Track and show upload progress
     setProgressBlock:^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
         //Calculate and show progress based on file type
         CGFloat progress = ((totalBytesWritten * 100) / totalBytesExpectedToWrite) ;
         if (fileType == FileTypeIPA) {
             NSString *status = [NSString stringWithFormat:@"Uploading IPA (%@%%)",[NSNumber numberWithInt:progress]];
             [self showStatus:status andShowProgressBar:YES withProgress:progress/100];
         }else if (fileType == FileTypeManifest){
             NSString *status = [NSString stringWithFormat:@"Uploading Manifest (%@%%)",[NSNumber numberWithInt:progress]];
             [self showStatus:status andShowProgressBar:YES withProgress:progress/100];
         }else if (fileType == FileTypeJson){
             NSString *status = [NSString stringWithFormat:@"Uploading AppInfo (%@%%)",[NSNumber numberWithInt:progress]];
             [self showStatus:status andShowProgressBar:YES withProgress:progress/100];
         }
     }];
}


#pragma mark → Dropbox Create/Get Shared Link
-(void)dbCreateSharedURLForFile:(NSString *)file{
    [[[DBClientsManager authorizedClient].sharingRoutes createSharedLinkWithSettings:file]
     //Track response with result and error
     setResponseBlock:^(DBSHARINGSharedLinkMetadata * _Nullable response, DBSHARINGCreateSharedLinkWithSettingsError * _Nullable routeError, DBRequestError * _Nullable error) {
         if (response){
             [self handleSharedURLResult:response.url];
         }else{
             [self handleSharedURLError:error forFile:file];
         }
     }];
}

-(void)dbGetSharedURLForFile:(NSString *)file{
    [[[DBClientsManager authorizedClient].sharingRoutes listSharedLinks:file cursor:nil directOnly:nil] setResponseBlock:^(DBSHARINGListSharedLinksResult * _Nullable response, DBSHARINGListSharedLinksError * _Nullable routeError, DBRequestError * _Nullable error) {
        if (response && response.links && response.links.count > 0){
            [self handleSharedURLResult:[[response.links firstObject] url]];
        }else{
            [self handleSharedURLError:error forFile:file];
        }
    }];
}

-(void)handleSharedURLError:(DBRequestError *)error forFile:(NSString *)file{
    [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Create Share Link Error - %@",error]];
    if ([error isClientError]){
        if ([[AppDelegate appDelegate] isInternetConnected]){
            [self dbCreateSharedURLForFile:file];
        }else{
            lastfailedOperation = [NSBlockOperation blockOperationWithBlock:^{
                [self dbCreateSharedURLForFile:file];
            }];
        }
    }else if([error isHttpError] && error.statusCode.integerValue == 409){
        [self dbGetSharedURLForFile:file];
    }else{
        [Common showAlertWithTitle:@"Error" andMessage:error.nsError.localizedDescription];
        [self viewStateForProgressFinish:YES];
    }
}

-(void)handleSharedURLResult:(NSString *)url{
    //Create manifest file with share IPA url and upload manifest file
    if (fileType == FileTypeIPA) {
        NSString *shareableLink = [url stringByReplacingCharactersInRange:NSMakeRange(url.length-1, 1) withString:@"1"];
        project.ipaFileDBShareableURL = [NSURL URLWithString:shareableLink];
        [project createManifestWithIPAURL:project.ipaFileDBShareableURL completion:^(NSURL *manifestURL) {
            if (manifestURL == nil){
                //show error if manifest file url is nil
                [Common showAlertWithTitle:@"Error" andMessage:@"Unable to create manifest file!!"];
                [self viewStateForProgressFinish:YES];
            }else{
                //change file type and upload manifest
                fileType = FileTypeManifest;
                [self dbUploadFile:manifestURL.resourceSpecifier to:project.dbManifestFullPath.absoluteString mode:[[DBFILESWriteMode alloc] initWithOverwrite]];
            }
        }];
        
    }
    //if same link enable load appinfo.json otherwise Create short shareable url of manifest
    else if (fileType == FileTypeManifest){
        NSString *shareableLink = [url substringToIndex:url.length-5];
        [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Manifest Sharable link - %@",shareableLink]];
        project.manifestFileSharableURL = [NSURL URLWithString:shareableLink];
        if(buttonUniqueLink.state){
            //Download previously uploaded appinfo
            [[[DBClientsManager authorizedClient].filesRoutes listRevisions:project.dbAppInfoJSONFullPath.absoluteString limit:@1]
             setResponseBlock:^(DBFILESListRevisionsResult * _Nullable response, DBFILESListRevisionsError * _Nullable routeError, DBRequestError * _Nullable error) {
                 //check there is any rev available
                 if (response && response.isDeleted.boolValue == NO && response.entries.count > 0){
                     [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Loaded Meta Data %@",response]];
                     project.uniqueLinkJsonMetaData = [response.entries firstObject];
                 }
                 
                 //handle meta data
                 [self handleAfterUniqueJsonMetaDataLoaded];
             }];
        }else{
            [self createManifestShortSharableUrl];
        }
    }
    
    //create app info file short sharable url
    else if (fileType == FileTypeJson){
        NSString *shareableLink = [url substringToIndex:url.length-5];
        [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"APPInfo Sharable link - %@",shareableLink]];
        project.uniquelinkShareableURL = [NSURL URLWithString:shareableLink];
        NSMutableDictionary *dictUniqueFile = [[self getUniqueJsonDict] mutableCopy];
        [dictUniqueFile setObject:shareableLink forKey:UNIQUE_LINK_SHARED];
        [self writeUniqueJsonWithDict:dictUniqueFile];
        if(project.appShortShareableURL){
            [self logAppUploadEventAndShareURLOnSlackChannel];
        }else{
            [self createUniqueShortSharableUrl];
        }
    }
}

#pragma mark - Updating Unique Link -
-(void)updateUniquLinkDictinory:(NSMutableDictionary *)dictUniqueLink{
    if(![dictUniqueLink isKindOfClass:[NSDictionary class]])
    dictUniqueLink = [NSMutableDictionary new];
    NSDictionary *latestVersion = @{
                                    @"name" : project.name,
                                    @"version" : project.version,
                                    @"build" : project.build,
                                    @"identifier" : project.identifer,
                                    @"manifestLink" : project.manifestFileSharableURL.absoluteString,
                                    @"timestamp" : [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]]
                                    };
    NSMutableArray *versionHistory = [[dictUniqueLink objectForKey:@"versions"] mutableCopy];
    if(!versionHistory){
        versionHistory = [NSMutableArray new];
    }
    [versionHistory addObject:latestVersion];
    [dictUniqueLink setObject:versionHistory forKey:@"versions"];
    [dictUniqueLink setObject:latestVersion forKey:@"latestVersion"];
    [self writeUniqueJsonWithDict:dictUniqueLink];
    project.uniquelinkShareableURL = [NSURL URLWithString:[dictUniqueLink objectForKey:UNIQUE_LINK_SHARED]];
    project.appShortShareableURL = [NSURL URLWithString:[dictUniqueLink objectForKey:UNIQUE_LINK_SHORT]];
    [self uploadUniqueLinkJsonFile];
}

- (NSDictionary *)getUniqueJsonDict{
    NSError *error;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[NSTemporaryDirectory() stringByAppendingPathComponent:FILE_NAME_UNIQUE_JSON]] options:kNilOptions error:&error];
    [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"%@ : %@",FILE_NAME_UNIQUE_JSON,dictionary]];
    return dictionary;
}

-(void)writeUniqueJsonWithDict:(NSDictionary *)jsonDict{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:FILE_NAME_UNIQUE_JSON];
    if([[NSFileManager defaultManager] fileExistsAtPath:path]){
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingPrettyPrinted error:nil];
    [jsonData writeToFile:path atomically:YES];
}

-(void)uploadUniqueLinkJsonFile{
    fileType = FileTypeJson;
    NSURL *path = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:FILE_NAME_UNIQUE_JSON]];
    
    //set mode for appinfo.json file to upload/update
    DBFILESWriteMode *mode = (project.uniqueLinkJsonMetaData) ? [[DBFILESWriteMode alloc] initWithUpdate:project.uniqueLinkJsonMetaData.rev] : [[DBFILESWriteMode alloc] initWithOverwrite];
    [self dbUploadFile:path.resourceSpecifier to:project.dbAppInfoJSONFullPath.absoluteString mode:mode];
}

-(void)handleAfterUniqueJsonMetaDataLoaded{
    if(project.uniqueLinkJsonMetaData){
        NSURL *path = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:FILE_NAME_UNIQUE_JSON]];
        
        //download appinfo.json file
        [[[DBClientsManager authorizedClient].filesRoutes downloadUrl:project.uniqueLinkJsonMetaData.pathDisplay overwrite:YES destination:path]
         setResponseBlock:^(DBFILESFileMetadata * _Nullable response, DBFILESDownloadError * _Nullable routeError, DBRequestError * _Nullable error, NSURL * _Nonnull destination) {
             if (response){
                 if([response.name hasSuffix:FILE_NAME_UNIQUE_JSON]){
                     //append new version
                     [self updateUniquLinkDictinory:[[self getUniqueJsonDict] mutableCopy]];
                 }
             }
             else if (routeError || error){
                 [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Error while loading metadata %@",error.nsError.localizedDescription]];
                 //create new appinfo.json
                 [self handleAfterUniqueJsonMetaDataLoaded];
             }
         }];
    }else{
        [self updateUniquLinkDictinory:[NSMutableDictionary new]];
    }
}

#pragma mark - Create ShortSharable URL -
-(void)createUniqueShortSharableUrl{
    NSString *originalURL = [project.uniquelinkShareableURL.absoluteString componentsSeparatedByString:@"dropbox.com"][1];
    //create short url
    project.appLongShareableURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?url=%@", abInstallWebAppBaseURL, originalURL]];
    GooglURLShortenerService *service = [GooglURLShortenerService serviceWithAPIKey: abGoogleTiny];
    [Tiny shortenURL:project.appLongShareableURL withService:service completion:^(NSURL *shortURL, NSError *error) {
        project.appShortShareableURL = shortURL;
        NSMutableDictionary *dictUniqueFile = [[self getUniqueJsonDict] mutableCopy];
        [dictUniqueFile setObject:shortURL.absoluteString forKey:UNIQUE_LINK_SHORT];
        [self writeUniqueJsonWithDict:dictUniqueFile];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            //upload file unique short url
            [self uploadUniqueLinkJsonFile];
        });
    }];
}

-(void)createManifestShortSharableUrl{
    NSString *originalURL = [project.manifestFileSharableURL.absoluteString componentsSeparatedByString:@"dropbox.com"][1];
    //create short url
    project.appLongShareableURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?url=%@", abInstallWebAppBaseURL,originalURL]];
    GooglURLShortenerService *service = [GooglURLShortenerService serviceWithAPIKey: abGoogleTiny];
    [Tiny shortenURL:project.appLongShareableURL withService:service completion:^(NSURL *shortURL, NSError *error) {
        project.appShortShareableURL = shortURL;
        dispatch_async(dispatch_get_main_queue(), ^{
            //show url
            [self logAppUploadEventAndShareURLOnSlackChannel];
        });
    }];
}


#pragma mark - Controller Helpers -

-(void)viewStateForProgressFinish:(BOOL)finish{
    [[AppDelegate appDelegate] addSessionLog:[NSString stringWithFormat:@"Updating view setting for finish - %@", [NSNumber numberWithBool:finish]]];
    [[AppDelegate appDelegate] setProcessing:!finish];
    [[AppDelegate appDelegate] setIsReadyToBuild:!finish];
    
    //reset project
    if (finish){
        project = [[XCProject alloc] init];
        [project setBuildDirectory:[UserData buildLocation]];
        [MBProgressHUD hideAllHUDsForView:self.view animated:true];
    }
    
    //unique link
    [buttonUniqueLink setEnabled:finish];
    [buttonUniqueLink setState: finish ? NSOffState : buttonUniqueLink.state];
    
    //ipa path
    [pathIPAFile setEnabled:finish];
    [pathIPAFile setURL: finish ? nil : pathIPAFile.URL.filePathURL];
    
    //project path
    [pathProject setEnabled:finish];
    [pathProject setURL: finish ? nil : pathProject.URL.filePathURL];
    
    //team id combo
    [comboTeamId setEnabled:finish];
    if (finish){
        //setup team id
        [comboTeamId removeAllItems];
        [comboTeamId setStringValue:abEmptyString];
        [allTeamIds enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [comboTeamId addItemWithObjectValue:[obj valueForKey:abFullName]];
        }];
    }
    
    //build type combo
    [comboBuildType setEnabled:finish];
    if (finish && comboBuildType.indexOfSelectedItem >= 0) [comboBuildType deselectItemAtIndex:comboBuildType.indexOfSelectedItem];
    
    //build scheme
    [comboBuildScheme setEnabled:finish];
    if (finish){
        if (comboBuildScheme.indexOfSelectedItem >= 0){
            [comboBuildScheme setStringValue:abEmptyString];
            [comboBuildScheme deselectItemAtIndex:comboBuildType.indexOfSelectedItem];
        }
        [comboBuildScheme removeAllItems];
    }
    
    
    //send mail
    [buttonSendMail setEnabled:finish];
    [buttonShutdownMac setEnabled:(finish && buttonSendMail.state == NSOnState)];
    [textFieldEmail setEnabled:(finish && buttonSendMail.state == NSOnState)];
    [textFieldMessage setEnabled:(finish && buttonSendMail.state == NSOnState)];
    
    //action button
    [self updateViewState];
    
    //logout buttons
    [self updateMenuButtons];
}

-(void)resetBuildOptions{
    [comboTeamId removeAllItems];
    [comboBuildScheme removeAllItems];
}

-(void)showStatus:(NSString *)status andShowProgressBar:(BOOL)showProgressBar withProgress:(double)progress{
    //log status in session log
    [[AppDelegate appDelegate]addSessionLog:[NSString stringWithFormat:@"%@",status]];
    
    //start/stop/progress based on showProgressBar and progress
    if (progress == -1){
        if (showProgressBar){
            [MBProgressHUD showStatus:status onView:self.view];
        }else{
            [MBProgressHUD showOnlyStatus:status onView:self.view];
        }
    }else{
        if (showProgressBar){
            [MBProgressHUD showStatus:status witProgress:progress onView:self.view];
        }else{
            [MBProgressHUD showOnlyStatus:status onView:self.view];
        }
    }
}

-(void)updateViewState{
    //update action button
    BOOL enable = ((comboBuildScheme.stringValue != nil && comboBuildType.stringValue.length > 0 && //build scheme
                    comboBuildType.stringValue != nil && comboBuildType.stringValue.length > 0 && //build type
                    comboTeamId.stringValue != nil && comboTeamId.stringValue.length > 0 && //team id
                    tabView.tabViewItems.firstObject.tabState == NSSelectedTab &&
                    (![comboBuildType.stringValue isEqualToString: BuildTypeAppStore] || project.itcPasswod.length > 0)) ||
                   
                   //if ipa selected
                   (project.ipaFullPath != nil && tabView.tabViewItems.lastObject.tabState == NSSelectedTab));
    [buttonAction setEnabled:(enable && (pathProject.enabled || pathIPAFile.enabled))];
    [buttonAction setTitle:(tabView.selectedTabViewItem.label)];
    
    //update CI button
    [buttonConfigCI setHidden:(tabView.tabViewItems.lastObject.tabState == NSSelectedTab)];
    [buttonConfigCI setEnabled:(buttonAction.enabled && !buttonConfigCI.hidden)];
    
    //update keepsame link
    [buttonUniqueLink setEnabled:((project.buildType == nil || ![project.buildType isEqualToString:BuildTypeAppStore] ||
                                  tabView.tabViewItems.lastObject.tabState == NSSelectedTab) && ![[AppDelegate appDelegate] processing])];
    
    //update advanced button
    [buttonAdcanced setEnabled:buttonAction.enabled];
    
}

-(void)updateMenuButtons{
    //Menu Buttons
    BOOL enable = ([DBClientsManager authorizedClient] && pathProject.enabled && pathIPAFile.enabled);
    [[[AppDelegate appDelegate] dropboxLogoutButton] setEnabled:enable];
}

//get optional feature enable/disable dictionary
-(NSDictionary *)getBasicViewStateWithOthersSettings:(NSDictionary *)otherSettings{
    if (otherSettings == nil){
        otherSettings = @{};
    }
    NSMutableDictionary *viewState = [[NSMutableDictionary alloc] initWithDictionary:otherSettings];
    [viewState setValue:[NSNumber numberWithInteger: buttonUniqueLink.state] forKey:@"Same Link"];
    [viewState setValue:[NSNumber numberWithInteger: buttonSendMail.state] forKey:@"Sent Mail"];
    [viewState setValue:[NSNumber numberWithInteger: buttonShutdownMac.state] forKey:@"Shudown Mac"];
    return viewState;
}

#pragma mark - E-Mail -
-(void)enableMailField:(BOOL)enable{
    //Gmail Logout Button
    [self updateMenuButtons];
    
    //Enable text fields
    [textFieldEmail setEnabled:enable];
    [textFieldMessage setEnabled:enable];
    
    //Get last time valid data
    [textFieldEmail setStringValue: enable ? [UserData userEmail] : abEmptyString];
    [textFieldMessage setStringValue: enable ? [UserData userMessage] : abEmptyString];
    
    //Just for confirm changes
    [self textFieldMailValueChanged:textFieldEmail];
    [self textFieldDevMessageValueChanged:textFieldMessage];
}

#pragma mark - TabView Delegate -
-(void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem{
    //update view state based on selected tap
    [self updateViewState];
}

#pragma mark - ProjectAdvancedViewDelegate - 
- (void)projectAdvancedSaveButtonTapped:(NSButton *)sender{

}

- (void)projectAdvancedCancelButtonTapped:(NSButton *)sender{
    
}

#pragma mark - AppleDeveloperLogin Delegate -
- (void)itcLoginResult:(BOOL)success{
    if (success) {
        //check xcode and application loader path
        [XCHandler getXCodePathWithCompletion:^(NSString *xcodePath, NSString *applicationLoaderPath) {
            if (xcodePath != nil){
                [project setXcodePath: xcodePath];
                if (applicationLoaderPath != nil){
                    [project setAlPath: applicationLoaderPath];
                    
                    //check for ipa, if ipa start upload
                    if (project.fullPath == nil && tabView.tabViewItems.lastObject.tabState == NSSelectedTab){
                        [self runALAppStoreScriptForValidation:YES];
                    }else{
                        [self updateViewState];
                    }
                }else{
                    [Common showAlertWithTitle:@"Error" andMessage:@"Can't able to find application loader in your machine."];
                }
            }else{
                [Common showAlertWithTitle:@"Error" andMessage:@"Can't able to find xcode in your machine."];
            }
        }];
    }
}

-(void)itcLoginCanceled{
    if (project.fullPath == nil && tabView.tabViewItems.lastObject.tabState == NSSelectedTab){
        [self uploadIPAFileWithLocalURL:project.ipaFullPath];
    } else {
        [project setBuildType:abEmptyString];
        [comboBuildType deselectItemAtIndex:comboBuildType.indexOfSelectedItem];
        [self updateViewState];
    }
}

#pragma mark - Navigation -
-(void)logAppUploadEventAndShareURLOnSlackChannel{
    //Log IPA Upload Success Rate with Other Options
    [Answers logCustomEventWithName:@"IPA Uploaded Success" customAttributes:[self getBasicViewStateWithOthersSettings:@{@"Uploaded to":@"Dropbox"}]];
    
    if ([UserData userSlackMessage].length > 0) {
        [self showStatus:@"Sending Message on Slack..." andShowProgressBar:YES withProgress:-1];
        [SlackClient sendMessageForProject:project completion:^(BOOL success) {
            [self handleAppURLAfterSlack];
        }];
    } else {
        [self handleAppURLAfterSlack];
    }
}


-(void) handleAppURLAfterSlack {
    //Send mail if valid email address othervise show link
    if (textFieldEmail.stringValue.length > 0 && [MailHandler isAllValidEmail:textFieldEmail.stringValue]) {
        [self showStatus:@"Sending Mail..." andShowProgressBar:YES withProgress:-1];
        [MailHandler sendMailForProject:project complition:^(BOOL success) {
            if (success) {
                [MBProgressHUD showStatus:@"Mail Sent" forSuccess:YES onView:self.view];
                if (buttonShutdownMac.state == NSOnState){
                    //if mac shutdown is checked then shutdown mac after 60 sec
                    [self viewStateForProgressFinish:YES];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [MacHandler shutdownSystem];
                    });
                }else if(![self.presentedViewControllers.lastObject isKindOfClass:[ShowLinkViewController class]]){
                    //if mac shutdown isn't checked then show link
                    if (repoProject == nil){
                        [self performSegueWithIdentifier:@"ShowLink" sender:self];
                    }else{
                        [self viewStateForProgressFinish:YES];
                        exit(0);
                    }
                }
            } else {
                [MBProgressHUD showStatus:@"Mail Failed" forSuccess:NO onView:self.view];
                [self performSegueWithIdentifier:@"ShowLink" sender:self];
            }
        }];
    }else{
        [self performSegueWithIdentifier:@"ShowLink" sender:self];
    }
}

-(void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender{
    
    //prepare to show link
    if ([segue.destinationController isKindOfClass:[ShowLinkViewController class]]) {
        //set project to destination
        [((ShowLinkViewController *)segue.destinationController) setProject:project];
        [self viewStateForProgressFinish:YES];
    }
    
    //prepare to show advanced project settings
    else if([segue.destinationController isKindOfClass:[ProjectAdvancedViewController class]]){
        ProjectAdvancedViewController *projectAdvancedViewController = ((ProjectAdvancedViewController *)segue.destinationController);
        [projectAdvancedViewController setProject:project];
        [projectAdvancedViewController setDelegate:self];
    }
    
    //prepare to show CI controller
    else if([segue.destinationController isKindOfClass:[CIViewController class]]){
        CIViewController *ciViewController = ((CIViewController *)segue.destinationController);
        [ciViewController setProject:project];
    }
    
    //prepare to show AppleDeveloperLogin
    else if ([segue.destinationController isKindOfClass:[ITCLoginViewController class]]){
        ITCLoginViewController *itcLoginViewController = ((ITCLoginViewController *)segue.destinationController);
        [itcLoginViewController setProject:project];
        [itcLoginViewController setDelegate:self];
    }
}

@end
