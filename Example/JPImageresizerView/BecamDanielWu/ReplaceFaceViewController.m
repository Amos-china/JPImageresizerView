//
//  ReplaceFaceViewController.m
//  JPImageresizerView_Example
//
//  Created by 周健平 on 2020/6/20.
//  Copyright © 2020 ZhouJianPing. All rights reserved.
//

#import "ReplaceFaceViewController.h"
#import "JPPreviewViewController.h"
#import "JPPhotoTool.h"

@interface ReplaceFaceViewController() <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@end

@implementation ReplaceFaceViewController

- (instancetype)initWithPersonImage:(UIImage *)personImage faceImage:(UIImage *)faceImage {
    if (self = [super init]) {
        self.personImage = personImage;
        self.faceImage = faceImage;
    }
    return self;
}

#pragma mark - 生命周期

- (void)viewDidLoad {
    [super viewDidLoad];
    [self __setupNavigationBar];
    [self __setupSubviews];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
#pragma clang diagnostic pop
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

- (void)dealloc {
    JPLog(@"%@ is dead", self.class);
}

#pragma mark - 初始布局

- (void)__setupNavigationBar {
    UIBarButtonItem *replaceImgBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(__replacePersonImage)];
    
    UIButton *synthesizeBtn = ({
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        [btn setTitle:@"合成" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(__synthesizeImages) forControlEvents:UIControlEventTouchUpInside];
        btn;
    });
    
    self.navigationItem.rightBarButtonItems = @[[[UIBarButtonItem alloc] initWithCustomView:synthesizeBtn], replaceImgBtn];
}

- (void)__setupSubviews {
    self.view.backgroundColor = UIColor.blackColor;
    
    if (self.personImage) {
        CGFloat w = JPPortraitScreenWidth;
        CGFloat h = w * (self.personImage.size.height / self.personImage.size.width);
        CGFloat x = 0;
        CGFloat y = JPHalfOfDiff(JPPortraitScreenHeight, h);
        UIImageView *personView = ({
            UIImageView *aImgView = [[UIImageView alloc] initWithFrame:CGRectMake(x, y, w, h)];
            aImgView.image = self.personImage;
            aImgView;
        });
        [self.view addSubview:personView];
        self.personView = personView;
        
        if (self.faceImage) {
            CGFloat scale = JPPortraitScreenWidth / self.personImage.size.width;
            w = (567.0 - 152.0 - 166.0) * scale;
            h = w * (300.0 / 263.0);
            x = self.personView.jp_x + JPHalfOfDiff(self.personView.jp_width, w);
            y = self.personView.jp_y + JPHalfOfDiff(self.personView.jp_height, h);
            @jp_weakify(self);
            FaceView *faceView = [[FaceView alloc] initWithFrame:CGRectMake(x, y, w, h) image:self.faceImage longPressAction:^{
                @jp_strongify(self);
                if (!self) return;
                [self __saveFaceImage];
            }];
            [self.view addSubview:faceView];
            self.faceView = faceView;
        }
    }
}

#pragma mark - 保存脸模图片

- (void)__saveFaceImage {
    UIAlertController *alertCtr = [UIAlertController alertControllerWithTitle:@"是否保存脸模到相册" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alertCtr addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [JPProgressHUD show];
        [JPPhotoToolSI savePhotoToAppAlbumWithImage:self.faceImage successHandle:^(NSString *assetID) {
            [JPProgressHUD showSuccessWithStatus:@"保存成功" userInteractionEnabled:YES];
        } failHandle:^(NSString *assetID, BOOL isGetAlbumFail, BOOL isSaveFail) {
            [JPProgressHUD showErrorWithStatus:@"保存失败" userInteractionEnabled:YES];
        }];
    }]];
    [alertCtr addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertCtr animated:YES completion:nil];
}

#pragma mark - 合成图片

- (void)__synthesizeImages {
    [JPProgressHUD show];
    
    UIImage *personImage = self.personView.image;
    CGRect rect = CGRectMake(0, 0, floorl(self.personView.frame.size.width), floorl(self.personView.frame.size.height));
    
    UIImage *faceImage = self.faceView.faceImage;
    CGFloat faceRadian = self.faceView.layer.jp_radian;
    CGFloat faceScale = self.faceView.layer.jp_scaleX;
    CGRect faceBounds = self.faceView.layer.bounds;
    CGPoint faceOrigin = [self.faceView convertPoint:CGPointZero toView:self.personView];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIGraphicsBeginImageContextWithOptions(rect.size, NO, JPScreenScale);
        [personImage drawInRect:rect];
        
        CGImageRef faceImageRef = [self __imageDownMirrored:faceImage].CGImage;
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextTranslateCTM(context, faceOrigin.x, faceOrigin.y); // 要先进行位移，确定好位置后再进行其他的形变操作，否则位置错乱。
        CGContextScaleCTM(context, faceScale, faceScale);
        CGContextRotateCTM(context, faceRadian);
        CGContextDrawImage(context, faceBounds, faceImageRef);
        
        UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [JPProgressHUD dismiss];
            JPPreviewViewController *vc = [JPPreviewViewController buildWithResult:[[JPImageresizerResult alloc] initWithImage:resultImage cacheURL:nil]];
            [self.navigationController pushViewController:vc animated:YES];
        });
    });
}

#pragma mark - 私有方法

- (UIImage *)__imageDownMirrored:(UIImage *)image {
    CGImageRef imageRef = image.CGImage;
    CGRect bounds = CGRectMake(0, 0, CGImageGetWidth(imageRef), CGImageGetHeight(imageRef));
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformMakeTranslation(0.0, bounds.size.height);
    transform = CGAffineTransformScale(transform, 1.0, -1.0);
    
    UIGraphicsBeginImageContext(bounds.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextTranslateCTM(context, 0.0, -bounds.size.height);
    CGContextConcatCTM(context, transform);
    CGContextDrawImage(UIGraphicsGetCurrentContext(), bounds, imageRef);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (void)__replacePersonImage {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:YES completion:^{
        [JPProgressHUD showImage:nil status:@"替换人物图片" userInteractionEnabled:YES];
    }];
}

#pragma mark - UIImagePickerController

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (!image) {
        if (@available(iOS 13.0, *)) {
            NSURL *url = info[UIImagePickerControllerImageURL];
            image = [UIImage imageWithData:[NSData dataWithContentsOfURL:url]];
        }
    }
    
    if (!image) {
        [JPProgressHUD showErrorWithStatus:@"照片获取失败" userInteractionEnabled:YES];
        return;
    }
    
    self.personImage = image;
    
    CGFloat w = JPPortraitScreenWidth;
    CGFloat h = w * (image.size.height / image.size.width);
    CGFloat x = 0;
    CGFloat y = JPHalfOfDiff(JPPortraitScreenHeight, h);
    
    [UIView transitionWithView:self.personView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.personView.image = image;
    } completion:nil];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.personView.frame = CGRectMake(x, y, w, h);
    }];
}

@end
