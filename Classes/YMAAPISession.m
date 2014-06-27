//
// Created by Alexander Mertvetsov on 20.05.14.
// Copyright (c) 2014 Yandex.Money. All rights reserved.
//

#import "YMAAPISession.h"
#import "YMAHostsProvider.h"

static NSString *const kUrlAuthorize = @"oauth/authorize";
static NSString *const kUrlToken = @"oauth/token";
static NSString *const kUrlRevoke = @"api/revoke";
static NSString *const kParameterClientId = @"client_id";


NSString *const YMAParameterResponseType = @"response_type";
NSString *const YMAValueParameterResponseType = @"code";

@implementation YMAAPISession

- (NSURLRequest *)authorizationRequestWithClientId:(NSString *)clientId andAdditionalParams:(NSDictionary *)params {
    return [self authorizationRequestWithUrl:kUrlAuthorize clientId:clientId andAdditionalParams:params];
}

- (NSURLRequest *)authorizationRequestWithUrl:(NSString *)relativeUrlString clientId:(NSString *)clientId andAdditionalParams:(NSDictionary *)params {
    NSMutableString *post = [NSMutableString stringWithCapacity:0];

    NSString *clientIdParamKey = [YMAConnection addPercentEscapesForString:kParameterClientId];
    NSString *clientIdParamValue = [YMAConnection addPercentEscapesForString:clientId];

    [post appendString:[NSString stringWithFormat:@"%@=%@&", clientIdParamKey, clientIdParamValue]];

    for (NSString *key in params.allKeys) {

        NSString *paramKey = [YMAConnection addPercentEscapesForString:key];
        NSString *paramValue = [YMAConnection addPercentEscapesForString:[params objectForKey:key]];

        [post appendString:[NSString stringWithFormat:@"%@=%@&", paramKey, paramValue]];
    }

    NSString *urlString = [NSString stringWithFormat:@"https://%@/%@", [YMAHostsProvider sharedManager].spMoneyUrl, relativeUrlString];
    NSURL *url = [NSURL URLWithString:urlString];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSData *postData = [post dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    [request setHTTPMethod:YMAMethodPost];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long) [postData length]] forHTTPHeaderField:@"Content-Length"];
    [request setValue:YMAValueContentTypeDefault forHTTPHeaderField:YMAHeaderContentType];
    [request setValue:_userAgent forHTTPHeaderField:YMAHeaderUserAgent];
    [request setHTTPBody:postData];

    return request;
}

- (BOOL)isRequest:(NSURLRequest *)request toRedirectUrl:(NSString *)redirectUrl authorizationInfo:(NSMutableDictionary * __autoreleasing *)authInfo error:(NSError * __autoreleasing *)error {
    NSURL *requestUrl = request.URL;

    if (!requestUrl)
        return NO;

    NSString *scheme = requestUrl.scheme;
    NSString *path = requestUrl.path;
    NSString *host = requestUrl.host;

    NSString *strippedURL = [NSString stringWithFormat:@"%@://%@%@", scheme, host, path];

    if ([strippedURL isEqual:redirectUrl]) {

        NSString *query = requestUrl.query;

        if (!query || query.length == 0) {
            if (error)
                *error = [NSError errorWithDomain:YMAErrorKeyUnknown code:0 userInfo:@{@"requestUrl" : request.URL}];
        } else if (authInfo) {

            *authInfo = [NSMutableDictionary dictionary];

            NSArray *queryComponents = [query componentsSeparatedByString:@"&"];

            for (NSString *keyValuePair in queryComponents) {
                NSArray *pairComponents = [keyValuePair componentsSeparatedByString:@"="];
                NSString *key = [pairComponents objectAtIndex:0];
                NSString *value = [pairComponents objectAtIndex:1];

                [*authInfo setObject:value forKey:key];
            }
        }

        return YES;
    } else
        return NO;
}

- (void)receiveTokenWithWithCode:(NSString *)code clientId:(NSString *)clientId andAdditionalParams:(NSDictionary *)params completion:(YMAIdHandler)block {
    [self receiveTokenWithWithUrl:kUrlToken code:code clientId:clientId andAdditionalParams:params completion:block];
}

- (void)receiveTokenWithWithUrl:(NSString *)relativeUrlString code:(NSString *)code clientId:(NSString *)clientId andAdditionalParams:(NSDictionary *)params completion:(YMAIdHandler)block {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setObject:code forKey:YMAValueParameterResponseType];
    [parameters setObject:clientId forKey:kParameterClientId];
    [parameters addEntriesFromDictionary:params];

    NSString *urlString = [NSString stringWithFormat:@"https://%@/%@", [YMAHostsProvider sharedManager].spMoneyUrl, relativeUrlString];
    NSURL *url = [NSURL URLWithString:urlString];

    [self performRequestWithToken:nil parameters:parameters url:url completion:^(NSURLRequest *request, NSURLResponse *response, NSData *responseData, NSError *error) {

        if (error) {
            block(nil, error);
            return;
        }

        NSInteger statusCode = ((NSHTTPURLResponse *) response).statusCode;

        id responseModel = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:&error];

        NSError *unknownError = [NSError errorWithDomain:YMAErrorKeyUnknown code:0 userInfo:@{@"response" : response, @"request" : request}];

        if (error || !responseModel) {
            block(nil, (error) ? error : unknownError);
            return;
        }

        if (statusCode == YMAStatusCodeOkHTTP) {

            NSString *accessToken = [responseModel objectForKey:@"access_token"];

            if (accessToken) {
                block(accessToken, nil);
            } else
                block(nil, unknownError);

            return;
        }

        NSString *errorKey = [responseModel objectForKey:@"error"];

        (errorKey) ? block(nil, [NSError errorWithDomain:NSLocalizedString(errorKey, errorKey) code:statusCode userInfo:nil]) : block(nil, unknownError);
    }];
}

- (void)revokeToken:(NSString *)token completion:(YMAHandler)block {
    NSString *urlString = [NSString stringWithFormat:@"https://%@/%@", [YMAHostsProvider sharedManager].moneyUrl, kUrlRevoke];
    NSURL *url = [NSURL URLWithString:urlString];

    [self performAndProcessRequestWithToken:token parameters:nil url:url completion:^(NSURLRequest *urlRequest, NSURLResponse *urlResponse, NSData *responseData, NSError *error) {
        if (error) {
            block(error);
            return;
        }

        block(nil);
    }];
}

- (void)performRequest:(YMABaseRequest *)request token:(NSString *)token completion:(YMARequestHandler)block {
    NSError *unknownError = [NSError errorWithDomain:YMAErrorKeyUnknown code:0 userInfo:@{@"request" : request}];

    if (!request) {
        block(request, nil, unknownError);
        return;
    }

    if ([request conformsToProtocol:@protocol(YMAParametersPosting)]) {
        YMABaseRequest <YMAParametersPosting> *paramsRequest = (YMABaseRequest <YMAParametersPosting> *) request;

        [self performAndProcessRequestWithToken:token parameters:paramsRequest.parameters url:request.requestUrl completion:^(NSURLRequest *urlRequest, NSURLResponse *urlResponse, NSData *responseData, NSError *error) {
            if (error) {
                block(request, nil, error);
                return;
            }

            [request buildResponseWithData:responseData queue:_responseQueue andCompletion:block];
        }];
    } else if ([request conformsToProtocol:@protocol(YMADataPosting)]) {
        YMABaseRequest <YMADataPosting> *dataRequest = (YMABaseRequest <YMADataPosting> *) request;

        [self performAndProcessRequestWithToken:token data:dataRequest.data url:dataRequest.requestUrl completion:^(NSURLRequest *urlRequest, NSURLResponse *urlResponse, NSData *responseData, NSError *error) {
            if (error) {
                block(request, nil, error);
                return;
            }

            [request buildResponseWithData:responseData queue:_responseQueue andCompletion:block];
        }];
    }
}

@end