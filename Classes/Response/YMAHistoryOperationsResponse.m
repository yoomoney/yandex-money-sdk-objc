//
// Created by Alexander Mertvetsov on 23.05.14.
// Copyright (c) 2014 Yandex.Money. All rights reserved.
//

#import "YMAHistoryOperationsResponse.h"
#import "YMAConstants.h"
#import "YMAHistoryOperationModel.h"

static NSString *const kParameterError = @"error";
static NSString *const kParameterNextRecord = @"next_record";
static NSString *const kParameterOperations = @"operations";

static NSString *const kParameterOperationOperationId = @"operation_id";
static NSString *const kParameterOperationStatus = @"status";
static NSString *const kParameterOperationDatetime = @"datetime";
static NSString *const kParameterOperationTitle = @"title";
static NSString *const kParameterOperationPatternId = @"pattern_id";
static NSString *const kParameterOperationDirection = @"direction";
static NSString *const kParameterOperationAmount = @"amount";
static NSString *const kParameterOperationLabel = @"label";
static NSString *const kParameterOperationFavourite = @"favourite";
static NSString *const kParameterOperationType = @"type";

@implementation YMAHistoryOperationsResponse

+ (YMAHistoryOperationModel *)historyOperationByModel:(id)historyOperationModel {
    NSString *operationId = [historyOperationModel objectForKey:kParameterOperationOperationId];
    NSString *statusString = [historyOperationModel objectForKey:kParameterOperationStatus];
    YMAHistoryOperationStatus status = [YMAHistoryOperationModel historyOperationStatusByString:statusString];

    NSString *dateTimeString = [historyOperationModel objectForKey:kParameterOperationDatetime];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"Europe/Moscow"]];
    NSDate *dateTime = [formatter dateFromString:dateTimeString];

    NSString *title = [historyOperationModel objectForKey:kParameterOperationTitle];
    NSString *patternId = [historyOperationModel objectForKey:kParameterOperationPatternId];

    NSString *directionString = [historyOperationModel objectForKey:kParameterOperationDirection];
    YMAHistoryOperationDirection direction = [YMAHistoryOperationModel historyOperationDirectionByString:directionString];

    NSString *amount = [[historyOperationModel objectForKey:kParameterOperationAmount] stringValue];
    NSString *label = [historyOperationModel objectForKey:kParameterOperationLabel];

    BOOL favourite = [[historyOperationModel objectForKey:kParameterOperationFavourite] boolValue];

    NSString *typeString = [historyOperationModel objectForKey:kParameterOperationType];
    YMAHistoryOperationType type = [YMAHistoryOperationModel historyOperationTypeByString:typeString];

    return [YMAHistoryOperationModel historyOperationWithOperationId:operationId status:status datetime:dateTime title:title patternId:patternId direction:direction amount:amount label:label favourite:favourite type:type];
}

#pragma mark -
#pragma mark *** Overridden methods ***
#pragma mark -

- (void)parseJSONModel:(id)responseModel error:(NSError * __autoreleasing *)error {
    NSString *errorKey = [responseModel objectForKey:kParameterError];

    if (errorKey) {
        if (!error) return;

        NSError *unknownError = [NSError errorWithDomain:kErrorKeyUnknown code:0 userInfo:@{@"response" : self}];
        *error = errorKey ? [NSError errorWithDomain:errorKey code:0 userInfo:@{@"response" : self}] : unknownError;

        return;
    }

    NSString *nextRecord = [responseModel objectForKey:kParameterNextRecord];
    _nextRecord = [nextRecord copy];

    id operationsModel = [responseModel objectForKey:kParameterOperations];

    if (!operationsModel)
        return;

    NSMutableArray *historyOperations = [NSMutableArray array];

    for (id historyOperationModel in operationsModel) {
        YMAHistoryOperationModel *operation = [YMAHistoryOperationsResponse historyOperationByModel:historyOperationModel];
        [historyOperations addObject:operation];
    }

    _operations = historyOperations;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, %@>", [self class], (__bridge void *) self,
                                      @{
                                              @"nextRecord" : self.nextRecord,
                                              @"operations" : self.operations.description
                                      }];
}

@end