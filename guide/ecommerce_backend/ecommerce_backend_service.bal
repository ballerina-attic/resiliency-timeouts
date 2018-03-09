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

int count = 0;

@http:configuration {basePath:"/browse", port:9092}
service<http> eCommerceService {

    @http:resourceConfig {
        methods:["GET"],
        path:"/items/{item_id}"
    }
    resource findItems (http:Connection httpConnection, http:InRequest request, string item_id) {
        count = count + 1;
        // Mock the busy service by only responding to one request out of five incoming requests
        if (count % 5 != 4) {
            sleep(10000);
        }
        // Initialize sample item details about the item
        json itemDetails = {
                               "itemId":item_id,
                               "brand":"ABC",
                               "condition":"New",
                               "itemLocation":"USA",
                               "marketingPrice":"$100",
                               "seller":"XYZ"
                           };

        // Send the response back with the item details
        http:OutResponse response = {};
        response.setJsonPayload(itemDetails);
        _ = httpConnection.respond(response);
    }
}
