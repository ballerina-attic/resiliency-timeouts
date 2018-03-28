# Retry and Timeout with HTTP

Timeout resilience pattern automatically cuts off the remote call if it fails to respond before the deadline. The retry resilience pattern allows repeated calls to remote services until it gets a response or until the retry count is reached. Timeouts are often seen together with retries. Under the philosophy of “best effort”, the service attempts to repeat failed remote calls that timed out. This helps to receive responses from the remote service even if it fails several times.

> This guide walks you through the process of incorporating resilience patterns like timeouts and retry to deal with potentially-busy remote backend services.

The following are the sections available in this guide.

- [What you'll build](#what-you-build)
- [Prerequisites](#pre-req)
- [Developing the service](#developing-service)
- [Testing](#testing)
- [Deployment](#deploying-the-scenario)
- [Observability](#observability)

## <a name="what-you-build"></a>  What you'll build

You’ll build a web service that calls a potentially busy remote backend (responds only to few requests). The service incorporates both retry and timeout resiliency patterns to call the remote backend. For better understanding, this is mapped with a real-world scenario of an eCommerce product search service. 

The eCommerce product search service uses a potentially busy remote eCommerce backend to obtain details about products. When an item is searched from the eCommerce product search service it calls the eCommerce backend to get the item details. The eCommerce backend is typically busy and might not respond to all the requests. The retry and timeout patterns will help to get the response from the busy eCommerce backend.


![alt text](/images/retry_and_timeout.png)


**Search item on eCommerce stores**: To search and find the details about items, you can use an HTTP GET message that contains item details as query parameters.

The eCommerce backend is not necessarily a Ballerina service and can theoretically be a third-party service that the eCommerve product search service calls to get things done. However, for the purposes of setting up this scenario and illustrating it in this guide, these third-party services are also written in Ballerina.

## <a name="pre-req"></a> Prerequisites
 
- JDK 1.8 or later
- [Ballerina Distribution](https://github.com/ballerina-lang/ballerina/blob/master/docs/quick-tour.md)
- A Text Editor or an IDE 

### Optional requirements
- Ballerina IDE plugins. ( [IntelliJ IDEA](https://plugins.jetbrains.com/plugin/9520-ballerina), [VSCode](https://marketplace.visualstudio.com/items?itemName=WSO2.Ballerina), [Atom](https://atom.io/packages/language-ballerina))
- [Docker](https://docs.docker.com/engine/installation/)

## <a name="developing-service"></a> Developing the RESTFul service with retry and timeout resiliency patterns

### Before you begin

#### Understand the package structure
Ballerina is a complete programming language that can have any custom project structure that you wish. Although the language allows you to have any package structure, use the following package structure for this project to follow this guide.

```
└── src
    ├── ecommerce_backend
    │   ├── ecommerce_backend_service.bal
    │   └── tests
    │       └── ecommerce_backend_service_test.bal
    └── product_search
        ├── product_serach_service.bal
        └── tests
            └── product_search_service_test.bal
    
```

The `product_search` is the service that handles the client requests. The product_search service incorporates the resiliency patterns like timeout and retry when calling potentially busy remote eCommerce backend.  

The `ecommerce_backend` is an independent web service that accepts product queries via an HTTP GET method and sends the item details back to the client. This service is used to mock a busy eCommerce backend.

### Implementation of the Ballerina services

#### product_serach_service.bal
The `product_serach_service.bal` is the service that incorporates the retry and timeout resiliency patterns. You need to pass the remote endpoint timeout and retry configurations while defining the HTTP client endpoint. 
The `endpoint` keyword in Ballerina refers to a connection with a remote service. The following code segment creates an HTTP client endpoint with the endpoint timeout of 1000 milliseconds and 10 retries with an interval of 100 milliseconds.
 
```ballerina
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
```

The argument `endpointTimeout` refers to the remote HTTP client timeout in milliseconds and `retry` refers to the retry configuration. There are two parameters in the retry configuration: `count` refers to the number of retires and the `interval` refers to the time interval between two consecutive retries. The `eCommerceEndpoint` is the reference to the HTTP endpoint of the eCommerce backend. Whenever you call that remote HTTP endpoint, it practices the retry and timeout resiliency patterns.

Refer the following code for the complete implementation of ecommerce product search service with retry and timeouts.
```ballerina
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
        var requestedItem = <string>queryParams.item;
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

```


#### ecommerce_backend_service.bal 
The eCommerce backend service is a simple web service that is used to mock a real world eCommerce web service. This service sends the following JSON message with the item details. 

```json
{"itemId":"item_id", "brand":"ABC", "condition":"New", "itemLocation":"USA", "marketingPrice":"$100", "seller":"XYZ"};
```
This mock eCommerce backend is designed only to respond once for every five requests. The 80% of calls to this eCommerce backend will not get any response.

Please find the implementation of the eCommerce backend service in [https://github.com/ballerina-guides/resiliency-timeouts/blob/master/guide/ecommerce_backend/ecommerce_backend_service.bal](https://github.com/ballerina-guides/resiliency-timeouts/blob/master/guide/ecommerce_backend/ecommerce_backend_service.bal).

## <a name="testing"></a> Testing 

### Try it out

1. Run both the product_search service and the ecommerce_backend service by entering the following commands in sperate terminals from the sample root directory.
    ```bash
    $  ballerina run src/ecommerce_backend/
   ```

   ```bash
   $ ballerina run src/product_search/
   ```

2. Invoke the product_search service by querying an item via the HTTP GET method. 
   ``` bash
    curl localhost:9090/products/search?item=TV
   ``` 
   The eCommerce product search service should finally respond after several internal timeouts and retires with the following JSON message.
   
   ```json
   {"itemId":"TV","brand":"ABC","condition":"New","itemLocation":"USA","marketingPrice":"$100","seller":"XYZ"}  
   ``` 
   
### <a name="unit-testing"></a> Writing unit tests 

In Ballerina, the unit test cases should be in the same package inside a `tests` folder. The naming convention should be as follows.
* Test files should contain _test.bal suffix.
* Test functions should contain test prefix.
  * e.g., testProductSearchService()

        
This guide contains unit test cases in the respective folders. The two test cases are written to test the `product_serach_service` and the `ecommerce_backend_service` service.

To run the unit tests, navigate to src folder inside the sample root directory and run the following command.
```bash
$ ballerina test 
```

## <a name="deploying-the-scenario"></a> Deployment

Once you are done with the development, you can deploy the service using any of the methods that are listed below. 

### <a name="deploying-on-locally"></a> Deploying locally
You can deploy the service that you developed above, in your local environment. You can use the Ballerina executable archive (.balx) archive that you created above and run it in your local environment as follows. 

**Building** 
Navigate to `SAMPLE_ROOT/src` and run the following commands
   ```bash
    $ ballerina build product_search/

    $ ballerina build ecommerce_backend/

   ```

**Running**
   ```bash
    $ ballerina run product_search.balx

    $ ballerina run ecommerce_backend.balx 

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
