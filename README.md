[![Build Status](https://travis-ci.org/rosensilva/resiliency-timeouts.svg?branch=master)](https://travis-ci.org/rosensilva/resiliency-timeouts)
# Endpoint Resiliency

Timeout resilience pattern automatically cuts off the remote call if it fails to respond before the deadline. The retry resilience pattern allows repeated calls to remote services until it gets a response or until the retry count is reached. Timeouts are often seen together with retries. Under the philosophy of “best effort”, the service attempts to repeat failed remote calls that timed out. This helps to receive responses from the remote service even if it fails several times.

> This guide walks you through the process of incorporating resilience patterns like timeouts and retry to deal with potentially-busy remote backend services.

The following are the sections available in this guide.

- [What you'll build](#what-youll-build)
- [Prerequisites](#prerequisites)
- [Developing the service](#developing-the-restful-service-with-retry-and-timeout-resiliency-patterns)
- [Testing](#testing)
- [Deployment](#deployment)

## What you'll build

You’ll build a web service that calls a potentially busy remote backend (responds only to few requests). The service incorporates both retry and timeout resiliency patterns to call the remote backend. For better understanding, this is mapped with a real-world scenario of an eCommerce product search service. 

The eCommerce product search service uses a potentially busy remote eCommerce backend to obtain details about products. When an item is searched from the eCommerce product search service it calls the eCommerce backend to get the item details. The eCommerce backend is typically busy and might not respond to all the requests. The retry and timeout patterns will help to get the response from the busy eCommerce backend.


![alt text](/images/resiliency-timeouts.svg)


**Search item on eCommerce stores**: To search and find the details about items, you can use an HTTP GET message that contains item details as query parameters.

The eCommerce backend is not necessarily a Ballerina service and can theoretically be a third-party service that the eCommerve product search service calls to get things done. However, for the purposes of setting up this scenario and illustrating it in this guide, these third-party services are also written in Ballerina.

## Prerequisites
 
- JDK 1.8 or later
- [Ballerina Distribution](https://github.com/ballerina-lang/ballerina/blob/master/docs/quick-tour.md)
- A Text Editor or an IDE 

### Optional requirements
- Ballerina IDE plugins. ( [IntelliJ IDEA](https://plugins.jetbrains.com/plugin/9520-ballerina), [VSCode](https://marketplace.visualstudio.com/items?itemName=WSO2.Ballerina), [Atom](https://atom.io/packages/language-ballerina))
- [Docker](https://docs.docker.com/engine/installation/)

## Developing the RESTFul service with retry and timeout resiliency patterns

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

#### product_search_service.bal
The `product_search_service.bal` is the service that incorporates the retry and timeout resiliency patterns. You need to pass the remote endpoint timeout and retry configurations while defining the HTTP client endpoint. 
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
    // Pass the endpoint timeout and retry configurations while creating the http endpoint
    // Retry configuration can have retry count and the time interval between two retires
    retry:{count:10, interval:100}
};


@http:ServiceConfig {basePath:"/products"}
service<http:Service> productSearchService bind productSearchEP {

// ecommerce product search resource
    @http:ResourceConfig {
        methods:["GET"],
        path:"/search"
    }
    searchProducts(endpoint httpConnection, http:Request request) {
        map queryParams = request.getQueryParams();
        var requestedItem = <string>queryParams.item;
        // Initialize HTTP request and response to interact with eCommerce endpoint
        http:Request outRequest = {};
        http:Response inResponse = {};
        if (requestedItem != null) {
            // Call the busy eCommerce backed(with timeout resiliency) to get item details
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
{"itemId":"item_id", "brand":"ABC", "condition":"New","itemLocation":"USA",
"marketingPrice":"$100", "seller":"XYZ"};
```
This mock eCommerce backend is designed only to respond once for every five requests. The 80% of calls to this eCommerce backend will not get any response.

Please find the implementation of the eCommerce backend service in [https://github.com/ballerina-guides/resiliency-timeouts/blob/master/guide/ecommerce_backend/ecommerce_backend_service.bal](https://github.com/ballerina-guides/resiliency-timeouts/blob/master/guide/ecommerce_backend/ecommerce_backend_service.bal).

## Testing 

### Try it out

- Run both the product_search service and the ecommerce_backend service by entering the following commands in sperate terminals from the sample root directory.
```bash
    $  ballerina run src/ecommerce_backend/
```

```bash
   $ ballerina run src/product_search/
```

- Invoke the product_search service by querying an item via the HTTP GET method. 
``` bash
    curl localhost:9090/products/search?item=TV
``` 
   The eCommerce product search service should finally respond after several internal timeouts and retires with the following JSON message.
   
```json
   {"itemId":"TV","brand":"ABC","condition":"New", "itemLocation":"USA",
   "marketingPrice":"$100","seller":"XYZ"}  
``` 
   
### Writing unit tests 

In Ballerina, the unit test cases should be in the same package inside a `tests` folder. The naming convention should be as follows.
* Test files should contain _test.bal suffix.
* Test functions should contain test prefix.
  * e.g., testProductSearchService()

        
This guide contains unit test cases in the respective folders. The two test cases are written to test the `product_serach_service` and the `ecommerce_backend_service` service.

To run the unit tests, navigate to src folder inside the sample root directory and run the following command.
```bash
$ ballerina test 
```

## Deployment

Once you are done with the development, you can deploy the service using any of the methods that are listed below. 

### Deploying locally
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
   
### Deploying on Docker

You can run the services that we developed above as a docker container. As Ballerina platform offers native support for running ballerina programs on containers, you just need to put the corresponding docker annotations on your service code. 
Let's see how we can deploy the product_search_service we developed above on docker. 

- In our product_search_service, we need to import  `` import ballerinax/docker; `` and use the annotation `` @docker:Config `` as shown below to enable docker image generation during the build time. 

##### product_search_service.bal
```ballerina
package product_search;

import ballerina/http;
import ballerinax/docker;

@docker:Config {
    registry:"ballerina.guides.io",
    name:"product_search_service",
    tag:"v1.0"
}

endpoint http:ServiceEndpoint productSearchEP {
    port:9090
};

// http:ClientEndpoint definition for the remote eCommerce endpoint

@http:ServiceConfig {basePath:"/products"}
service<http:Service> productSearchService bind productSearchEP {
``` 

- Now you can build a Ballerina executable archive (.balx) of the service that we developed above, using the following command. It points to the service file that we developed above and it will create an executable binary out of that. 
This will also create the corresponding docker image using the docker annotations that you have configured above. Navigate to the `<SAMPLE_ROOT>/src/` folder and run the following command.  
  
```
  $ballerina build product_search
  
  Run following command to start docker container: 
  docker run -d -p 9090:9090 ballerina.guides.io/product_search_service:v1.0
```
- Once you successfully build the docker image, you can run it with the `` docker run`` command that is shown in the previous step.  

```   
    docker run -d -p 9090:9090 ballerina.guides.io/product_search_service:v1.0
```

   Here we run the docker image with flag`` -p <host_port>:<container_port>`` so that we use the host port 9090 and the container port 9090. Therefore you can access the service through the host port. 

- Verify docker container is running with the use of `` $ docker ps``. The status of the docker container should be shown as 'Up'. 
- You can access the service using the same curl commands that we've used above. 
 
```
   curl -X GET http://localhost:9090/products/search?item=TV
 ```


### Deploying on Kubernetes

- You can run the services that we developed above, on Kubernetes. The Ballerina language offers native support for running a ballerina programs on Kubernetes, 
with the use of Kubernetes annotations that you can include as part of your service code. Also, it will take care of the creation of the docker images. 
So you don't need to explicitly create docker images prior to deploying it on Kubernetes.   
Let's see how we can deploy the product_search_service we developed above on kubernetes.

- We need to import `` import ballerinax/kubernetes; `` and use `` @kubernetes `` annotations as shown below to enable kubernetes deployment for the service we developed above. 

##### product_search_service.bal

```ballerina
package product_search;

import ballerina/http;
import ballerinax/kubernetes;

@kubernetes:Ingress {
    hostname:"ballerina.guides.io",
    name:"ballerina-guides-product-search-service",
    path:"/"
}

@kubernetes:Service {
    serviceType:"NodePort",
    name:"ballerina-guides-product-search-service"
}

@kubernetes:Deployment {
    image:"ballerina.guides.io/product_search_service:v1.0",
    name:"ballerina-guides-product-search-service"
}

endpoint http:ServiceEndpoint productSearchEP {
    port:9090
};

// http:ClientEndpoint definition for the remote eCommerce endpoint

@http:ServiceConfig {basePath:"/products"}
service<http:Service> productSearchService bind productSearchEP {  
``` 

- Here we have used ``  @kubernetes:Deployment `` to specify the docker image name which will be created as part of building this service. 
- We have also specified `` @kubernetes:Service {} `` so that it will create a Kubernetes service which will expose the Ballerina service that is running on a Pod.  
- In addition we have used `` @kubernetes:Ingress `` which is the external interface to access your service (with path `` /`` and host name ``ballerina.guides.io``)

- Now you can build a Ballerina executable archive (.balx) of the service that we developed above, using the following command. It points to the service file that we developed above and it will create an executable binary out of that. 
This will also create the corresponding docker image and the Kubernetes artifacts using the Kubernetes annotations that you have configured above.
  
```
  $ballerina build product_search
  
  Run following command to deploy kubernetes artifacts:  
  kubectl apply -f ./target/product_search/kubernetes
```

- You can verify that the docker image that we specified in `` @kubernetes:Deployment `` is created, by using `` docker ps images ``. 
- Also the Kubernetes artifacts related our service, will be generated in `` ./target/product_search/kubernetes``. 
- Now you can create the Kubernetes deployment using:

```
 $ kubectl apply -f ./target/product_search/kubernetes 
   deployment.extensions "ballerina-guides-product-search-service" created
   ingress.extensions "ballerina-guides-product-search-service" created
   service "ballerina-guides-product-search-service" created
```

- You can verify Kubernetes deployment, service and ingress are running properly, by using following Kubernetes commands. 
```
$kubectl get service
$kubectl get deploy
$kubectl get pods
$kubectl get ingress
```

- If everything is successfully deployed, you can invoke the service either via Node port or ingress. 

Node Port:
 
```
 curl -X GET http://<Minikube_host_IP>:<Node_Port>/products/search?item=TV
```
Ingress:

Add `/etc/hosts` entry to match hostname. 
``` 
127.0.0.1 ballerina.guides.io
```

Access the service 

``` 
 curl -X GET http://ballerina.guides.io/products/search?item=TV
```
