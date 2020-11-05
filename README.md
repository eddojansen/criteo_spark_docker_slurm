# criteo_spark_docker_slurm

Short description:
criteo_spark_docker_slurm provides an automated way to run Criteo benchmarks on a dynamicly created Spark cluster that runs in Docker containers 
across multiple SLURM nodes.

Requirements:
- Working SLURM environment with or without GPU support
- Docker installed on the SLURM nodes
- Shared file storage shared across SLURM nodes (S3 supported for data sets)
- Support to exclusivly use SLURM nodes allowing the "--network host" option in Docker
- Sudo access rights on SLURM nodes

Preperation:
- Git clone this repository on a node with access to the SLURM environment | https://github.com/eddojansen/criteo_spark_docker_slurm.git
- Build your own Docker images or use the ones already provided, more Docker image details below
- Download one or more Criteo datasets, each link below represents a single day of information; day_0 - day_23:
	http://azuremlsampleexperiments.blob.core.windows.net/criteo/day_0.gz
	http://azuremlsampleexperiments.blob.core.windows.net/criteo/day_1.gz
	http://azuremlsampleexperiments.blob.core.windows.net/criteo/day_2.gz
...
- Adjust start-container-on-slurm.script to match the respources availible in your environment 
  and adjust the settings for testing, more details below
- Adjust submit_criteo.sh when needed (not included in container)

Usage:
- To submit the Criteo workload to the slurm environment run: sbath start-container-on-slurm.script
- When a job is accepted it will get a job number and create a log file for that job in the current directory
- The history files for the jobs can be found in the history folder on the defined shared storage mountpoint
- The Criteo results can be found in the results folder on the defined shared storage mountpoint

start-container-on-slurm.script:
- Provide mountpoint for shared filesystem for config
	export MOUNT=/data
- Provide mountpoint for criteo data set
	export CRITEO_DATA=/data/days
- Criteo test settings
	export STARTDAY=0
	export ENDDAY=0
	export FREQUENCY_LIMIT=15
- Enable or disable GPU with "true" or "false"
	export ENABLE_GPU="true"
- Set threads per GPU
	export CONCURRENTGPU='1'
- When using S3 for the data set, change the below values accordingly
	export INPUT_PATH="file:///opt/criteo/days"
	export OUTPUT_PATH="file:///opt/results"
	export S3_ENDPOINT=""
	export S3A_CREDS_USR=""
	export S3A_CREDS_PSW=""

Docker images:
- criteo_spark_docker_slurm uses the following 3 Docker images:  
	gcr.io/data-science-enterprise/spark-master-rapids-cuda:3.0.1
	gcr.io/data-science-enterprise/spark-worker-rapids-cuda:3.0.1
	gcr.io/data-science-enterprise/spark-criteo-rapids-cuda:0.2
- The Spark master and Criteo container will be run on the first SLURM node
- The Spark worker container will be run on all nodes (including the first SLURM node)
- The submit_criteo.sh will be mapped to /opt/criteo/submit_criteo.sh in the Criteo container and used as entrypoint
- All images have the following:
	Spark installed locally in /opt/spark
	CUDA-11 installed, based from nvidia/cuda:11.0-devel-ubuntu18.04
	cudf-0.15-cuda11.jar locally in /opt/sparkRapidsPlugin
	rapids-4-spark_2.12-0.2.0.jar locally in /opt/sparkRapidsPlugin
	getGpusResources.sh locally in /opt/sparkRapidsPlugin
- In addition the Criteo image has the following:
	xgboost4j-spark_3.0-1.3.0-20201029.081913-63.jar locally in /opt/sparkRapidsPlugin
	xgboost4j_3.0-1.3.0-20201029.081852-63.jar locally in /opt/sparkRapidsPlugin
	sample_xgboost_apps-0.2.2-SNAPSHOT.jar locally in /opt/criteo
        spark_data_utils.py locally in /opt/criteo

Building your own Docker images:
- The following Dockerfiles are included in the repository:
	Dockerfile-spark-master-rapids.cuda
	Dockerfile-spark-worker-rapids.cuda
	Dockerfile-spark-criteo-rapids.cuda
- Follow the Dockerfile examples and ensure the following is present in the Docker build location:
	Extracted spark installation
	cudf-0.15-cuda11.jar
	rapids-4-spark_2.12-0.2.0.jar
	getGpusResources.sh 
	xgboost4j-spark_3.0-1.3.0-20201029.081913-63.jar
	xgboost4j_3.0-1.3.0-20201029.081852-63.jar
	sample_xgboost_apps-0.2.2-SNAPSHOT.jar
	spark_data_utils.py
- Build images with:
	docker build -t gcr.io/data-science-enterprise/spark-master-rapids-cuda:x.x.x -f Dockerfile-spark-master-rapids.cuda --network host .
- Push images with:
	docker push gcr.io/data-science-enterprise/spark-master-rapids-cuda:3.0.1

Logic:
- SLURM will allocate availible nodes and resources
- Required configuration folders will be created on the configured shared storage mountpoint
- wait-worker.sh, kill-master.sh, kill-worker.sh and submit_criteo.sh will be copied to their designated folders 
- Any old running Docker instances for master and criteo will be killed on the first SLURM node
- Any old running docker instances for worker will be killed on all SLURM nodes
- Cache will be dropped and cleared on all SLURM nodes
- Hostnames for all SLURM nodes that participate in the job will be added to the mountpoint/conf/slaves file
- Default Spark setting will be added to mountpoint/conf/spark-defaults.conf
- When needed master docker image can be removed from first SLURM node (not enabled by default)
- Run Spark master docker container on first SLURM node with:
	mapped spark-defaults.conf
 	mapped history 
	mapped results
	mapped criteo dataset
        network host
- When needed worker docker image can be removed from all SLURM nodes (not enabled by default)
- Run Spark worker docker container on all SLURM nodes with:
        mapped spark-defaults.conf
        mapped history
        mapped results
        mapped criteo dataset
        network host
- Wait untill all workers have been registered with the master
- When needed Criteo docker image can be removed from first SLURM node (not enabled by default)
- Run Spark Criteo docker container on all SLURM nodes with:
       -- mapped spark-defaults.conf
       -- mapped history
       -- mapped results
       -- mapped criteo dataset
       -- mapped submit_criteo.sh
       -- network host
- Echo test complete message including results and history location
- Kill master and Criteo instance on first SLURM node
- Kill worker instance on all SLURM nodes

