#import <UIKit/UIKit.h>
#import <UIKit/UIHingeInteraction.h>
#import <math.h>

@interface ProbeController : UIViewController @end
@implementation ProbeController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UIHingeInteraction *interaction = [[UIHingeInteraction alloc] initWithUpdateHandler:^(UIHingeInteraction *sender, UIHingeInteractionUpdate *update) {
        UIHinge *hinge = update.hinge;
        if (!hinge) return;
        NSDictionary *receipt = @{@"angle_radians": @(hinge.angle), @"angle_degrees": @(hinge.angle * 180.0 / M_PI), @"status": @(hinge.status), @"timestamp": @([NSDate date].timeIntervalSince1970), @"api": @"UIKit.UIHingeInteraction"};
        NSData *data = [NSJSONSerialization dataWithJSONObject:receipt options:NSJSONWritingPrettyPrinted error:nil];
        [data writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/hinge.json"] atomically:YES];
    }];
    [self.view addInteraction:interaction];
}
@end
@interface ProbeScene : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation ProbeScene
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [ProbeController new];
    [self.window makeKeyAndVisible];
}
@end
@interface ProbeApp : UIResponder <UIApplicationDelegate> @end
@implementation ProbeApp
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *config = [[UISceneConfiguration alloc] initWithName:@"Probe" sessionRole:session.role];
    config.delegateClass = ProbeScene.class;
    return config;
}
@end
int main(int argc,char **argv) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(ProbeApp.class)); } }
