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

package guide.ecommerce_backend;

import ballerina.net.http;
import ballerina.test;

function testeCommerceBackendService () {
    endpoint<http:HttpClient> httpEndpoint {
        create http:HttpClient("http://localhost:9092/browse", {endpointTimeout:1000});
    }

    http:HttpConnectorError err;
    // Initialize the empty http request and response
    http:OutRequest req = {};
    http:InResponse resp = {};
    // Start eCommerce backend service
    _ = test:startService("eCommerceService");

    // Test the findItems resource

    // Send 4 requests to service and get the response and test with expected behaviour
    resp, err = httpEndpoint.get("/items/TV", req);
    test:assertIntEquals(err.statusCode, 504, "eCommerce endpoint didnot respond with 504 server error signal");

    req = {};
    resp, err = httpEndpoint.get("/items/TV", req);
    test:assertIntEquals(err.statusCode, 504, "eCommerce endpoint didnot respond with 504 server error signal");

    req = {};
    resp, err = httpEndpoint.get("/items/TV", req);
    test:assertIntEquals(err.statusCode, 504, "eCommerce endpoint didnot respond with 504 server error signal");

    req = {};
    resp, err = httpEndpoint.get("/items/TV", req);
    println(resp.getJsonPayload());
    // Test the responses from the service with the original test data
    test:assertIntEquals(resp.statusCode, 200, "eCommerce endpoint didnot respond with 200 OK signal");

    json expectedJson = {"itemId":"TV", "brand":"ABC", "condition":"New", "itemLocation":"USA", "marketingPrice":"$100",
                            "seller":"XYZ"};
    // Assert the response message JSON payload
    test:assertStringEquals(resp.getJsonPayload().toString(), expectedJson.toString(),
                            "Item details of the eCommerce service did not match with expected results");


}
