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
//    registry: "ballerina.guides.io",
//    name: "product_search_service",
//    tag: "v1.0"
//}
//
//@docker:Expose{}

//@kubernetes:Ingress {
//    hostname: "ballerina.guides.io",
//    name: "ballerina-guides-product-search-service",
//    path: "/"
//}
//
//@kubernetes:Service {
//    serviceType: "NodePort",
//    name: "ballerina-guides-product-search-service"
//}
//
//@kubernetes:Deployment {
//    image: "ballerina.guides.io/product_search_service:v1.0",
//    name: "ballerina-guides-product-search-service"
//}

// Create the endpoint for the ecommerce product search service
listener http:Listener productSearchEP = new(9090);
// Initialize the remote eCommerce endpoint
http:Client eCommerceEndpoint = new("http://localhost:9092/browse", config = {
        // End point timeout should be in milliseconds
        timeoutMillis: 1000,
        // Pass the endpoint timeout and retry configurations while creating the http client.
        // Retry configuration should have retry count and the time interval between two retires
        retryConfig: {
            interval: 100,
            count: 10,
            backOffFactor: 0.5
        }
    }
);

@http:ServiceConfig { basePath: "/products" }
service productSearchService on productSearchEP {

    // ecommerce product search resource
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/search"
    }
    resource function searchProducts(http:Caller caller, http:Request request) {
        map<string> queryParams = request.getQueryParams();
        var requestedItem = queryParams["item"];
        // Initialize HTTP request to interact with eCommerce endpoint
        http:Response inResponse = new;
        if (requestedItem is string) {
            // Prepare the url path with requested item
            // Use `untained` keyword since the URL paths are @Sensitive
            string urlPath = "/items/" + untaint requestedItem;
            // Call the busy eCommerce backend(configured with timeout resiliency) to get item details
            var endpointResponse = eCommerceEndpoint->get(urlPath);
            if (endpointResponse is http:Response) {
                // Send the item details back to the client
                var result = caller->respond(endpointResponse);
                handleError(result);
            } else {
                log:printError(endpointResponse.reason(), err = endpointResponse);
                string errorMsg = "Backend service unavailable";
                inResponse.setTextPayload(errorMsg);
                inResponse.statusCode = 400;
                var result = caller->respond(inResponse);
                handleError(result);
            }
        } else {
            inResponse.setTextPayload("Please enter item as query parameter");
            inResponse.statusCode = 400;
            var result = caller->respond(inResponse);
            handleError(result);
        }
    }
}

function handleError(error? result) {
    if (result is error) {
        log:printError(result.reason(), err = result);
    }
}
