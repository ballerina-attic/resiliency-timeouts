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
import ballerina/log;
//import ballerinax/docker;
//import ballerinax/kubernetes;

//@docker:Config {
//    registry:"ballerina.guides.io",
//    name:"product_search_service",
//    tag:"v1.0"
//}
//
//@docker:Expose{}

//@kubernetes:Ingress {
//    hostname:"ballerina.guides.io",
//    name:"ballerina-guides-product-search-service",
//    path:"/"
//}
//
//@kubernetes:Service {
//    serviceType:"NodePort",
//    name:"ballerina-guides-product-search-service"
//}
//
//@kubernetes:Deployment {
//    image:"ballerina.guides.io/product_search_service:v1.0",
//    name:"ballerina-guides-product-search-service"
//}

// Create the endpoint for the ecommerce product search service
listener http:Listener productSearchEP = new(9090);

// Initialize the remote eCommerce endpoint
http:Client eCommerceEndpoint = new(
    // URI to the ecommerce backend
    "http://localhost:9092/browse",
    {
        // End point timeout should be in milliseconds
        timeoutInMillis: 1000,
        // Pass the endpoint timeout and retry configurations while creating the http client.
        // Retry configuration should have retry count and the time interval between two retires
        retryConfig: {
            intervalInMillis: 100,
            count: 10,
            backOffFactor: 0.5
        }
    });

@http:ServiceConfig { basePath: "/products" }
service productSearchService on productSearchEP {

    // Ecommerce product search resource
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/search"
    }
    resource function searchProducts (http:Caller httpConnection, http:Request request) returns error? {
        var requestedItem = request.getQueryParamValue("item");
        // Initialize HTTP request and response to interact with eCommerce endpoint
        http:Request outRequest;
        http:Response inResponse = new;
        // Prepare the url path with requested item
        // Use `untained` keyword since the URL paths are @Sensitive
        string urlPath = "/items/" + <@untainted> requestedItem.toString();
        if (requestedItem is string) {
            // Call the busy eCommerce backed(configured with timeout resiliency) to get item details
            inResponse = check eCommerceEndpoint->get(urlPath);
            // Send the item details back to the client
            var result = httpConnection->respond(inResponse);
            if (result is error) {
                log:printError(result.reason(), err = result);
            }
        }
        else {
            inResponse.setTextPayload("Please enter item as query parameter");
            inResponse.statusCode = 400;
            var result = httpConnection->respond(inResponse);
            if (result is error) {
                log:printError(result.reason(), err = result);
            }
        }
    }
}
