# Installing kind to work with a K8 local cluster
- Install kind (kind.sigs.k8s.io)
- From polar-deployment/kubernetes, run the following command to create a local Kubernetes cluster named
  kind-polar-cluster (kind- + the name value specified in the configuration file):
    ```
    kind create cluster --config=kind-config.yml
    ```

# Preparing the microservice for deployment
Install the command-line tool called *HTTPie* to test the behavior of the RESTful endpoints.montecarlos 

1. Add Spring Cloud Config Client to the service to make it fetch configuration data from Config Service.

2. Configure the Cloud Native Buildpacks integration, containerize the application, and define both CI and CD pipelines.
    - Build the image calling:
      ```
      ./run.sh build_image <REGISTRY_URL> <REGISTRY_USERNAME> <REGISTRY_TOKEN>
      ```
3. Write the Deployment and Service manifests for deploying the MS to a Kubernetes cluster.
    - Once is done, run the following command from the MS root directory:
        ```
        kubectl apply -f k8s/deployment.yml
        ```
    - To list all the pods of the current deployment:      
        ```
        kubectl get pods -l app=order-service
        ```
    - To delete all the objects created for Order Service, from the MS root directory:      
        ```
        kubectl delete -f k8s
        ```
Finally, navigate to the polar-deployment/kubernetes/local folder and delete the MySQL installation:
```
kubectl delete -f platform
```  

4. Configure Skaffold to automate the MS deployment to the local Kubernetes cluster initialized with kind.
    - Before configuring Skaffold, makes sure you have a database instance up and running in your local Kubernetes cluster. 
      Open a Terminal window, navigate to your polar-deployment/kubernetes/local folder, and run the following command to deploy
      the database:
      ```
      kubectl apply -f platform
      ```
    - Install Skaffold.
    - If there is not any skaffold.yml file in the MS directory, open a Terminal window, navigate to the project root folder,
      and run the following command:
      ```
      skaffold init --XXenableBuildpacksInit
      ```
              
    - Then from the MS root directory run:
      ```
      skaffold dev --no-prune=false --cache-artifacts=false --no-prune-children=false --port-forward
      ```
      For debugging at the same time:
      ```
      skaffold debug --port-forward
      ```
      
# Visualizing your Kubernetes workloads with Octant  
- Install Octant (octant.dev)    