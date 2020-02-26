#import "CTCrop.h"

#define CDV_PHOTO_PREFIX @"cdv_photo_"

@interface CTCrop ()
@property (copy) NSString* callbackId;
@property (assign) NSUInteger quality;
@end

@implementation CTCrop

- (void) cropImage: (CDVInvokedUrlCommand *) command {
    UIImage *image;
    NSString *imagePath = [command.arguments objectAtIndex:0];
    
    self.quality = 50;
    
    NSString *filePrefix = @"file://";
    
    if ([imagePath hasPrefix:filePrefix]) {
        imagePath = [imagePath substringFromIndex:[filePrefix length]];
    }
    
    if (!(image = [UIImage imageWithContentsOfFile:imagePath])) {
        NSDictionary *err = @{
                              @"message": @"Image doesn't exist",
                              @"code": @"ENOENT"
                              };
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:err];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    PECropViewController *cropController = [[PECropViewController alloc] init];
    cropController.delegate = self;
    cropController.image = image;
    cropController.keepingCropAspectRatio = YES;
    
    CGFloat width = image.size.width;
    CGFloat height = image.size.height;
    CGFloat croperWidth;
    CGFloat croperHeight;
    
    croperWidth = MIN(width, height);
    croperHeight = croperWidth;
    
    cropController.toolbarHidden = YES;
    cropController.rotationEnabled = NO;
    cropController.imageCropRect = CGRectMake((width - croperWidth) / 2,
                                              (height - croperHeight) / 2,
                                              croperWidth,
                                              croperHeight);
    
    self.callbackId = command.callbackId;
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:cropController];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    [self.viewController presentViewController:navigationController animated:YES completion:NULL];
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize{
    UIGraphicsBeginImageContext(newSize);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

#pragma mark - PECropViewControllerDelegate

- (void)cropViewController:(PECropViewController *)controller didFinishCroppingImage:(UIImage *)croppedImage {
    [controller dismissViewControllerAnimated:YES completion:nil];
    if (!self.callbackId) return;
    
    UIImage *resizedImage = [self imageWithImage:croppedImage scaledToSize:CGSizeMake(500.0, 500.0)];
    NSData *data = UIImageJPEGRepresentation(resizedImage, (CGFloat) self.quality);
    NSString* filePath = [self tempFilePath:@"jpg"];
    CDVPluginResult *result;
    NSError *err;
    
    // save file
    if (![data writeToFile:filePath options:NSAtomicWrite error:&err]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[err localizedDescription]];
    }
    else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[[NSURL fileURLWithPath:filePath] absoluteString]];
    }
    
    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
    self.callbackId = nil;
}

- (void)cropViewControllerDidCancel:(PECropViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
    NSDictionary *err = @{
                          @"message": @"User cancelled",
                          @"code": @"userCancelled"
                          };
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:err];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    self.callbackId = nil;
}

#pragma mark - Utilites

- (NSString*)tempFilePath:(NSString*)extension
{
    NSString* docsPath = [NSTemporaryDirectory()stringByStandardizingPath];
    NSFileManager* fileMgr = [[NSFileManager alloc] init]; // recommended by Apple (vs [NSFileManager defaultManager]) to be threadsafe
    NSString* filePath;
    
    // generate unique file name
    int i = 1;
    do {
        filePath = [NSString stringWithFormat:@"%@/%@%03d.%@", docsPath, CDV_PHOTO_PREFIX, i++, extension];
    } while ([fileMgr fileExistsAtPath:filePath]);
    
    return filePath;
}

@end
