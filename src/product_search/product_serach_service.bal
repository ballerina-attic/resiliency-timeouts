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

package product_search;

import ballerina/net.http;

// Create the endpoint for the ecommerce product search service
endpoint http:ServiceEndpoint productSearchEP {
    port:9090
};

// Initialize the remote eCommerce endpoint
endpoint http:ClientEndpoint eCommerceEndpoint {
// URI to the ecommerce backend
    targets:[
            {
                uri:"http://localhost:9092/browse"
            }
            ],
// End point timeout should be in milliseconds
    endpointTimeout:1000,
// Pass the endpoint timeout and retry configurations while creating the http client endpoint
// Retry configuration should have retry count and the time interval between two retires
    retry:{count:10, interval:100}
};


@http:ServiceConfig {basePath:"/products"}
service<http:Service> productSearchService bind productSearchEP {

    // ecommerce product search resource
    @http:ResourceConfig {
        methods:["GET"],
        path:"/search"
    }
    searchProducts (endpoint httpConnection, http:Request request) {
        map queryParams = request.getQueryParams();
        var itemString = <string>queryParams.item;
        match itemString {
            string requestedItem => {
            // Initialize HTTP request and response to interact with eCommerce endpoint
                http:Request outRequest = {};
                http:Response inResponse = {};
                if (requestedItem != null) {
                    // Call the busy eCommerce backed(configured with timeout resiliency) to get item details
                    inResponse =? eCommerceEndpoint -> get("/items/" + requestedItem, outRequest);
                    // Send the item details back to the client
                    _ = httpConnection -> forward(inResponse);
                }
                else {
                    inResponse.setStringPayload("Please enter item as query parameter");
                    inResponse.statusCode = 400;
                    _ = httpConnection -> respond(inResponse);
                }
            }
        }
    }
}
