# HTTP Calls with Retry and Timeouts
This guide walks you through the process of incorporating resilience patterns like timeouts and retry to deal with potentially-busy remote backend services. Timeout resilience pattern will automatically cut off the remote call if it fails to respond before the deadline. The retry resilience pattern allows calls to the remote backed services repeatedly until it gets a response or until retry count is reached. Timeouts are often seen together with retries. Under the philosophy
of “best effort,” the service attempts to repeat a failed remote calls
that timed out. This helps to receive responses from remote service even it fails several times.

## <a name="what-you-build"></a>  What you'll build

You’ll build a web service that calls potentially busy remote backend(response only to few requests). The service incorporates both retry and timeout resiliency patterns to call the remote backend. For better understanding, we will map this with a real-world scenario of an eCommerce product search service. The eCommerce product search service uses potentially-busy remote eCommerce backend to obtain details about products. When some item is searched from the eCommerce product search service it will call to the eCommerce backend to get the details about the item. The eCommerce backend is typically busy and might not respond to all the requests. The retry and timeout patterns will help to get the response from the busy eCommerce backend.


![alt text](https://github.com/rosensilva/ballerina-samples/blob/master/resiliency-timeouts/images/retry_and_timeout_scenario.png)


- **Search item on eCommerce stores **: To search and find the details about items, you can use the HTTP GET message that contains item details as query parameters.

## <a name="pre-req"></a> Prerequisites
 
- JDK 1.8 or later
- Ballerina Distribution (Install Instructions:  https://ballerinalang.org/docs/quick-tour/quick-tour/#install-ballerina)
- A Text Editor or an IDE 

Optional Requirements
- Docker (Refer: https://docs.docker.com/engine/installation/)
- Ballerina IDE plugins. ( Intellij IDEA, VSCode, Atom)
- Testerina (Refer: https://github.com/ballerinalang/testerina)
- Container-support (Refer: https://github.com/ballerinalang/container-support)
- Docerina (Refer: https://github.com/ballerinalang/docerina)

## <a name="developing-service"></a> Develop the RESTFul service with retry and timeout resiliency patterns

### Before you begin

##### Understand the package structure
Ballerina is a complete programming language that can have any custom project structure as you wish. Although language allows you to have any package structure, we'll stick with the following package structure for this project.

```
└── guide
    ├── product_search
    │   ├── product_search_service_test.bal
    │   └── product_serach_service.bal
    └── ecommerce_backend
        ├── ecommerce_backend_service.bal
        └── ecommerce_backend_service_test.bal

```

The `product_search` is the service that handles the client requests. product_search incorporate resiliency pattern like timeouts and retry when calling potentially-busy remote eCommerce backend.  

The `ecommerce_backend` is an independent web service that accepts product queries via HTTP GET method and sends the item details back to the client. This service is used to mock a busy eCommerce backend

### Develop the Ballerina services

#### product_serach_service.bal
The `product_serach_service.bal` is the service which incorporates the retry and timeout resiliency patterns. You need to pass the remote endpoint timeout and retry configurations while defining the HTTP client endpoint. 

```ballerina
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
```
 The `endpoint` keyword in ballerina refers to a connection with remote service. The following code segment will create an HTTP client with the endPoint timeout of 1000 milliseconds and 10 retries with an interval of 100 milliseconds.
```ballerina
create http:HttpClient("http://localhost:9092/browse/",
{endpointTimeout:1000, retryConfig:{count:10, interval:100}});
```

The argument `endpointTimeout` refers to the remote HTTP client timeout in milliseconds and `retryConfig` refers to retry configuration. There are two parameters in the retry configuration, `count` refers to the number of retires and the `interval` refers to the time interval between two consecutive retries. The `eCommerceEndpoint` is the reference to the HTTP endpoint of eCommerce backend. Whenever you call that remote HTTP endpoint it practices the retry and timeout resiliency patterns.


#### ecommerce_backend_service.bal 
The eCommerce backend service is a simple web service which is used to mock realworld eCommerce web service. This service 
will send the following JSON message with the item details. 
```json
{"itemId":"item_id", "brand":"ABC", "condition":"New", "itemLocation":"USA", "marketingPrice":"$100", "seller":"XYZ"};
```
This mock eCommerce backend is designed only to respond once for every five requests. The 80% of calls to this eCommerce backend will not get any response.

Please find the implementation of the eCommerce backend service in `ballerina-guides/resiliency-timeouts/guides/ecommerce_backend/ecommerce_backend_service.bal`


## <a name="testing"></a> Testing 

### Try it out

1. Run both product_search service and the ecommerce_backend service by entering the following commands in sperate terminals
    ```bash
    <SAMPLE_ROOT_DIRECTORY>$  ballerina run guide/ecommerce_backend/
   ```

   ```bash
   <SAMPLE_ROOT_DIRECTORY>$ ballerina run guide/product_search/
   ```

2. Then invoke the product_search by querying an item via HTTP GET method. 
   ``` bash
    curl localhost:9090/products/search?item=TV
   ``` 
   The eCommerce product search service should finally respond after several internal timeouts and retires with the following json message, 
   
   ```json
   {"itemId":"TV","brand":"ABC","condition":"New","itemLocation":"USA","marketingPrice":"$100","seller":"XYZ"}  
   ``` 
   
### <a name="unit-testing"></a> Writing Unit Tests 

In ballerina, the unit test cases should be in the same package and the naming convention should be as follows,
* Test files should contain _test.bal suffix.
* Test functions should contain test prefix.
  * e.g.: testProductSearchService()

        
This guide contains unit test cases in the respective folders. The two test cases are written to test the `product_serach_service` and the `ecommerce_backend_service` service.
To run the unit tests, go to the sample root directory and run the following command
```bash
<SAMPLE_ROOT_DIRECTORY>$ ballerina test guide/product_search/
```

```bash
<SAMPLE_ROOT_DIRECTORY>$ ballerina test guide/ecommerce_backend/
```

## <a name="deploying-the-scenario"></a> Deployment

Once you are done with the development, you can deploy the service using any of the methods that we listed below. 

### <a name="deploying-on-locally"></a> Deploying Locally
You can deploy the RESTful service that you developed above, in your local environment. You can use the Ballerina executable archive (.balx) archive that we created above and run it in your local environment as follows. 

```
<SAMPLE_ROOT_DIRECTORY>$  ballerina run product_search.balx 
```

```
<SAMPLE_ROOT_DIRECTORY>$  ballerina run ecommerce_backend.balx 
```

### <a name="deploying-on-docker"></a> Deploying on Docker
(Work in progress) 

### <a name="deploying-on-k8s"></a> Deploying on Kubernetes
(Work in progress) 


## <a name="observability"></a> Observability 

### <a name="logging"></a> Logging
(Work in progress) 

### <a name="metrics"></a> Metrics
(Work in progress) 


### <a name="tracing"></a> Tracing 
(Work in progress) 
