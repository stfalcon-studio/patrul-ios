/*
 Copyright (c) 2015 - 2016. Stepan Tanasiychuk
 This file is part of Gromadskyi Patrul is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by the Free Software Found ation, version 3 of the License, or any later version.
 If you would like to use any part of this project for commercial purposes, please contact us
 for negotiating licensing terms and getting permission for commercial use. Our email address: info@stfalcon.com
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General Public License along with this program.
 If not, see http://www.gnu.org/licenses/.
 */
// https://github.com/stfalcon-studio/patrol-android/blob/master/app/build.gradle
//
//  HRPViolationCell.h
//  HromadskyiPatrul
//
//  Created by msm72 on 26.08.15.
//  Copyright (c) 2015 Monastyrskiy Sergey. All rights reserved.
//


#import <UIKit/UIKit.h>
#import "HRPViolation.h"
#import "HRPButton.h"
#import "MBProgressHUD.h"


typedef NS_ENUM (NSInteger, CellBackgroundColorType) {
    CellBackgroundColorTypeBlue,
    CellBackgroundColorTypeBlack
};


@interface HRPViolationCell : UICollectionViewCell

@property (strong, nonatomic) HRPViolation *violation;
@property (strong, nonatomic) IBOutlet UIImageView *photoImageView;
@property (strong, nonatomic) IBOutlet UIImageView *playVideoImageView;
@property (strong, nonatomic) IBOutlet HRPButton *uploadStateButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityLoader;

@property (strong, nonatomic) MBProgressHUD *HUD;

- (void)customizeCellStyle;
- (void)uploadImage:(NSIndexPath *)indexPath inImages:(NSMutableArray *)images;
- (void)showActivityLoader;
- (void)hideActivityLoader;

@end
