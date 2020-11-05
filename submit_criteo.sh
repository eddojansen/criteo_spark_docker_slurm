set -eux

CMD_PARAM="--master $MASTER \
    --jars $JARS \
    --driver-memory ${DRIVER_MEMORY}G \
    --executor-cores $NUM_EXECUTOR_CORES \
    --executor-memory ${EXECUTOR_MEMORY} \
    --conf spark.cores.max=$TOTAL_CORES \
    --conf spark.files.maxPartitionBytes=1342177280 \
    --conf spark.task.cpus=${NUM_EXECUTOR_CORES} \
    --conf spark.task.resource.gpu.amount=$RESOURCE_GPU_AMT \
    --conf spark.executor.resource.gpu.amount=1 \
    --conf spark.sql.extensions=com.nvidia.spark.rapids.SQLExecPlugin \
    --conf spark.plugins=com.nvidia.spark.SQLPlugin \
    --conf spark.rapids.sql.concurrentGpuTasks=2 \
    --conf spark.rapids.sql.reader.batchSizeRows=4000000 \
    --conf spark.rapids.memory.pinnedPool.size=16g \
    --conf spark.sql.autoBroadcastJoinThreshold=1GB \
    --conf spark.rapids.sql.incompatibleOps.enabled=true \
    --conf spark.sql.files.maxPartitionBytes=1G \
    --conf spark.driver.maxResultSize=2G \
    --conf spark.locality.wait=0s \
    --conf spark.executor.extraClassPath=${XGBOOST_JAR}:${XGBOOST_SPARK_JAR}:${SPARK_RAPIDS_PLUGIN_JAR}:${SPARK_CUDF_JAR} \
    --conf spark.driver.extraClassPath=${XGBOOST_JAR}:${XGBOOST_SPARK_JAR}:${SPARK_RAPIDS_PLUGIN_JAR}:${SPARK_CUDF_JAR} \
    --conf spark.network.timeout=1800s \
    --conf spark.hadoop.fs.s3a.access.key=$S3A_CREDS_USR \
    --conf spark.hadoop.fs.s3a.secret.key=$S3A_CREDS_PSW \
    --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
    --conf spark.hadoop.fs.s3a.endpoint=$S3_ENDPOINT \
    --conf spark.hadoop.fs.s3a.path.style.access=true \
    --conf spark.hadoop.fs.s3a.experimental.input.fadvise=sequential \
    --conf spark.hadoop.fs.s3a.connection.maximum=1000\
    --conf spark.hadoop.fs.s3a.threads.core=1000\
    --conf spark.hadoop.parquet.enable.summary-metadata=false \
    --conf spark.sql.parquet.mergeSchema=false \
    --conf spark.sql.parquet.filterPushdown=true \
    --conf spark.sql.hive.metastorePartitionPruning=true \
    --conf spark.hadoop.fs.s3a.connection.ssl.enabled=true"    
    
/opt/spark/bin/spark-submit $CMD_PARAM \
    	--conf spark.sql.shuffle.partitions=600 \
    	--conf spark.executor.extraJavaOptions="-Dai.rapids.cudf.prefer-pinned=${ENABLE_GPU}\ -Djava.io.tmpdir=/tmp" \
    	$SCRIPT --mode generate_models \
    	--input_folder $INPUT_PATH \
    	--frequency_limit $FREQUENCY_LIMIT \
        --debug_mode \
    	--days ${STARTDAY}-${ENDDAY} \
    	--model_folder $OUTPUT_PATH/models \
	--write_mode overwrite --low_mem &&

/opt/spark/bin/spark-submit $CMD_PARAM \
	--conf spark.sql.shuffle.partitions=600 \
        --conf spark.executor.extraJavaOptions="-Dai.rapids.cudf.prefer-pinned=$ENABLE_GPU\ -Djava.io.tmpdir=/tmp" \
        $SCRIPT --mode transform \
        --input_folder $INPUT_PATH \
        --debug_mode \
        --days ${STARTDAY}-${ENDDAY} \
        --output_folder $OUTPUT_PATH/train \
        --model_folder $OUTPUT_PATH/models \
        --write_mode overwrite --low_mem &&

/opt/spark/bin/spark-submit $CMD_PARAM \
        --conf spark.sql.shuffle.partitions=30 \
        --conf spark.executor.extraJavaOptions="-Dai.rapids.cudf.prefer-pinned=$ENABLE_GPU\ -Djava.io.tmpdir=/tmp/" \
        $SCRIPT --mode transform \
        --input_folder $INPUT_PATH \
        --debug_mode \
        --days ${STARTDAY}-${ENDDAY} \
        --output_folder $OUTPUT_PATH/gpu_test \
        --output_ordering input \
        --model_folder $OUTPUT_PATH/models \
        --write_mode overwrite --low_mem 
