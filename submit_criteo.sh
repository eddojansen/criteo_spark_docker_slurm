set -eux

RESOURCE_GPU_AMT=$(echo "scale=3; ${NUM_EXECUTORS} / ${TOTAL_CORES}" | bc)

TRANSENDDAY=$((${ENDDAY}-1))

if [ $ENABLE_GPU = "false" ]
  then CMD_PARAM="--master spark://$MASTER:7077 \
    --jars ${JARS} \
    --driver-memory ${DRIVER_MEMORY} \
    --executor-cores ${NUM_EXECUTOR_CORES} \
    --executor-memory ${EXECUTOR_MEMORY} \
    --conf spark.sql.shuffle.partitions=${SHUFFLE_PARTITIONS} \
    --conf spark.task.cpus=2 \
    --conf spark.cores.max=${TOTAL_CORES} \
    --conf spark.sql.autoBroadcastJoinThreshold=1G \
    --conf spark.driver.maxResultSize=2G \
    --conf spark.sql.files.maxPartitionBytes=1G \
    --conf spark.executor.heartbeatInterval=300s \
    --conf spark.storage.blockManagerSlaveTimeoutMs=3600s \
    --conf spark.sql.files.maxPartitionBytes=${MAXPARTITIONBYTES} \
    --conf spark.locality.wait=0s \
    --conf spark.network.timeout=3600s \
    --conf spark.hadoop.fs.s3a.access.key=${S3A_CREDS_USR} \
    --conf spark.hadoop.fs.s3a.secret.key=${S3A_CREDS_PSW} \
    --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
    --conf spark.hadoop.fs.s3a.endpoint=${S3_ENDPOINT} \
    --conf spark.hadoop.fs.s3a.path.style.access=true \
    --conf spark.hadoop.fs.s3a.experimental.input.fadvise=sequential \
    --conf spark.hadoop.fs.s3a.connection.maximum=1000\
    --conf spark.hadoop.fs.s3a.threads.core=1000\
    --conf spark.hadoop.parquet.enable.summary-metadata=false \
    --conf spark.sql.parquet.mergeSchema=false \
    --conf spark.sql.parquet.filterPushdown=true \
    --conf spark.sql.hive.metastorePartitionPruning=true \
    --conf spark.hadoop.fs.s3a.connection.ssl.enabled=true" &&
    TEST="cpu_test" && 
  echo "Running CPU mode"

  else CMD_PARAM="--master spark://$MASTER:7077 \
    --jars ${JARS} \
    --driver-memory ${DRIVER_MEMORY} \
    --executor-cores ${NUM_EXECUTOR_CORES} \
    --executor-memory ${EXECUTOR_MEMORY} \
    --conf spark.sql.files.maxPartitionBytes=${MAXPARTITIONBYTES} \
    --conf spark.sql.shuffle.partitions=${SHUFFLE_PARTITIONS} \
    --conf spark.shuffle.consolidateFiles=true \
    --conf spark.task.cpus=1 \
    --conf spark.executor.resource.gpu.amount=1 \
    --conf spark.executor.extraJavaOptions="-Dai.rapids.cudf.prefer-pinned=true" \
    --conf spark.cores.max=${TOTAL_CORES} \
    --conf spark.sql.autoBroadcastJoinThreshold=2G \
    --conf spark.sql.files.maxPartitionBytes=2G \
    --conf spark.task.resource.gpu.amount=${RESOURCE_GPU_AMT} \
    --conf spark.sql.extensions=com.nvidia.spark.rapids.SQLExecPlugin \
    --conf spark.plugins=com.nvidia.spark.SQLPlugin \
    --conf spark.rapids.sql.incompatibleOps.enabled=true \
    --conf spark.rapids.sql.concurrentGpuTasks=${CONCURRENTGPU} \
    --conf spark.rapids.memory.pinnedPool.size=${PINNED_POOL_SIZE} \
    --conf spark.rapids.memory.gpu.pooling.enabled=true \
    --conf spark.rapids.shuffle.transport.enabled=true \
    --conf spark.rapids.memory.gpu.debug=STDOUT \
    --conf spark.executor.heartbeatInterval=300s \
    --conf spark.storage.blockManagerSlaveTimeoutMs=3600s \
    --conf spark.locality.wait=0s \
    --conf spark.network.timeout=1800s \
    --conf spark.executor.extraClassPath=${XGBOOST_JAR}:${XGBOOST_SPARK_JAR}:${SPARK_RAPIDS_PLUGIN_JAR}:${SPARK_CUDF_JAR} \
    --conf spark.driver.extraClassPath=${XGBOOST_JAR}:${XGBOOST_SPARK_JAR}:${SPARK_RAPIDS_PLUGIN_JAR}:${SPARK_CUDF_JAR} \
    --conf spark.hadoop.fs.s3a.access.key=${S3A_CREDS_USR} \
    --conf spark.hadoop.fs.s3a.secret.key=${S3A_CREDS_PSW} \
    --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
    --conf spark.hadoop.fs.s3a.endpoint=${S3_ENDPOINT} \
    --conf spark.hadoop.fs.s3a.path.style.access=true \
    --conf spark.hadoop.fs.s3a.experimental.input.fadvise=sequential \
    --conf spark.hadoop.fs.s3a.connection.maximum=$(( ${TOTAL_CORES} * 2 )) \
    --conf spark.hadoop.fs.s3a.threads.core=${TOTAL_CORES} \
    --conf spark.hadoop.parquet.enable.summary-metadata=false \
    --conf spark.sql.parquet.mergeSchema=false \
    --conf spark.sql.parquet.filterPushdown=true \
    --conf spark.hadoop.fs.s3a.connection.ssl.enabled=true" && 
  TEST="gpu_test" &&
  echo "Running GPU mode"
fi

/opt/spark/bin/spark-submit ${CMD_PARAM} \
	${SCRIPT} --mode generate_models \
        --input_folder ${INPUT_PATH} \
        --frequency_limit ${FREQUENCY_LIMIT} \
        --debug_mode \
        --days ${STARTDAY}-${ENDDAY} \
        --model_folder ${OUTPUT_PATH}/models \
        --write_mode overwrite --low_mem &&

/opt/spark/bin/spark-submit ${CMD_PARAM} \
	${SCRIPT} --mode transform \
        --input_folder ${INPUT_PATH} \
        --debug_mode \
        --days ${STARTDAY}-${TRANSENDDAY} \
        --output_folder ${OUTPUT_PATH}/train \
        --model_folder ${OUTPUT_PATH}/models \
        --write_mode overwrite --low_mem &&

/opt/spark/bin/spark-submit ${CMD_PARAM} \
	${SCRIPT} --mode transform \
        --input_folder ${INPUT_PATH} \
        --debug_mode \
        --days ${ENDDAY}-${ENDDAY} \
        --output_folder ${OUTPUT_PATH}/${TEST} \
        --output_ordering input \
        --model_folder ${OUTPUT_PATH}/models \
        --write_mode overwrite --low_mem
