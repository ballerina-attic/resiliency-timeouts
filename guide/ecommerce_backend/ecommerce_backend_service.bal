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
