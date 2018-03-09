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

package guide.product_search;

import ballerina.net.http;

@http:configuration {basePath:"/products"}
service<http> productSearchService {
    // Initialize the remote eCommerce endpoint
    endpoint<http:HttpClient> eCommerceEndpoint {
    // Pass the endpoint timeout and retry configurations while creating the http client
    // End point timeout should be in milliseconds
    // Retry configuration should have retry count and the time interval between two retires
        create http:HttpClient("http://localhost:9092/browse/",
                               {endpointTimeout:1000, retryConfig:{count:10, interval:100}});
    }

    @http:resourceConfig {
        methods:["GET"],
        path:"/search"
    }
    resource searchProducts (http:Connection httpConnection, http:InRequest request) {
        map queryParams = request.getQueryParams();
        var requestedItem, err = (string)queryParams.item;

        // Initialize the response message to send back to client
        http:OutResponse outResponse = {};

        // Send bad request message to the client if request don't contain search items
        if (err != null) {
            outResponse.setStringPayload("Error : Please provide 'item' in query parameter");
            // set the response code as 400 to indicate a bad request
            outResponse.statusCode = 400;
            _ = httpConnection.respond(outResponse);
            return;
        }
        // Initialize HTTP request and response to interact with eCommerce endpoint
        http:OutRequest outRequest = {};
        http:InResponse inResponse = {};
        // Call the busy eCommerce backed(configured with timeout resiliency) to get item details
        inResponse, _ = eCommerceEndpoint.get("/items/" + requestedItem, outRequest);
        // Send the item details back to the client
        outResponse.setJsonPayload(inResponse.getJsonPayload());
        _ = httpConnection.respond(outResponse);
    }
}
