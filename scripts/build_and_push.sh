#!/bin/bash

# This script builds and pushes the Docker image for the GKE demo application,
# then updates the Kubernetes deployment manifest with the new image path.

# --- Configuration ---
PROJECT_ID=$(gcloud config get-value project)
REPO_NAME="docker-images"
LOCATION="us-central1"
IMAGE_NAME="gke-demo-app"
TAG="latest"
DEPLOYMENT_FILE="gke/deployment.yaml"

# --- Full Image Path ---
IMAGE_PATH="${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${TAG}"

# --- Script Logic ---
echo "------------------------------------"
echo "Building and pushing image:"
echo "$IMAGE_PATH"
echo "------------------------------------"

# Navigate to the application directory
cd demo-app || { echo "Directory demo-app not found"; exit 1; }

# Build the Docker image
if ! docker build -t "$IMAGE_PATH" .; then
    echo "Docker build failed. Exiting."
    exit 1
fi

# Come back to the root directory
cd ..

# Push the Docker image to Artifact Registry
if ! docker push "$IMAGE_PATH"; then
    echo "Docker push failed. Exiting."
    exit 1
fi

echo "------------------------------------"
echo "Build and push successful!"
echo "Updating deployment manifest..."
echo "------------------------------------"

# --- NEW SECTION: UPDATE DEPLOYMENT MANIFEST ---
# Use sed to replace the placeholder with the actual image path.
# The use of '|' as a delimiter avoids issues with slashes in the path.
sed -i.bak "s|IMAGE_PLACEHOLDER|$IMAGE_PATH|g" "$DEPLOYMENT_FILE"

# Check if sed command was successful
if [ $? -eq 0 ]; then
    echo "Deployment file '$DEPLOYMENT_FILE' updated successfully."
    # Optional: remove the backup file created by sed
    rm "${DEPLOYMENT_FILE}.bak"
else
    echo "Failed to update deployment file."
    exit 1
fi

echo "------------------------------------"
echo "Script finished. You can now apply the manifest:"
echo "kubectl apply -f $DEPLOYMENT_FILE"
echo "------------------------------------"

