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