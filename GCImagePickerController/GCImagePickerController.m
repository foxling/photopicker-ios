//
//  GCImagePickerController.m
//
//  Copyright (c) 2011-2012 Caleb Davenport.
//

#ifndef __IPHONE_5_0
    #error This project uses features only available in iOS SDK 5.0 and later.
#endif
#if !__has_feature(objc_arc)
    #error This project requires ARC.
#endif

#import <MobileCoreServices/MobileCoreServices.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "GCImagePickerController.h"
#import "GCIPViewController_Pad.h"
#import "GCIPGroupPickerController.h"
#import "GCIPAssetPickerController.h"

@interface GCImagePickerController () <UINavigationControllerDelegate>

@end

@implementation GCImagePickerController

#pragma mark - class methods

+ (NSString *)localizedString:(NSString *)key {
    static NSURL *URL = nil;
    static NSBundle *bundle = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        URL = [[NSBundle mainBundle] URLForResource:NSStringFromClass(self) withExtension:@"bundle"];
        bundle = [NSBundle bundleWithURL:URL];
    });
    return [bundle localizedStringForKey:key value:nil table:nil];
}

+ (void)failedToLoadAssetsWithError:(NSError *)error {
    NSInteger code = [error code];
    UIAlertView *alert = nil;
    if (code == ALAssetsLibraryAccessUserDeniedError || code == ALAssetsLibraryAccessGloballyDeniedError) {
        NSString *message = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
        message = [NSString stringWithFormat:
                   [self localizedString:@"PHOTO_ROLL_ACCESS_ERROR"],
                   message];
        alert = [[UIAlertView alloc]
                 initWithTitle:[self localizedString:@"ERROR"]
                 message:message
                 delegate:nil
                 cancelButtonTitle:[self localizedString:@"OK"]
                 otherButtonTitles:nil];

    }
    else {
        alert = [[UIAlertView alloc]
                 initWithTitle:[self localizedString:@"ERROR"]
                 message:[self localizedString:@"UNKNOWN_LIBRARY_ERROR"]
                 delegate:nil
                 cancelButtonTitle:[self localizedString:@"OK"]
                 otherButtonTitles:nil];
    }
    [alert show];
}

+ (GCImagePickerController *)picker {
    return [self pickerForGroupWithURL:nil];
}

+ (GCImagePickerController *)pickerForGroupWithURL:(NSURL *)groupURL {
    
    // create root controller
    UIViewController *controller = nil;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        controller = [[GCIPViewController_Pad alloc] init];
    }
    else { controller = [[GCIPGroupPickerController alloc] init]; }
    
    // create picker
    GCImagePickerController *picker = [[GCImagePickerController alloc] initWithRootViewController:controller];
    picker.modalPresentationStyle = UIModalPresentationPageSheet;
    picker.assetsFilter = [ALAssetsFilter allAssets];
    picker.allowsMultipleSelection = YES;
    picker.delegate = picker;
    
    // push a group on if we have one
    if (groupURL && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        GCIPAssetPickerController *assetPicker = [[GCIPAssetPickerController alloc] init];
        assetPicker.groupURL = groupURL;
        [picker pushViewController:assetPicker animated:NO];
    }
    
    // assets library
    picker->_assetsLibrary = [[ALAssetsLibrary alloc] init];
    [picker->_assetsLibrary writeImageToSavedPhotosAlbum:nil metadata:nil completionBlock:nil];
    [[NSNotificationCenter defaultCenter]
     addObserver:picker
     selector:@selector(assetsLibraryDidChange:)
     name:ALAssetsLibraryChangedNotification
     object:picker->_assetsLibrary];
    
    // return
    return picker;
    
}

#pragma mark - object methods

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:ALAssetsLibraryChangedNotification
     object:self.assetsLibrary];
}

- (void)assetsLibraryDidChange:(NSNotification *)notif {
    [self.viewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[GCIPViewController class]]) {
            [(GCIPViewController *)obj reloadAssets];
        }
    }];
}

- (void)setAllowsMultipleSelection:(BOOL)allow {
    _allowsMultipleSelection = allow;
    if (!_allowsMultipleSelection && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.viewControllers enumerateObjectsUsingBlock:^(UIViewController *controller, NSUInteger idx, BOOL *stop) {
            controller.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                            initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                            target:self
                                                            action:@selector(cancelForSingleSelection)];
        }];
    }
}

- (void)cancelForSingleSelection {
    if (self.finishBlock) {
        self.finishBlock();
        return;
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UINavivationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (!self.allowsMultipleSelection && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        viewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                            initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                            target:self
                                                            action:@selector(cancelForSingleSelection)];
    }
}

@end
