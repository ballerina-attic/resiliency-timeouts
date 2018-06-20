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

endpoint http:Client httpEndpoint {
    url: "http://localhost:9090/products",
    timeoutMillis: 10000
};

function beforeFunction() {
    // Start eCommerce backend service
    _ = test:startServices("product_search");
}
function afterFunction() {
    // Start eCommerce backend service
    test:stopServices("product_search");
}

@test:Config {
    before: "beforeFunction",
    after: "afterFunction"
}
function testProductSearchService() {

    // Initialize the empty http request and response
    http:Request req = new;
    http:Response resp = new;

    // Test the searchProducts resource
    // Send a request to service
    resp = check httpEndpoint->get("/search?item=TV");

    int expectedResult = 500;

    test:assertEquals(resp.statusCode, expectedResult, msg = "backend error code did not
    match");
}
