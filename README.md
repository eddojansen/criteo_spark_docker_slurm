# criteo_spark_docker_slurm

# Short description:
criteo_spark_docker_slurm provides an automated way to run Criteo benchmarks on a dynamically created Spark cluster that runs in Docker containers 
across multiple SLURM nodes.

# Requirements:
1) Working SLURM environment with or without GPU support
2) Docker installed on the SLURM nodes
3) Shared file storage shared across SLURM nodes (S3 supported for data sets)
4) Support to exclusively use SLURM nodes allowing the "--network host" option in Docker
5) Sudo access rights on SLURM nodes

# Preparation:
1) Git clone this repository on a node with access to the SLURM environment
      - https://github.com/eddojansen/criteo_spark_docker_slurm.git
2) Build your own Docker images or use the ones already provided, more Docker image details below
3) Download one or more Criteo datasets, each link below represents a single day of information; day_0 - day_23:
      -	http://azuremlsampleexperiments.blob.core.windows.net/criteo/day_0.gz
      -	http://azuremlsampleexperiments.blob.core.windows.net/criteo/day_1.gz
      -	http://azuremlsampleexperiments.blob.core.windows.net/criteo/day_2.gz
      - ...
4) Adjust start-container-on-slurm.script to match the resources available in your environment 
  and adjust the settings for testing, more details below
5) Adjust submit_criteo.sh when needed (not included in container)

# Usage:
1) To submit the Criteo workload to the SLURM environment run: sbatch start-container-on-slurm.script
2) When a job is accepted it will get a job number and create a log file for that job in the current directory
3) The history files for the jobs can be found in the history folder on the defined shared storage mount-point
4) The Criteo results can be found in the results folder on the defined shared storage mount-point

# start-container-on-slurm.script:
1) Provide mount-point for shared filesystem for config
      -	export MOUNT=/data
2) Provide mount-point for Criteo data set
      - export CRITEO_DATA=/data/days
3) Criteo test settings
      - export STARTDAY=0
      - export ENDDAY=0
      - export FREQUENCY_LIMIT=15
4) Enable or disable GPU with "true" or "false"
      - export ENABLE_GPU="true"
5) Set threads per GPU
      - export CONCURRENTGPU=1
6) When using S3 for the data set, change the below values accordingly
      - export INPUT_PATH="file:///opt/criteo/days"
      - export OUTPUT_PATH="file:///opt/results"
      - export S3_ENDPOINT=""
      - export S3A_CREDS_USR=""
      - export S3A_CREDS_PSW=""

# Docker images:
1) criteo_spark_docker_slurm uses the following 3 Docker images:  
      - gcr.io/data-science-enterprise/spark-master-rapids-cuda:3.0.1
      - gcr.io/data-science-enterprise/spark-worker-rapids-cuda:3.0.1
      - gcr.io/data-science-enterprise/spark-criteo-rapids-cuda:0.2
2) The Spark master and Criteo container will be run on the first SLURM node
3) The Spark worker container will be run on all nodes (including the first SLURM node)
4) The submit_criteo.sh will be mapped to /opt/criteo/submit_criteo.sh in the Criteo container and used as entrypoint
5) All images have the following:
      - Spark installed locally in /opt/spark
      - CUDA-11 installed, based from nvidia/cuda:11.0-devel-ubuntu18.04
      - cudf-0.15-cuda11.jar locally in /opt/sparkRapidsPlugin
      - rapids-4-spark_2.12-0.2.0.jar locally in /opt/sparkRapidsPlugin
      - getGpusResources.sh locally in /opt/sparkRapidsPlugin
6) In addition the Criteo image has the following:
      - xgboost4j-spark_3.0-1.3.0-20201029.081913-63.jar locally in /opt/sparkRapidsPlugin
      - xgboost4j_3.0-1.3.0-20201029.081852-63.jar locally in /opt/sparkRapidsPlugin
      - sample_xgboost_apps-0.2.2-SNAPSHOT.jar locally in /opt/criteo
      - spark_data_utils.py locally in /opt/criteo

# Building your own Docker images:
1) The following Dockerfiles are included in the repository:
      - Dockerfile-spark-master-rapids.cuda
      - Dockerfile-spark-worker-rapids.cuda
      - Dockerfile-spark-criteo-rapids.cuda
2) Follow the Dockerfile examples and ensure the following is present in the Docker build location:
      - Extracted spark installation
      - cudf-0.15-cuda11.jar
      - rapids-4-spark_2.12-0.2.0.jar
      - getGpusResources.sh 
      - xgboost4j-spark_3.0-1.3.0-20201029.081913-63.jar
      - xgboost4j_3.0-1.3.0-20201029.081852-63.jar
      - sample_xgboost_apps-0.2.2-SNAPSHOT.jar
      - spark_data_utils.py
3) Build images with:
      - docker build -t gcr.io/data-science-enterprise/spark-master-rapids-cuda:x.x.x -f Dockerfile-spark-master-rapids.cuda --network host .
4) Push images with:
      - docker push gcr.io/data-science-enterprise/spark-master-rapids-cuda:3.0.1

# Logic:
1) SLURM will allocate available nodes and resources
2) Required configuration folders will be created on the configured shared storage mountpoint
3) wait-worker.sh, kill-master.sh, kill-worker.sh and submit_criteo.sh will be copied to their designated folders 
4) Any old running Docker instances for master and criteo will be killed on the first SLURM node
5) Any old running docker instances for worker will be killed on all SLURM nodes
6) Cache will be dropped and cleared on all SLURM nodes
7) Hostnames for all SLURM nodes that participate in the job will be added to the mountpoint/conf/slaves file
8) Default Spark setting will be added to mountpoint/conf/spark-defaults.conf
9) When needed master docker image can be removed from first SLURM node (not enabled by default)
10) Run Spark master docker container on first SLURM node with:
      - mapped spark-defaults.conf
      - mapped history
      - mapped results
      - mapped criteo dataset
      - network host
11) When needed worker docker image can be removed from all SLURM nodes (not enabled by default)
12) Run Spark worker docker container on all SLURM nodes with:
      - mapped spark-defaults.conf
      - mapped history
      - mapped results
      - mapped criteo dataset
      - network host
13) Wait until all workers have been registered with the master
14) When needed Criteo docker image can be removed from first SLURM node (not enabled by default)
15) Run Spark Criteo docker container on all SLURM nodes with:
      - mapped spark-defaults.conf
      - mapped history
      - mapped results
      - mapped criteo dataset
      - mapped submit_criteo.sh
      - network host
16) Echo test complete message including results and history location
17) Kill master and Criteo instance on first SLURM node
18) Kill worker instance on all SLURM nodes
