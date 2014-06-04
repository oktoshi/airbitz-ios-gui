//
//  MainViewController.m
//  AirBitz
//
//  Created by Carson Whitsett on 2/28/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import "ABC.h"
#import "MainViewController.h"
#import "TabBarView.h"
#import "DirectoryViewController.h"
#import "RequestViewController.h"
#import "SendViewController.h"
#import "WalletsViewController.h"
#import "LoginViewController.h"
#import "Notifications.h"
#import "SettingsViewController.h"
#import "SendStatusViewController.h"
#import "TransactionDetailsViewController.h"
#import "User.h"
#import "Config.h"
#import "Util.h"
#import "CoreBridge.h"

id mainId;

typedef enum eAppMode
{
	APP_MODE_DIRECTORY,
	APP_MODE_REQUEST,
	APP_MODE_SEND,
	APP_MODE_WALLETS,
	APP_MODE_SETTINGS
} tAppMode;

@interface MainViewController () <TabBarViewDelegate, RequestViewControllerDelegate, SettingsViewControllerDelegate, LoginViewControllerDelegate, TransactionDetailsViewControllerDelegate>
{
	UIViewController *selectedViewController;
	DirectoryViewController *diretoryViewController;
	RequestViewController *requestViewController;
	SendViewController *sendViewController;
	WalletsViewController *walletsViewController;
	LoginViewController *loginViewController;
	SettingsViewController *settingsViewController;
	SendStatusViewController  *sendStatusController;
    TransactionDetailsViewController *txDetailsController;
	CGRect originalTabBarFrame;
	CGRect originalViewFrame;
	tAppMode appMode;
}

@property (nonatomic, weak) IBOutlet TabBarView *tabBar;

@end

@implementation MainViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [User initAll];

    NSMutableData *seedData = [[NSMutableData alloc] init];
    [self fillSeedData:seedData];
#if !DIRECTORY_ONLY
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docs_dir = [paths objectAtIndex:0];

    tABC_Error Error;
    Error.code = ABC_CC_Ok;
   // NSLog(@"Calling ABC_Initialize...");
    ABC_Initialize([docs_dir UTF8String],
                   ABC_BitCoin_Event_Callback,
                   (__bridge void *) self,
                   (unsigned char *)[seedData bytes],
                   (unsigned int)[seedData length],
                   &Error);
    //NSLog(@"ABC_Initialize complete");
    [Util printABC_Error:&Error];
#endif

	originalTabBarFrame = self.tabBar.frame;
	originalViewFrame = self.view.frame;
	// Do any additional setup after loading the view.
	UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle: nil];
	diretoryViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"DirectoryViewController"];
	requestViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"RequestViewController"];
	requestViewController.delegate = self;

	sendViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"SendViewController"];

	walletsViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"WalletsViewController"];

	loginViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"LoginViewController"];
	loginViewController.delegate = self;
	settingsViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"SettingsViewController"];
	settingsViewController.delegate = self;
	

}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewWillAppear:(BOOL)animated
{
	self.tabBar.delegate = self;
	
	//originalTabBarPosition = self.tabBar.frame.origin;
#if DIRECTORY_ONLY
	[self hideTabBarAnimated:NO];
#else
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showHideTabBar:) name:NOTIFICATION_SHOW_TAB_BAR object:nil];
#endif
	[self.tabBar selectButtonAtIndex:0];
}

#pragma mark - Misc Methods


- (void)fillSeedData:(NSMutableData *)data
{
    NSMutableString *strSeed = [[NSMutableString alloc] init];

    // add the advertiser identifier
    if ([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)])
    {
        [strSeed appendString:[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    }

    // add the UUID
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    [strSeed appendString:[[NSString alloc] initWithString:(__bridge NSString *)string]];
    CFRelease(string);

    // add the device name
    [strSeed appendString:[[UIDevice currentDevice] name]];

    // add the string to the data
    //NSLog(@"seed string: %@", strSeed);
    [data appendData:[strSeed dataUsingEncoding:NSUTF8StringEncoding]];

    double time = CACurrentMediaTime();

    [data appendBytes:&time length:sizeof(double)];

    u_int32_t rand = arc4random();

    [data appendBytes:&rand length:sizeof(u_int32_t)];
}

-(void)showLogin
{
	loginViewController.view.frame = self.view.bounds;
	[self.view insertSubview:loginViewController.view belowSubview:self.tabBar];
	loginViewController.view.alpha = 0.0;
	[self hideTabBarAnimated:YES];
	[UIView animateWithDuration:0.25
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseIn
					 animations:^
	 {
		 loginViewController.view.alpha = 1.0;
	 }
					 completion:^(BOOL finished)
	 {
	 }];
}

-(void)updateChildViewSizeForTabBar
{
	if([selectedViewController respondsToSelector:@selector(viewBottom:)])
	{
		[(id)selectedViewController viewBottom:self.tabBar.frame.origin.y + 5.0];	/* 5.0 covers transparent area at top of tab bar */
	}
}

-(void)showHideTabBar:(NSNotification *)notification
{
	BOOL showTabBar = ((NSNumber *)notification.object).boolValue;
	if(showTabBar)
	{
		[self showTabBarAnimated:YES];
	}
	else
	{
		[self hideTabBarAnimated:YES];
	}
}

-(void)hideTabBarAnimated:(BOOL)animated
{
	if(animated)
	{
		[UIView animateWithDuration:0.25
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
						 animations:^
		 {
			 CGRect frame = self.tabBar.frame;
			 frame.origin.y = originalTabBarFrame.origin.y + frame.size.height;
			 self.tabBar.frame = frame;
			 
			 selectedViewController.view.frame = self.view.bounds;
		 }
		completion:^(BOOL finished)
		 {
			//NSLog(@"view: %f, %f, tab bar origin: %f", self.view.frame.origin.y, self.view.frame.size.height, self.tabBar.frame.origin.y);
		 }];
	}
	else
	{
		CGRect frame = self.tabBar.frame;
		frame.origin.y = originalTabBarFrame.origin.y + frame.size.height;
		self.tabBar.frame = frame;
		
		selectedViewController.view.frame = self.view.bounds;
	}
}

-(void)launchViewControllerBasedOnAppMode
{
    mainId = self;
	switch(appMode)
	{
		case APP_MODE_DIRECTORY:
		{
			if(selectedViewController != diretoryViewController)
			{
				[selectedViewController.view removeFromSuperview];
				selectedViewController = diretoryViewController;
				[self.view insertSubview:selectedViewController.view belowSubview:self.tabBar];
			}
			break;
		}
		case APP_MODE_REQUEST:
		{
			if(selectedViewController != requestViewController)
			{
				if(([User Singleton].name.length && [User Singleton].password.length) || (DIRECTORY_ONLY == 1))
				{
					[selectedViewController.view removeFromSuperview];
					selectedViewController = requestViewController;
					[self.view insertSubview:selectedViewController.view belowSubview:self.tabBar];
				}
				else
				{
					[self showLogin];
				}
			}
			break;
		}
			break;
		case APP_MODE_SEND:
		{
			if(selectedViewController != sendViewController)
			{
				if(([User Singleton].name.length && [User Singleton].password.length) || (DIRECTORY_ONLY == 1))
				{
					tABC_CC result;
					tABC_WalletInfo **walletInfo;
					unsigned int numWallets = 0;
					tABC_Error error;
					
					result = ABC_GetWallets([[User Singleton].name UTF8String],
										   [[User Singleton].password UTF8String],
										   &walletInfo,
										   &numWallets,
										   &error);
					
					if(1) //numWallets)
					{
						[selectedViewController.view removeFromSuperview];
						selectedViewController = sendViewController;
						[self.view insertSubview:selectedViewController.view belowSubview:self.tabBar];
					}
					else
					{
						[Util printABC_Error:&error];
						UIAlertView *alert = [[UIAlertView alloc]
											  initWithTitle:NSLocalizedString(@"No Wallets", @"Alert title that warns user they have no wallets to send from")
											  message:NSLocalizedString(@"You have no wallets from which to send funds.  First create a wallet by tapping on the Wallets tab and hitting the '+' button", nil)
											  delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
						[alert show];
					}
					
				}
				else
				{
					[self showLogin];
				}
			}
			break;
		}
		case APP_MODE_WALLETS:
		{
			if(selectedViewController != walletsViewController)
			{
				if(([User Singleton].name.length && [User Singleton].password.length) || (DIRECTORY_ONLY == 1))
				{
					[selectedViewController.view removeFromSuperview];
					selectedViewController = walletsViewController;
					[self.view insertSubview:selectedViewController.view belowSubview:self.tabBar];
				}
				else
				{
					[self showLogin];
				}
			}
			break;
		}
		case APP_MODE_SETTINGS:
			if(selectedViewController != settingsViewController)
			{
				if(([User Singleton].name.length && [User Singleton].password.length) || (DIRECTORY_ONLY == 1))
				{
					[selectedViewController.view removeFromSuperview];
					selectedViewController = settingsViewController;
					[self.view insertSubview:selectedViewController.view belowSubview:self.tabBar];
				}
				else
				{
					[self showLogin];
				}
			}
			break;
	}
}

-(void)showTabBarAnimated:(BOOL)animated
{
	if(animated)
	{
		[UIView animateWithDuration:0.25
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
						 animations:^
		 {
			 self.tabBar.frame = originalTabBarFrame;
			 CGRect frame = self.view.bounds;
			 frame.size.height -= (originalTabBarFrame.size.height - 5.0);
			 selectedViewController.view.frame = frame;
		 }
		 completion:^(BOOL finished)
		 {
			// NSLog(@"view: %f, %f, tab bar origin: %f", self.view.frame.origin.y, self.view.frame.size.height, self.tabBar.frame.origin.y);

		 }];
	}
	else
	{
		self.tabBar.frame = originalTabBarFrame;
		
		CGRect frame = self.view.bounds;
		frame.size.height -= (originalTabBarFrame.size.height - 5.0);
		selectedViewController.view.frame = frame;
	}
}

#pragma mark TabBarView delegates

-(void)tabVarView:(TabBarView *)view selectedSubview:(UIView *)subview
{
	//NSLog(@"Selecting view %i", (int) subview.tag);
	appMode = (tAppMode)(subview.tag);

	[self launchViewControllerBasedOnAppMode]; //will show login if necessary
	[self updateChildViewSizeForTabBar];
}

#pragma mark RequestViewControllerDelegates

-(void)RequestViewControllerDone:(RequestViewController *)vc
{
	//cw this method currently not used
	
	//pop back to directory
	//[self.tabBar selectButtonAtIndex:0];
}

#pragma mark SettingsViewControllerDelegates

-(void)SettingsViewControllerDone:(SettingsViewController *)controller
{
	appMode = APP_MODE_DIRECTORY;
	[self.tabBar selectButtonAtIndex:APP_MODE_DIRECTORY];
}

#pragma mark LoginViewControllerDelegates

-(void)loginViewControllerDidAbort
{
	appMode = APP_MODE_DIRECTORY;
	[self.tabBar selectButtonAtIndex:APP_MODE_DIRECTORY];
	[self showTabBarAnimated:YES];
	[loginViewController.view removeFromSuperview];
}

-(void)loginViewControllerDidLogin
{
    [loginViewController.view removeFromSuperview];
    [self showTabBarAnimated:YES];
    [self launchViewControllerBasedOnAppMode];
}

-(void)launchReceiving: (NSArray *) params
{
    NSString *walletUUID = params[0];
    NSString *txId = params[1];
    Transaction *transaction = [CoreBridge getTransaction:walletUUID withTx:txId];
    NSLog(@("launchReceiving: %@ %@ %@\n"), walletUUID, txId, transaction);
    /* If we aren't on the selector view, then just notify the user */
    if (selectedViewController != requestViewController && txDetailsController == nil)
    {
        NSLog(@("Showing Notification\n"));
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.alertBody = [NSString stringWithFormat:@"Received funds"];
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        localNotification.applicationIconBadgeNumber = 1;
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
    }
    else
    {
        NSLog(@("Launching Receiving page\n"));
        UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
        sendStatusController = [mainStoryboard instantiateViewControllerWithIdentifier:@"SendStatusViewController"];

        CGRect frame = self.view.bounds;
        sendStatusController.view.frame = frame;
        [self.view addSubview:sendStatusController.view];
        sendStatusController.view.alpha = 0.0;
        sendStatusController.messageLabel.text = NSLocalizedString(@"Receiving...", @"status message");
        sendStatusController.titleLabel.text = NSLocalizedString(@"Receive Status", @"status title");
        [UIView animateWithDuration:0.35
                            delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                        animations:^
        {
            sendStatusController.view.alpha = 1.0;
        }
        completion:^(BOOL finished)
        {
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self launchTransactionDetails:transaction];
                [sendStatusController.view removeFromSuperview];
                sendStatusController = nil;
            });
        }];
    }
}

-(void) launchTransactionDetails: (Transaction *)transaction
{
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
    txDetailsController = [mainStoryboard instantiateViewControllerWithIdentifier:@"TransactionDetailsViewController"];
    txDetailsController.transaction = transaction;
    txDetailsController.delegate = self;
    txDetailsController.bOldTransaction = NO;
    txDetailsController.transactionDetailsMode = TD_MODE_RECEIVED;

    CGRect frame = self.view.bounds;
    frame.origin.x = frame.size.width;
    txDetailsController.view.frame = frame;
    [self.view addSubview:txDetailsController.view];
    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^
    {
        txDetailsController.view.frame = self.view.bounds;
    }
    completion:^(BOOL finished)
    {
    }];
}

-(void)TransactionDetailsViewControllerDone:(TransactionDetailsViewController *)controller
{
    [UIView animateWithDuration:0.35
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^
    {
        CGRect frame = self.view.bounds;
        frame.origin.x = frame.size.width;
        txDetailsController.view.frame = frame;
    }
    completion:^(BOOL finished)
    {
        [txDetailsController.view removeFromSuperview];
        txDetailsController = nil;
    }];
}

#pragma mark - ABC Callbacks

void ABC_BitCoin_Event_Callback(const tABC_AsyncBitCoinInfo *pInfo)
{
    if (pInfo->eventType == ABC_AsyncEventType_IncomingBitCoin)
    {
        NSString *walletUUID = [NSString stringWithUTF8String:pInfo->szWalletUUID];
        NSString *txId = [NSString stringWithUTF8String:pInfo->szTxID];
        NSArray *params = [NSArray arrayWithObjects: walletUUID, txId, nil];
        [mainId performSelectorOnMainThread:@selector(launchReceiving:) withObject:params waitUntilDone:NO];
    }
}

@end
