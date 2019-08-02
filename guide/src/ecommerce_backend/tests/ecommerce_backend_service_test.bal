// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/test;
import ballerina/io;

http:Client httpEndpoint = new( "http://localhost:9092/browse", { timeoutInMillis: 1000 });

function afterFunction() {
    // Start eCommerce backend service
    test:stopServices("ecommerce_backend");
}

@test:Config {
    after: "afterFunction"
}
function testeCommerceBackendService() returns error? {
    // Error message if server respond with 504 error
    string ERROR_MGS = "Idle timeout triggered before initiating inbound response";

    // Initialize the empty http request and response
    http:Request req;

    // Test the findItems resource
    // Send 4 requests to service and get the response and test with expected behaviour
    // Send the request to ecommerce backend for the 1st time
    var result1 = httpEndpoint->get("/items/TV");
    if (result1 is http:Response) {
        return;
    } else {
        test:assertEquals(result1.detail()?.message, ERROR_MGS, msg = "eCommerce endpoint didnot respond with 504 server error
            signal");
    }
    // Send the request to ecommerce backend for the 2nd time
    req = new;
    var result2 = httpEndpoint->get("/items/TV");
    if (result2 is http:Response) {
        return;
    } else {
        test:assertEquals(result2.detail()?.message, ERROR_MGS, msg = "eCommerce endpoint didnot respond with 504 server error signal");
    }
    if (result2 is http:Response) {
        return;
    } else {
        test:assertEquals(result2.detail()?.message, ERROR_MGS, msg =
                        "eCommerce endpoint didnot respond with 504 server error signal");
    }

    // Send the request to ecommerce backend for the 3rd time
    req = new;
    var result3 = httpEndpoint->get("/items/TV");

    if (result3 is http:Response) {
        return;
    } else {
        test:assertEquals(result3.detail()?.message, ERROR_MGS, msg =
                    "eCommerce endpoint didnot respond with 504 server error signal");
    }

    // Send the request to ecommerce backend for the 4th time
    req = new;
    var result4 = httpEndpoint->get("/items/TV");
    if (result4 is http:Response) {
        // Test the responses from the service with the original test data
        test:assertEquals(result4.statusCode, 200, msg = "eCommerce endpoint didnot respond with 200 OK signal");
        json expectedJson = { "itemId": "TV", "brand": "ABC", "condition": "New",
                        "itemLocation": "USA",
                        "marketingPrice": "$100",
                        "seller": "XYZ" };
        json receivedJson = check result4.getJsonPayload();
        // Assert the response message JSON payload
        test:assertEquals(receivedJson, expectedJson,
                msg = "Item details of the eCommerce service did not match with expected results");
    } else {
        return;
    }
}
