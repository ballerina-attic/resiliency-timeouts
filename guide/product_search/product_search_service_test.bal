
// Copyright (c) 2017 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

package guide.product_search;

import ballerina.net.http;
import ballerina.test;

function testProductSearchService () {
    endpoint<http:HttpClient> httpEndpoint {
        create http:HttpClient("http://localhost:9090/products", {endpointTimeout:10000});
    }

    http:HttpConnectorError err;
    // Initialize the empty http request and response
    http:OutRequest req = {};
    http:InResponse resp = {};
    // Start eCommerce backend service
    _ = test:startService("eCommerceEndpoint");

    // Test the searchProducts resource
    // Send a request to service
    resp, err = httpEndpoint.get("/search?item=TV", req);
    test:assertIntEquals(resp.statusCode, 200, "product search service didnot respond with 200 OK signal");

    json expectedJson = {"itemId":"TV", "brand":"ABC", "condition":"New", "itemLocation":"USA", "marketingPrice":"$100",
                            "seller":"XYZ"};
    // Assert the response message JSON payload
    test:assertStringEquals(resp.getJsonPayload().toString(), expectedJson.toString(),
                            "Item details of the eCommerce service did not match with expected results");

}
