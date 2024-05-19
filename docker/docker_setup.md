# Docker Image Build Steps

#### Docker login to nvcr.io. (login credentials after registering in nvidia config set in https://org.ngc.nvidia.com/setup/api-key)
```
docker login nvcr.io  
user : "userid"  
password : "Auth Key"      
```

#### Build all images
```
docker build . -t inference:v01     
docker build . -t model-store:v01  
docker build . -t snowflake_handler:v01  
docker build . -t lab:v01  
```

#### Check if all images are created locally
```
docker images  
```
#### docker login to snowflake image repository (you can get your image repository url using "SHOW IMAGE REPOSITORIES")
```
docker login <snowflakeurl>/nvidia_nemo_ms_master/code_schema/service_repo  
user : "snowflake user id"
password : "password" 
```

#### Tag all 4 images from local to target destination

```
docker tag inference:v01 <snowflakeurl>/nvidia_nemo_ms_master/code_schema/service_repo/nemollm-inference-ms:24.02.nimshf  
docker tag model-store:v01 <snowflakeurl>/nvidia_nemo_ms_master/code_schema/service_repo/nvidia-nemo-ms-model-store:v01  
docker tag snowflake_handler:v01 <snowflakeurl>/nvidia_nemo_ms_master/code_schema/service_repo/snowflake_handler:v0.4  
docker tag lab:v01 <snowflakeurl>/nvidia_nemo_ms_master/code_schema/service_repo/snowflake_jupyterlab:v0.1  
```

#### Push all 4 images to snowflake image repo
```
docker push <snowflakeurl>/nvidia_nemo_ms_master/code_schema/service_repo/nemollm-inference-ms:24.02.nimshf  
docker push <snowflakeurl>/nvidia_nemo_ms_master/code_schema/service_repo/nvidia-nemo-ms-model-store:v01  
docker push <snowflakeurl>/nvidia_nemo_ms_master/code_schema/service_repo/snowflake_handler:v0.4  
docker push <snowflakeurl>/nvidia_nemo_ms_master/code_schema/service_repo/snowflake_jupyterlab:v0.1  
```

#### Check if the instruct.yaml and modelgenerator.sh files are available by logging into the inference container locally
```
docker run -it --rm=true <snowflakeurl>/nvidia_nemo_ms_master/code_schema/service_repo/nemollm-inference-ms:24.02.nimshf /bin/bash
```
