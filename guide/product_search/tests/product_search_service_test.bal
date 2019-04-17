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
//
import ballerina/http;
import ballerina/test;
import ballerina/io;
import ecommerce_backend;

http:Client httpEndpoint = new("http://localhost:9090/products", config = { timeoutMillis: 10000 });

@test:Config
function testProductSearchService() {
    // Test the searchProducts resource
    // Send a request to service
    var result = httpEndpoint->get("/search?item=TV");
    if (result is http:Response) {
        int expectedResult = 200;
        test:assertEquals(result.statusCode, expectedResult, msg = "backend status code did not match");
        json expectedJson = { "itemId": "TV", "brand": "ABC", "condition": "New",
            "itemLocation": "USA",
            "marketingPrice": "$100",
            "seller": "XYZ" };
        var receivedJson = result.getJsonPayload();
        if (receivedJson is json) {
            // Assert the response message JSON payload
            test:assertEquals(receivedJson, expectedJson,
                msg = "Item details of the eCommerce service did not match with expected results");
        } else {
            test:assertFail(msg = "An error occured while retrieving the Json payload");
        }
    } else {
        test:assertFail(msg = "An error occured while execute the GET");
    }
}
