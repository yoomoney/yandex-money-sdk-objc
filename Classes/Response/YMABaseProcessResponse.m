//
//  YMABaseProcessResponse.m
//
//  Created by Alexander Mertvetsov on 01.11.13.
//  Copyright (c) 2013 Yandex.Money. All rights reserved.
//

#import "YMABaseProcessResponse.h"
#import "YMAConstants.h"

static NSString *const kKeyResponseStatusRefused = @"refused";
static NSString *const kKeyResponseStatusInProgress = @"in_progress";
static NSString *const kKeyResponseStatusExtAuthRequired = @"ext_auth_required";
static NSString *const kKeyResponseStatusHoldForPickup = @"hold_for_pickup";
static NSString *const kKeyResponseStatusSuccess = @"success";

static NSString *const kParameterStatus = @"status";
static NSString *const kParameterError = @"error";
static NSString *const kParameterNextRetry = @"next_retry";
static NSString *const kParameterAccountUnblockUri = @"account_unblock_uri";

@implementation YMABaseProcessResponse

- (id)init {
    self = [super init];

    if (self) {
        _nextRetry = 0;
    }

    return self;
}

#pragma mark -
#pragma mark *** NSOperation ***
#pragma mark -

- (void)parseJSONModel:(id)responseModel error:(NSError * __autoreleasing *)error {
    NSString *statusKey = [responseModel objectForKey:kParameterStatus];
    NSString *accountUnblockUri = [responseModel objectForKey:kParameterAccountUnblockUri];
    _accountUnblockUri = [accountUnblockUri copy];

    if ([statusKey isEqual:kKeyResponseStatusRefused]) {
        NSString *errorKey = [responseModel objectForKey:kParameterError];
        _status = YMAResponseStatusRefused;

        if (!error) return;

        NSError *unknownError = [NSError errorWithDomain:kErrorKeyUnknown code:0 userInfo:@{@"response" : self}];
        *error = errorKey ? [NSError errorWithDomain:errorKey code:0 userInfo:@{@"response" : self}] : unknownError;

        return;
    }

    if ([statusKey isEqual:kKeyResponseStatusInProgress]) {
        NSString *nextRetryString = [responseModel objectForKey:kParameterNextRetry];
        _nextRetry = (NSUInteger) [nextRetryString integerValue];
        _status = YMAResponseStatusInProgress;
    } else if ([statusKey isEqual:kKeyResponseStatusHoldForPickup])
        _status = YMAResponseStatusHoldForPickup;
    else if ([statusKey isEqual:kKeyResponseStatusExtAuthRequired])
        _status = YMAResponseStatusExtAuthRequired;
    else if ([statusKey isEqual:kKeyResponseStatusSuccess])
        _status = YMAResponseStatusSuccess;
    else
        _status = YMAResponseStatusUnknown;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, %@>", [self class], (__bridge void *) self,
                                      @{
                                              @"status" : [NSNumber numberWithInteger:self.status],
                                              @"nextRetry" : [NSNumber numberWithInteger:self.nextRetry],
                                              @"accountUnblockUri" : self.accountUnblockUri
                                      }];
}

@end
