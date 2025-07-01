# PepFlow: Full-Atom Peptide Design

![alt text](teaser.png)


This repository contains the official implementation of 💡 Full-Atom Peptide Design based on Multi-modal Flow Matching (ICML 2024).

You can find our [paper](https://arxiv.org/abs/2406.00735) here. We also appreciate the inspiration from [diffab](https://github.com/luost26/diffab) and [frameflow](https://github.com/microsoft/protein-frame-flow).

If you have any questions, please contact lijiahanypc@pku.edu.cn or ced3ljhypc@gmail.com. Thank you! :)

## Install


### Environment

Please replace cuda and torch version to match your machine, here we test our code on CUDA >= 11.7, we also suggest using [micromamba](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html) as a replace of conda.

```bash
conda env create -f environment.yml # or use micromamba instead of conda

conda activate flow

pip install torch-scatter -f https://data.pyg.org/whl/torch-2.0.0+cu117.html

pip install joblib lmdb easydict

```

### Clone Repo### Train

```bash
git clone https://github.com/Ced3-han/PepFlowww.git
```

We suggest adding the code to the Python environment variable, or you can use setup tools.

 ```bash
export PYTHONPATH=$(pwd):$PYTHONPATH
python setup.py develop
 ```


### Data and Weights Download

We provide data and pretrained model weights, please download from the google drive link: https://drive.google.com/drive/folders/1bHaKDF3uCDPtfsihjZs0zmjwF6UU1uVl?usp=sharing.

+ PepMerge_release.zip: 1.2GB
+ PepMerge_lmdb.zip: 180MB
+ model1.pt: 80MB
+ model2.pt: 80MB

The ```PepMerge_release.zip``` contains filtered data of peptide-receptor pairs. For example, in the folder ```1a0n_A```, the ```P``` chain in the PDB file ```1a0n``` is the peptide. In this folder, we provide the FASTA and PDB files of the peptide and receptor. The postfix _merge means the peptide and receptor are in the same PDB file. We also extract the binding pocket of the receptor, where our model is trained to generate peptides based on the binding pocket. You can also download [PepBDB](http://huanglab.phys.hust.edu.cn/pepbdb/db/1cta_A/) and [QBioLip](https://yanglab.qd.sdu.edu.cn/Q-BioLiP/Download), and use ```playgrounds/gen_dataset```.ipynb to reproduce the dataset.

The ```PepMerge_lmdb.zip``` contains several different splits of the dataset. We use ```mmseqs2``` to cluster complexes based on receptor sequence identity. See ```playgrounds/cluster.ipynb``` for details. The names.txt file contains the names of complexes in the test set. You can use ```models_con/pep_dataloader.py``` to load these datasets. We suggest putting these LMDBs in a single ```Data``` folder.

Besides, ```model1.pt``` and ```model2.pt``` are two checkpoints that you can load using ```models_con/flow_model.py``` together with the config file configs/learn_angle.yaml. We suggest using model1 for benchmark evaluation and model2 for real-world peptide design tasks, the latter is trained on a larger dataset.


## Usage

We will add more user-friendly straightforward pipelines (generation and evaluation) later.

### Inference and Generate

By default, we support sampling of generated peptides from our processed dataset. You can use ```models_con/sample.py``` to sample, and ```models_con/inference.py``` to reconstruct PDB files.

If you want to use your own data, you can organize your data (peptide and pocket) as we did in PepMerge_release and construct a dataset for sampling and reconstruction. You can also use ```models_con/pep_dataloader/preprocess_structure``` to parse a single data point. 




### Evaluation

Our evaluation involves many third-party packages, and we include some useful evaluation scripts in ```eval```. Please refer to our paper for details and download the corresponding packages for evaluation. Please use different python environments for these tools.



### Train

You can also use ```train.py``` for single GPU training and ```train_ddp.py``` for multiple GPU training.

### Training on Google Cloud Vertex AI

This project includes tools to run training jobs on Google Cloud Vertex AI, leveraging spot VMs for cost efficiency and GCS for dataset and checkpoint management.

**1. Prerequisites:**

*   **Google Cloud Project:** You need a Google Cloud Project with billing enabled.
*   **Enable APIs:** Ensure the following APIs are enabled in your project:
    *   Vertex AI API
    *   Artifact Registry API
    *   Cloud Build API (optional, if you build containers using Cloud Build)
*   **IAM Permissions:** The service account used by Vertex AI Custom Jobs (or your user account if running `gcloud` commands locally) needs appropriate permissions:
    *   `Vertex AI User` or `Vertex AI Administrator` role for managing Vertex AI jobs.
    *   `Artifact Registry Writer` (or `roles/artifactregistry.writer`) to push Docker images to Artifact Registry.
    *   `Storage Object Admin` (or `roles/storage.objectAdmin`) on the GCS buckets used for:
        *   Storing checkpoints.
        *   Storing the LMDB dataset.
*   **Google Cloud SDK:** Install and initialize the `gcloud` CLI.
*   **Docker:** Docker must be installed locally to build and push the container image.

**2. Data Preparation for Vertex AI Training:**

The training script `train.py` is configured to load LMDB datasets. For Vertex AI, these datasets should be stored in Google Cloud Storage (GCS).

*   **Download and Extract LMDB Dataset:**
    *   Download the `PepMerge_lmdb.zip` (or your custom LMDB dataset) from the link provided in the "Data and Weights Download" section.
    *   Extract the zip file. You should have one or more `.lmdb` files (e.g., `train_structure_cache.lmdb`, `val_structure_cache.lmdb`).
*   **Upload LMDB Files to GCS:**
    *   Create a GCS bucket (or use an existing one).
    *   Upload your LMDB files to a directory within this bucket. For example, if your bucket is `my-pepflow-bucket` and you want to store the LMDBs under `datasets/lmdb/`, you would upload them there:
        ```bash
        # Example: Uploading a directory containing train.lmdb, val.lmdb etc.
        gsutil -m cp -r path/to/your/extracted_lmdb_files/ gs://my-pepflow-bucket/datasets/lmdb/
        # Ensure individual files like train_structure_cache.lmdb are directly under the GCS path you'll specify.
        # For example, after upload, you should have:
        # gs://my-pepflow-bucket/datasets/lmdb/train_structure_cache.lmdb
        # gs://my-pepflow-bucket/datasets/lmdb/val_structure_cache.lmdb (if using validation)
        ```

**3. Configure the Submission Script:**

The `submit_job.sh` script is used to build the Docker image, push it to Artifact Registry, and submit the training job to Vertex AI.

*   Open `submit_job.sh` and edit the **CONFIGURATION** section:
    *   `PROJECT_ID`: Your Google Cloud Project ID.
    *   `REGION`: The Google Cloud region where you want to run Vertex AI jobs and store artifacts (e.g., `us-central1`).
    *   `GCS_BUCKET_NAME`: The name of your GCS bucket used for **storing checkpoints** (do not include `gs://` prefix). The script will create a subdirectory for checkpoints.
    *   `ARTIFACT_REGISTRY_REPO`: The name of your Artifact Registry repository where the Docker image will be stored. Create one if it doesn't exist (e.g., `pepflow-repo`).
    *   `IMAGE_NAME`: Name for your Docker image (default: `pepflow-trainer`).
    *   `IMAGE_TAG`: Tag for your Docker image (default: `latest`).
    *   `GCS_LMDB_DATA_DIR`: **Crucial for data loading.** The full GCS path to the directory containing your LMDB dataset files (e.g., `"gs://my-pepflow-bucket/datasets/lmdb/"`). Make sure this path ends with a trailing slash.
    *   `TRAIN_LMDB_FILENAME`: The filename of your main training LMDB file located in `GCS_LMDB_DATA_DIR` (e.g., `"train_structure_cache.lmdb"`).
    *   *(Optional)* `VAL_LMDB_FILENAME`: If you intend to use a validation LMDB dataset and have modified `train.py` to load it, specify its filename here.

**4. Run the Training Job:**

*   Ensure you are authenticated with gcloud and Docker is configured for Artifact Registry (the script attempts to do this via `gcloud auth configure-docker`).
*   Make the script executable: `chmod +x submit_job.sh`
*   Execute the script:
    ```bash
    ./submit_job.sh
    ```
    This will:
    1.  Build the Docker image using `Dockerfile`.
    2.  Push the image to your Artifact Registry.
    3.  Submit a custom training job to Vertex AI using the specified configuration (A100 GPU, spot VMs, GCS checkpointing, and GCS LMDB data path).

You can monitor the job progress in the Google Cloud Console under Vertex AI > Training > Custom Jobs. Checkpoints will be saved to the GCS path specified by `GCS_CHECKPOINT_PATH` in the script. Logs will be available in Cloud Logging.


## Future Work


Future improvements on peptide generation models may include chemical modifications, non-canonical amino acids, pretraining on larger datasets, language models, better sampling methods, etc. Stay tuned and feel free to contact us for collaboration and discussion!


## Reference

```bibtex
@InProceedings{pmlr-v235-li24o,
  title={Full-Atom Peptide Design based on Multi-modal Flow Matching},
  author={Li, Jiahan and Cheng, Chaoran and Wu, Zuofan and Guo, Ruihan and Luo, Shitong and Ren, Zhizhou and Peng, Jian and Ma, Jianzhu},
  booktitle={Proceedings of the 41st International Conference on Machine Learning},
  pages={27615--27640},
  year={2024},
  editor={Salakhutdinov, Ruslan and Kolter, Zico and Heller, Katherine and Weller, Adrian and Oliver, Nuria and Scarlett, Jonathan and Berkenkamp, Felix},
  volume={235},
  series={Proceedings of Machine Learning Research},
  month=21--27 Jul},
  publisher={PMLR},
}
```
