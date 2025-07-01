#!/bin/bash

# #############################################################################
# HELPERS (you don't need to change anything here)
# #############################################################################

# Exit immediately if a command exits with a non-zero status.
set -e

# #############################################################################
# CONFIGURATION (fill in your values here)
# #############################################################################

# GCP Project ID
PROJECT_ID="your-gcp-project-id"

# Google Cloud Region for Vertex AI and Artifact Registry
REGION="us-central1" # e.g., us-central1

# GCS Bucket name for storing checkpoints (without gs:// prefix)
GCS_BUCKET_NAME="your-gcs-bucket-name"

# Artifact Registry repository name (must exist or be created)
ARTIFACT_REGISTRY_REPO="your-artifact-registry-repo-name" # e.g., peptide-folding-repo

# Docker image name
IMAGE_NAME="pepflow-trainer"

# Docker image tag (e.g., latest, v1.0)
IMAGE_TAG="latest"

# Display name for the Vertex AI Custom Job
JOB_DISPLAY_NAME="pepflow-spot-training-$(date +%Y%m%d_%H%M%S)"

# Path within the GCS bucket for this job's checkpoints
# This will create a unique directory for each job under the main GCS_BUCKET_NAME
JOB_CHECKPOINT_DIR_SUFFIX="pepflow_checkpoints/${JOB_DISPLAY_NAME}" # Vertex AI will create this sub-directory if it doesn't exist

# Machine type for the training job
MACHINE_TYPE="a2-ultragpu-1g" # As requested: a2-ultragpu-1g

# Accelerator type and count (derived from machine type for A2/N1 series)
# For a2-ultragpu-1g, it implies 1 NVIDIA A100 80GB GPU.
# The API expects this in a specific format if you need to be explicit,
# but for A2 types, it's often inferred. We'll specify it for clarity.
ACCELERATOR_TYPE="NVIDIA_A100_80GB"
ACCELERATOR_COUNT=1

# #############################################################################
# SCRIPT LOGIC (generally, no changes needed below this line)
# #############################################################################

# Construct the full image URI for Artifact Registry
IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"

# Construct the full GCS path for checkpoints
GCS_CHECKPOINT_PATH="gs://${GCS_BUCKET_NAME}/${JOB_CHECKPOINT_DIR_SUFFIX}"

# Authenticate gcloud if needed (usually done if running locally, not needed in Cloud Shell)
# gcloud auth login
# gcloud auth application-default login

# Configure Docker to use gcloud as a credential helper for Artifact Registry
echo "Configuring Docker for Artifact Registry..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

# Build the Docker image
echo "Building Docker image: ${IMAGE_URI}..."
docker build -t ${IMAGE_URI} -f Dockerfile .
echo "Docker image build complete."

# Push the Docker image to Artifact Registry
echo "Pushing Docker image to Artifact Registry: ${IMAGE_URI}..."
docker push ${IMAGE_URI}
echo "Docker image push complete."

# Submit the Vertex AI Custom Training Job
echo "Submitting Vertex AI Custom Training Job: ${JOB_DISPLAY_NAME}..."
echo "Using image: ${IMAGE_URI}"
echo "Machine type: ${MACHINE_TYPE}"
echo "Using Spot VMs."
echo "Checkpoint GCS Path: ${GCS_CHECKPOINT_PATH}"

# Note on Spot VMs:
# For worker_pool_spec, to enable spot VMs, you'd typically use the `enable-spot-vm` flag
# in the gcloud command or directly set `use_spot_vms = True` in the API request's scheduling field.
# The `gcloud ai custom-jobs create` command structure for spot VMs:
# --worker-pool-spec=machine-type=${MACHINE_TYPE},replica-count=1,container-image-uri=${IMAGE_URI},accelerator-type=${ACCELERATOR_TYPE},accelerator-count=${ACCELERATOR_COUNT} \
# --enable-spot-vm \
# (or for more complex scheduling: --scheduling-use-spot-vms)

gcloud ai custom-jobs create \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --display-name=${JOB_DISPLAY_NAME} \
  --worker-pool-spec=machine-type=${MACHINE_TYPE},replica-count=1,container-image-uri=${IMAGE_URI},accelerator-type=${ACCELERATOR_TYPE},accelerator-count=${ACCELERATOR_COUNT} \
  --enable-spot-vm \
  --args="--config=./configs/angle/learn_angle.yaml,--checkpoint-dir=${GCS_CHECKPOINT_PATH}" \
  --labels=job-type=training,experiment=pepflow

echo "Vertex AI Custom Training Job submitted."
echo "Job Name (for tracking): projects/${PROJECT_ID}/locations/${REGION}/customJobs/<JOB_ID>"
echo "You can monitor the job in the Google Cloud Console (Vertex AI > Training > Custom Jobs)."
echo "Checkpoints will be saved to: ${GCS_CHECKPOINT_PATH}"
