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