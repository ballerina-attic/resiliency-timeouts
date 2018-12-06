[![Build Status](https://travis-ci.org/ballerina-guides/resiliency-timeouts.svg?branch=master)](https://travis-ci.org/ballerina-guides/resiliency-timeouts)

# Endpoint Resiliency

Timeout resilience pattern automatically cuts off the remote call if it fails to respond before the deadline. The retry resilience pattern allows repeated calls to remote services until it gets a response or until the retry count is reached. Timeouts are often seen together with retries. Under the philosophy of “best effort”, the service attempts to repeat failed remote calls that timed out. This helps to receive responses from the remote service even if it fails several times.

> This guide walks you through the process of incorporating resilience patterns like timeouts and retry to deal with potentially-busy remote backend services.

The following are the sections available in this guide.

- [What you'll build](#what-youll-build)
- [Prerequisites](#prerequisites)
- [Implementation](#implementation)
- [Testing](#testing)
- [Deployment](#deployment)
- [Observability](#observability)

## What you'll build

You’ll build a web service that calls a potentially busy remote backend (responds only to few requests). The service incorporates both retry and timeout resiliency patterns to call the remote backend. For better understanding, this is mapped with a real-world scenario of an eCommerce product search service. 

The eCommerce product search service uses a potentially busy remote eCommerce backend to obtain details about products. When an item is searched from the eCommerce product search service, it calls the eCommerce backend to get the item details. The eCommerce backend is typically busy and might not respond to all the requests. The retry and timeout patterns will help to get the response from the busy eCommerce backend.


![alt text](/images/resiliency-timeouts.svg)


**Search item on eCommerce stores**: To search and find the details about items, you can use an HTTP GET message that contains item details as query parameters.

The eCommerce backend is not necessarily a Ballerina service and can theoretically be a third-party service that the eCommerce product search service calls to get things done. However, for the purposes of setting up this scenario and illustrating it in this guide, this third-party service is also written in Ballerina.

## Prerequisites
 
- [Ballerina Distribution](https://ballerina.io/learn/getting-started/)
- A Text Editor or an IDE 

### Optional requirements
- Ballerina IDE plugins ([IntelliJ IDEA](https://plugins.jetbrains.com/plugin/9520-ballerina), [VSCode](https://marketplace.visualstudio.com/items?itemName=WSO2.Ballerina), [Atom](https://atom.io/packages/language-ballerina))
- [Docker](https://docs.docker.com/engine/installation/)
- [Kubernetes](https://kubernetes.io/docs/setup/)

## Implementation

> If you want to skip the basics, you can download the git repo and directly move to the "Testing" section by skipping  "Implementation" section.

### Create the project structure

Ballerina is a complete programming language that can have any custom project structure that you wish. Although the language allows you to have any package structure, use the following package structure for this project to follow this guide.
```
└── resiliency-timeouts
    └── guide
        ├── ecommerce_backend
        │   ├── ecommerce_backend_service.bal
        │   └── tests
        │       └── ecommerce_backend_service_test.bal
        └── product_search
            ├── product_search_service.bal
            └── tests
                └── product_search_service_test.bal
```

- Create the above directories in your local machine and also create empty `.bal` files.

- Then open the terminal and navigate to `resiliency-timeouts/guide` and run Ballerina project initializing toolkit.
```bash
   $ ballerina init
```

The `product_search` is the service that handles the client requests. The product_search service incorporates the resiliency patterns like timeout and retry when calling potentially busy remote eCommerce backend.  

The `ecommerce_backend` is an independent web service that accepts product queries via an HTTP GET method and sends the item details back to the client. This service is used to mock a busy eCommerce backend.

### Developing the RESTFul service with retry and timeout resiliency patterns

#### product_search_service.bal
The `product_search_service.bal` is the service that incorporates the retry and timeout resiliency patterns. You need to pass the remote endpoint timeout and retry configurations while defining the HTTP client. 
The following code segment creates an HTTP client with `http://localhost:9092/browse` URL and with the endpoint timeout of 1000 milliseconds, 0.5  back off factor and 10 retries with an interval of 100 milliseconds.
 
```ballerina
http:Client eCommerceEndpoint = new("http://localhost:9092/browse", config = {
        // End point timeout should be in milliseconds
        timeoutMillis: 1000,
        // Pass the timeout and retry configurations while creating the HTTP client
        // Retry configuration should have retry count,
        // time interval between two retires and back off factor
        retryConfig: {
            interval: 100,
            count: 10,
            backOffFactor: 0.5
        }
    }
);
```

The `eCommerceEndpoint` is the reference to the HTTP endpoint of the eCommerce backend. Whenever you call that remote HTTP endpoint, it practices the retry and timeout resiliency patterns.

Refer the following code for the complete implementation of ecommerce product search service with retry and timeouts.
```ballerina
import ballerina/http;
import ballerina/log;

// Create the HTTP listener for the ecommerce product search service
listener http:Listener productSearchEP = new(9090);

// Initialize the remote eCommerce HTTP Client
http:Client eCommerceEndpoint = new("http://localhost:9092/browse", config = {
        // End point timeout should be in milliseconds
        timeoutMillis: 1000,
        // Pass the timeout and retry configurations while creating the HTTP client.
        // Retry configuration should have retry count,
        // time interval between two retires and back off factor
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
            // Call the busy eCommerce backend(configured with timeout resiliency)
            // to get item details
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
```


#### ecommerce_backend_service.bal 
The eCommerce backend service is a simple web service that is used to mock a real world eCommerce web service. This service sends the following JSON message with the item details. 

```json
{"itemId":"TV", "brand":"ABC", "condition":"New","itemLocation":"USA",
"marketingPrice":"$100", "seller":"XYZ"};
```
This mock eCommerce backend is designed only to respond once for every five requests. The 80% of calls to this eCommerce backend will not get any response.

Please find the implementation of the eCommerce backend service [ecommerce_backend_service.bal](guide/ecommerce_backend/ecommerce_backend_service.bal).

## Testing 

### Try it out

- Run both the product_search service and the ecommerce_backend service by entering the following commands in separate terminals from the sample root directory.
```bash
   $ ballerina run ecommerce_backend/
```

```bash
   $ ballerina run product_search/
```

- Invoke the product_search service by querying an item via the HTTP GET method. 
``` bash
    $ curl localhost:9090/products/search?item=TV
``` 
   The eCommerce product search service should finally respond after several internal timeouts and retires with the following JSON message.
   
```json
   {"itemId":"TV","brand":"ABC","condition":"New", "itemLocation":"USA",
   "marketingPrice":"$100","seller":"XYZ"}  
``` 
Few error messages like below getting print in the ecommerce_backend service log file.
The reason is few delayed responses try to send to product_search but resulting an error due to the connection closure.         
```bash
   $ 2018-12-05 16:27:38,098 ERROR [ballerina/log] - {ballerina/http}HTTPError : {ballerina/http}HTTPError {message:"Connection between remote client and host is closed"} 
   $ 2018-12-05 16:27:39,120 ERROR [ballerina/log] - {ballerina/http}HTTPError : {ballerina/http}HTTPError {message:"Connection between remote client and host is closed"} 
   $ 2018-12-05 16:27:40,182 ERROR [ballerina/log] - {ballerina/http}HTTPError : {ballerina/http}HTTPError {message:"Connection between remote client and host is closed"}
```
   
### Writing unit tests 

In Ballerina, the unit test cases should be in the same package inside a folder named as 'tests'.  When writing the test functions the below convention should be followed.
- Test functions should be annotated with `@test:Config`. See the below example.
```ballerina
   @test:Config
   function testProductSearchService() {
```
  
This guide contains unit test cases for each method available in the 'product_search' implemented above. 

To run the unit tests, open your terminal and navigate to `resiliency-timeouts/guide`, and run the following command.
```bash
   $ ballerina test
```
To check the implementation of the test file, refer tests folders in the [repository](https://github.com/ballerina-guides/resiliency-timeouts).

## Deployment

Once you are done with the development, you can deploy the service using any of the methods that are listed below. 

### Deploying locally
- As the first step, you can build a Ballerina executable archive (.balx) of the services that we developed above. Navigate to `resiliency-timeouts/guide` and run the following commands. 
```bash
   $ ballerina build ecommerce_backend
```
```bash
   $ ballerina build product_search
```

- Once the balx files are created inside the target folder, you can run the services with the following commands. 
```bash
   $ ballerina run target/ecommerce_backend.balx
```
```bash
   $ ballerina run target/product_search.balx
```

- The successful execution of the service will show us the following output. 
```
   Initiating service(s) in 'target/ecommerce_backend.balx'
   [ballerina/http] started HTTP/WS endpoint 0.0.0.0:9092
```
```
   Initiating service(s) in 'target/product_search.balx'
   [ballerina/http] started HTTP/WS endpoint 0.0.0.0:9090
```

### Deploying on Docker

You can run the services that we developed above as a Docker container. As Ballerina platform offers native support for running ballerina programs on containers, you just need to put the corresponding Docker annotations on your service code.
Let's see how we can deploy the product_search_service we developed above on Docker.

- In our product_search_service, we need to import  `` import ballerinax/docker; `` and use the annotation `` @docker:Config `` as shown below to enable Docker image generation during the build time.

##### product_search_service.bal
```ballerina
package product_search;

import ballerina/http;
import ballerinax/docker;

@docker:Config {
    registry: "ballerina.guides.io",
    name: "product_search_service",
    tag: "v1.0"
}

@docker:Expose{}
listener http:Listener productSearchEP = new(9090);

// Initialize the remote eCommerce endpoint

@http:ServiceConfig {basePath: "/products"}
service productSearchService on productSearchEP {
``` 

- Now you can build a Ballerina executable archive (.balx) of the service that we developed above, using the following command. It points to the service file that we developed above and it will create an executable binary out of that. 
This will also create the corresponding Docker image using the Docker annotations that you have configured above. Navigate to the `<SAMPLE_ROOT>/src/` folder and run the following command.
  
```bash
   $ ballerina build product_search
  
   Run following command to start docker container: 
   $ docker run -d -p 9090:9090 ballerina.guides.io/product_search_service:v1.0
```
- Once you successfully build the Docker image, you can run it with the `` docker run`` command that is shown in the previous step.

```bash 
   $ docker run -d -p 9090:9090 ballerina.guides.io/product_search_service:v1.0
```

   Here we run the Docker image with flag`` -p <host_port>:<container_port>`` so that we use the host port 9090 and the container port 9090. Therefore you can access the service through the host port.

- Verify Docker container is running with the use of `` $ docker ps``. The status of the Docker container should be shown as 'Up'.
- You can access the service using the same curl commands that we've used above. 
 
```bash
   $ curl -X GET http://localhost:9090/products/search?item=TV
```


### Deploying on Kubernetes

- You can run the services that we developed above, on Kubernetes. The Ballerina language offers native support for running a ballerina programs on Kubernetes, 
with the use of Kubernetes annotations that you can include as part of your service code. Also, it will take care of the creation of the Docker images.
So you don't need to explicitly create Docker images prior to deploying it on Kubernetes.
Let's see how we can deploy the product_search_service we developed above on kubernetes.

- We need to import `` import ballerinax/kubernetes; `` and use `` @kubernetes `` annotations as shown below to enable kubernetes deployment for the service we developed above. 

> NOTE: Linux users can use Minikube to try this out locally.

##### product_search_service.bal

```ballerina
package product_search;

import ballerina/http;
import ballerinax/kubernetes;

@kubernetes:Ingress {
    hostname: "ballerina.guides.io",
    name: "ballerina-guides-product-search-service",
    path: "/"
}

@kubernetes:Service {
    serviceType: "NodePort",
    name: "ballerina-guides-product-search-service"
}

@kubernetes:Deployment {
    image: "ballerina.guides.io/product_search_service:v1.0",
    name: "ballerina-guides-product-search-service"
}

listener http:Listener productSearchEP = new(9090);;

// Initialize the remote eCommerce endpoint

@http:ServiceConfig {basePath: "/products"}
service productSearchService on productSearchEP {  
``` 

- Here we have used ``  @kubernetes:Deployment `` to specify the Docker image name which will be created as part of building this service.
- We have also specified `` @kubernetes:Service {} `` so that it will create a Kubernetes service which will expose the Ballerina service that is running on a Pod.  
- In addition we have used `` @kubernetes:Ingress `` which is the external interface to access your service (with path `` /`` and host name ``ballerina.guides.io``)

If you are using Minikube, you need to set a couple of additional attributes to the `@kubernetes:Deployment` annotation.
- `dockerCertPath` - The path to the certificates directory of Minikube (e.g., `/home/ballerina/.minikube/certs`).
- `dockerHost` - The host for the running cluster (e.g., `tcp://192.168.99.100:2376`). The IP address of the cluster can be found by running the `minikube ip` command.
 
- Now you can build a Ballerina executable archive (.balx) of the service that we developed above, using the following command. It points to the service file that we developed above and it will create an executable binary out of that. 
This will also create the corresponding Docker image and the Kubernetes artifacts using the Kubernetes annotations that you have configured above.
  
```bash
   $ ballerina build product_search
  
   Run following command to deploy kubernetes artifacts:  
   $ kubectl apply -f ./target/kubernetes/product_search
```

- You can verify that the Docker image that we specified in `` @kubernetes:Deployment `` is created, by using `` docker ps images ``.
- Also the Kubernetes artifacts related our service, will be generated in `` ./target/product_search/kubernetes``. 
- Now you can create the Kubernetes deployment using:

```bash
   $ kubectl apply -f ./target/product_search/kubernetes 
   deployment.extensions "ballerina-guides-product-search-service" created
   ingress.extensions "ballerina-guides-product-search-service" created
   service "ballerina-guides-product-search-service" created
```

- You can verify Kubernetes deployment, service and ingress are running properly, by using following Kubernetes commands. 
```bash
   $ kubectl get service
   $ kubectl get deploy
   $ kubectl get pods
   $ kubectl get ingress
```

- If everything is successfully deployed, you can invoke the service either via Node port or ingress. 

Node Port:
 
```bash
   $ curl -X GET http://<Minikube_host_IP>:<Node_Port>/products/search?item=TV
```
If you are using Minikube, you should use the IP address of the Minikube cluster obtained by running the `minikube ip` command. The port should be the node port given when running the `kubectl get services` command.

Ingress:

Add `/etc/hosts` entry to match hostname. For Minikube, the IP address should be the IP address of the cluster.
``` 
127.0.0.1 ballerina.guides.io
```

Access the service 

```bash
   $ curl -X GET http://ballerina.guides.io/products/search?item=TV
```

## Observability 
Ballerina is by default observable. Meaning you can easily observe your services, resources, etc.
However, observability is disabled by default via configuration. Observability can be enabled by adding following configurations to `ballerina.conf` file and starting the ballerina service using it. A sample configuration file can be found in `resilency-timeouts/guide/product_search/`.

```ballerina
[b7a.observability]

[b7a.observability.metrics]
# Flag to enable Metrics
enabled=true

[b7a.observability.tracing]
# Flag to enable Tracing
enabled=true
```

To start the ballerina service using the configuration file, run the following command

```bash
   $ ballerina run --config product_search/ballerina.conf product_search/
```
NOTE: The above configuration is the minimum configuration needed to enable tracing and metrics. With these configurations default values are load as the other configuration parameters of metrics and tracing.

### Tracing 

You can monitor ballerina services using in built tracing capabilities of Ballerina. We'll use [Jaeger](https://github.com/jaegertracing/jaeger) as the distributed tracing system.
Follow the following steps to use tracing with Ballerina.

- You can add the following configurations for tracing. Note that these configurations are optional if you already have the basic configuration in `ballerina.conf` as described above.
```
   [b7a.observability]

   [b7a.observability.tracing]
   enabled=true
   name="jaeger"

   [b7a.observability.tracing.jaeger]
   reporter.hostname="localhost"
   reporter.port=5775
   sampler.param=1.0
   sampler.type="const"
   reporter.flush.interval.ms=2000
   reporter.log.spans=true
   reporter.max.buffer.spans=1000
```

- Run Jaeger Docker image using the following command
```bash
   $ docker run -d -p5775:5775/udp -p6831:6831/udp -p6832:6832/udp -p5778:5778 -p16686:16686 \
   -p14268:14268 jaegertracing/all-in-one:latest
```

- Navigate to `restful-service/guide` and run the restful-service using the following command
```bash
   $ ballerina run --config product_search/ballerina.conf product_search/
```

- Observe the tracing using Jaeger UI using following URL
```
http://localhost:16686
```

### Metrics
Metrics and alerts are built-in with ballerina. We will use Prometheus as the monitoring tool.
Follow the below steps to set up Prometheus and view metrics for Ballerina restful service.

- You can add the following configurations for metrics. Note that these configurations are optional if you already have the basic configuration in `ballerina.conf` as described under `Observability` section.

```
   [b7a.observability.metrics]
   enabled=true
   reporter="prometheus"

   [b7a.observability.metrics.prometheus]
   port=9797
   host="0.0.0.0"
```

- Create a file `prometheus.yml` inside `/tmp/` location. Add the below configurations to the `prometheus.yml` file.
```
   global:
     scrape_interval:     15s
     evaluation_interval: 15s

   scrape_configs:
     - job_name: prometheus
       static_configs:
         - targets: ['172.17.0.1:9797']
```

   NOTE : Replace `172.17.0.1` if your local Docker IP differs from `172.17.0.1`
   
- Run the Prometheus Docker image using the following command
```bash
   $ docker run -p 19090:9090 -v /tmp/prometheus.yml:/etc/prometheus/prometheus.yml \
   prom/prometheus
```

- Navigate to `restful-service/guide` and run the restful-service using the following command
```bash
   $ ballerina run --config product_search/ballerina.conf product_search/
```
   
- You can access Prometheus at the following URL
```
http://localhost:19090/
```

NOTE:  Ballerina will by default have following metrics for HTTP server connector. You can enter following expression in Prometheus UI
-  http_requests_total
-  http_response_time


### Logging

Ballerina has a log package for logging to the console. You can import ballerina/log package and start logging. The following section will describe how to search, analyze, and visualize logs in real time using Elastic Stack.

- Start the Ballerina Service with the following command from `resilency-timeouts/guide`
```bash
   $ nohup ballerina run product_search &>> ballerina.log&
```
   NOTE: This will write the console log to the `ballerina.log` file in the `resilency-timeouts/guide` directory

- Start Elasticsearch using the following command

- Start Elasticsearch using the following command
```bash
   $ docker run -p 9200:9200 -p 9300:9300 -it -h elasticsearch --name \
   elasticsearch docker.elastic.co/elasticsearch/elasticsearch:6.2.2 
```

   NOTE: Linux users might need to run `sudo sysctl -w vm.max_map_count=262144` to increase `vm.max_map_count` 
   
- Start Kibana plugin for data visualization with Elasticsearch
```bash
   $ docker run -p 5601:5601 -h kibana --name kibana --link \
   elasticsearch:elasticsearch docker.elastic.co/kibana/kibana:6.2.2     
```

- Configure logstash to format the ballerina logs

i) Create a file named `logstash.conf` with the following content
```
input {  
 beats{ 
     port => 5044 
 }  
}

filter {  
 grok{  
     match => { 
	 "message" => "%{TIMESTAMP_ISO8601:date}%{SPACE}%{WORD:logLevel}%{SPACE}
	 \[%{GREEDYDATA:package}\]%{SPACE}\-%{SPACE}%{GREEDYDATA:logMessage}"
     }  
 }  
}   

output {  
 elasticsearch{  
     hosts => "elasticsearch:9200"  
     index => "store"  
     document_type => "store_logs"  
 }  
}  
```

ii) Save the above `logstash.conf` inside a directory named as `{SAMPLE_ROOT}\pipeline`
     
iii) Start the logstash container, replace the {SAMPLE_ROOT} with your directory name
     
```bash
   $ docker run -h logstash --name logstash --link elasticsearch:elasticsearch \
    -it --rm -v ~/{SAMPLE_ROOT}/pipeline:/usr/share/logstash/pipeline/ \
    -p 5044:5044 docker.elastic.co/logstash/logstash:6.2.2
```
  
 - Configure filebeat to ship the ballerina logs
    
i) Create a file named `filebeat.yml` with the following content
```
filebeat.prospectors:
- type: log
  paths:
    - /usr/share/filebeat/ballerina.log
output.logstash:
  hosts: ["logstash:5044"]  
```
NOTE : Modify the ownership of filebeat.yml file using `$chmod go-w filebeat.yml` 

ii) Save the above `filebeat.yml` inside a directory named as `{SAMPLE_ROOT}\filebeat`   
        
iii) Start the logstash container, replace the {SAMPLE_ROOT} with your directory name
     
```bash
   $ docker run -v {SAMPLE_ROOT}/filbeat/filebeat.yml:/usr/share/filebeat/filebeat.yml \
   -v {SAMPLE_ROOT}/guide/product_search/ballerina.log:/usr/share\
   /filebeat/ballerina.log --link logstash:logstash docker.elastic.co/beats/filebeat:6.2.2
```
 
 - Access Kibana to visualize the logs using following URL
```
   http://localhost:5601 
```
  
 

