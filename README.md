Of course. Here is the complete and final `README.md` file in Markdown format for you to copy.

# GKE Advanced Lifecycle & Resizing Demo

A hands-on demonstration of two powerful Google Kubernetes Engine (GKE) features, designed to work on both **GKE Autopilot and Standard** clusters:

1.  **Graceful Pod Termination:** Showcasing how to properly configure `terminationGracePeriodSeconds` and the `preStop` lifecycle hook to ensure applications shut down cleanly.
2.  **In-Place Resource Resizing:** Demonstrating how to change a container's CPU and memory allocations *without a restart*.

This project is designed for customer engineers to present these advanced GKE capabilities to clients in a clear and impactful way.

-----

## Getting Started

Follow these instructions to get the demo environment set up on your GKE cluster.

### Prerequisites

Before you begin, ensure you have the following:

  * A **GKE Autopilot or Standard cluster** running **Kubernetes v1.33** or later.
  * The `gcloud` CLI, `docker`, and `kubectl` are installed and configured.
  * An Artifact Registry Docker repository named `docker-images`. If you don't have one, create it:
    ```bash
    gcloud artifacts repositories create docker-images --repository-format=docker --location=us-central1
    ```

> **Note on Cluster Modes:** While this demo works on both cluster types, the resource requests in `gke/deployment.yaml` are set to be compatible with GKE Autopilot's requirements. On a Standard cluster, you have more flexibility to adjust these values.

#### Verifying the In-Place Resizing Feature (Beta)

The ability to resize container resources in-place is a **Beta** feature in Kubernetes v1.33 and is enabled by default in GKE. You can verify that the feature gate is active on your cluster by running the following command. This precise filter ensures you only see the relevant line.

```bash
kubectl get --raw /metrics | grep 'InPlacePodVerticalScaling",stage="BETA"'
```

The output should be exactly this line. The `1` at the end confirms it is enabled.

```
kubernetes_feature_enabled{name="InPlacePodVerticalScaling",stage="BETA"} 1
```

### Installation

This demo requires a custom application image that can handle termination signals gracefully. The application code is located in `demo-app/app.py`.

1.  **Build and Push the Container:** A shell script is provided in the `scripts/` directory to automate this.
    ```bash
    # Make the script executable
    chmod +x scripts/build_and_push.sh

    # Run the script to build and push the image
    ./scripts/build_and_push.sh
    ```

-----

## Usage: Running the Demo

Once the image is pushed, you can demonstrate the two key features.

### Feature 1: Graceful Pod Termination

This part demonstrates how a pod can shut down cleanly without being abruptly killed. A graceful shutdown is a two-part process: the application must be coded to handle termination signals, and the Kubernetes pod must be configured to give the application time to do so.

#### The Application's Role: Handling `SIGTERM`

First, the application itself must be able to catch the `SIGTERM` signal that Kubernetes sends. In our `demo-app/app.py`, we've added a signal handler to do this.

**Purpose:** This code ensures that when the application is asked to terminate, it doesn't just crash. Instead, it runs a predefined function (`handle_sigterm`) to print a message and exit with a success code (`sys.exit(0)`), telling Kubernetes the shutdown was clean.

#### The Infrastructure's Role: The Grace Period

Next, we configure the pod in `gke/deployment.yaml` to provide a "time budget" for this shutdown process.

  * `terminationGracePeriodSeconds: 60`: This is the **total time** the pod has to shut down after termination is initiated. It's the master clock. After 60 seconds, the pod will be forcibly killed (`SIGKILL`) no matter what.
  * `preStop.sleep.seconds: 45`: This is a **blocking action** that runs first. It consumes 45 seconds from the 60-second budget. Its purpose is to simulate a delay for external systems, like a load balancer, to stop sending new traffic to the pod.

The key is that the `preStop` sleep (45s) is shorter than the grace period (60s), which leaves **15 seconds of dedicated time for our application's `handle_sigterm` logic to run** after the connection draining is complete.

#### Running the Demo

1.  **Deploy the application** using the manifest designed for this test.
    ```bash
    kubectl apply -f gke/deployment.yaml
    ```
2.  **Get the pod name** and start watching its status in one terminal. This is your primary visual.
    ```bash
    POD_NAME=$(kubectl get pods -l app=demo -o jsonpath='{.items[0].metadata.name}')
    watch kubectl get pod $POD_NAME
    ```
3.  **Delete the pod** in a second terminal to initiate the termination sequence.
    ```bash
    kubectl delete pod $POD_NAME
    ```
4.  **Quickly check the logs** in a third terminal. You have to be fast to catch the message before the container is gone.
    ```bash
    kubectl logs $POD_NAME
    ```
5.  **Observe and Explain:** Point to the watch window. The pod's status will change from `Running` to `Terminating` and will stay that way for the grace period. Then, point to the logs, which will show:
    ```
    SIGTERM received. Application is shutting down gracefully!
    ```
    This proves that the application code ran and the pod was given the necessary time, resulting in a clean shutdown.

### Feature 2: In-Place Resource Resizing

This part demonstrates how to change a container's resources without a restart.

1.  **Deploy the application** if it's not already running.
    ```bash
    kubectl apply -f gke/deployment.yaml
    ```
2.  **Get the pod name.**
    ```bash
    POD_NAME=$(kubectl get pods -l app=demo -o jsonpath='{.items[0].metadata.name}')
    ```
3.  **Show resources BEFORE the patch.** This command provides a clean view of the current state.
    ```bash
    kubectl get pod $POD_NAME -o custom-columns="POD:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,CPU_REQUEST:.spec.containers[0].resources.requests.cpu,MEM_REQUEST:.spec.containers[0].resources.requests.memory"
    ```
4.  **Apply the patch** to manually resize the container's CPU and memory.
    ```bash
    kubectl patch pod $POD_NAME --subresource resize --patch \
      '{"spec":{"containers":[{"name":"demo-app", "resources":{"requests":{"cpu":"800m", "memory":"820Mi"}, "limits":{"cpu":"800m", "memory":"820Mi"}}}]}}'
    ```
5.  **Show resources AFTER the patch.** Run the same `get` command again. The resource values will be updated, but the `RESTARTS` count will remain `0`, proving the resize was done in-place.
    ```bash
    kubectl get pod $POD_NAME -o custom-columns="POD:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,CPU_REQUEST:.spec.containers[0].resources.requests.cpu,MEM_REQUEST:.spec.containers[0].resources.requests.memory"
    ```

-----

## Cleanup

To remove all the demo resources from your cluster, simply delete the deployment.

```bash
kubectl delete -f gke/deployment.yaml
```