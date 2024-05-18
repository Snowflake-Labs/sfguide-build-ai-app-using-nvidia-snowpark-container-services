# sfguide-build-ai-app-using-nvidia-snowpark-container-services

# NVIDIA NeMo Inference Service (NIM)

In this repo we primarily show how to download the Large Language Model [Mistral-7b-instructv0.1](https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.1) from [HuggingFace](https://huggingface.co/) and then shrink the model size to fit a smaller GPU on [NemoLLM Inference Microservice NIMs](https://registry.ngc.nvidia.com/orgs/ohlfw0olaadg/teams/ea-participants/containers/nemollm-inference-ms/tags) Container using the [model_generator](https://github.com/Snowflake-Labs/sfguide-build-ai-app-using-nvidia-snowpark-container-services/blob/main/docker/inference/modelgenerator.sh) and [instruct.yaml](https://github.com/Snowflake-Labs/sfguide-build-ai-app-using-nvidia-snowpark-container-services/blob/main/docker/inference/instruct.yaml) provided by NVIDIA.
![](https://github.com/Snowflake-Labs/sfguide-build-ai-app-using-nvidia-snowpark-container-services/blob/main/NVIDIA%20Mistral%207B%20NIMS%20on%20SPCS.png)
If you are interested to compress a different Large Language Model from Huggingface, you need a different instruct.yaml file that will generate a new model that will fit in a smaller GPU.

#### NVIDIA related

In this example, We are not downloading the model hosted on [nvcr.io](https://registry.ngc.nvidia.com/orgs/ohlfw0olaadg/teams/ea-participants/containers/nemollm-inference-ms/tags), but we will be using [NIMs container](https://registry.ngc.nvidia.com/orgs/ohlfw0olaadg/teams/ea-participants/containers/nemollm-inference-ms/tags), so please register and create your a login.

![](./NVIDIA-NeMo.gif)

#### Huggingface related

Since you are downloading the model from Huggingface, you need to register and create a [HuggingFace](https://huggingface.co/) user login. After logging into huggingface with your userid and password, [create a user access token](https://huggingface.co/docs/hub/en/security-tokens) to clone any model using git_lfs. This is a required step to clone a Large Language model such as Mistral-7b-instructv0.1  

Make sure you edit [model_generator.sh](https://github.com/Snowflake-Labs/sfguide-build-ai-app-using-nvidia-snowpark-container-services/blob/main/docker/inference/modelgenerator.sh) and replace the "user" and "token" with your information from huggingface before you move to the next step.

```
git clone https://<user>:<token>@huggingface.co/mistralai/Mistral-7B-Instruct-v0.1 /blockstore/clone

```

#### Snowflake related

This is a POC SPCS / NA service implementing the NVIDIA NeMo Microservices inference service. You can access the inference service by a Snowflake UDF. You can find the UDFs in your instance schema under Functions.

Under the hood, this app uses [fastchat api](https://github.com/lm-sys/FastChat/blob/main/docs/openai_api.md) exposed via a [flask app](https://flask.palletsprojects.com/en/3.0.x/).  The flask app currently implements only a completion route but can easily be extended to serve additional routes.

# Installation

## Native App Installation 

Since we are using a currently PrPr, soon to be PuPr NA <-> SPCS feature, you need to request the account where you are planning to build the provider app is enabled.

#### As a Provider  
Execute the Following the scripts in this sequence from the Provider scripts.  
1. [Setup.sql](https://github.com/Snowflake-Labs/sfguide-build-ai-app-using-nvidia-snowpark-container-services/blob/main/Native%20App/Provider/01%20Setup.sql)

STOP HERE AND FOLLOW THE DOCKER INSTALLATION STEPS
## Docker Installation

### Docker Image Build 

#### Docker login to nvcr.io. 
Register and get login credentials from [nvidia config set](https://org.ngc.nvidia.com/setup/api-key)

```
docker login nvcr.io  
user : "userid"  
password : "Auth Key"      
```

#### Build all 4 images
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

### Resume Native App Installation

2. [NIM Provider Application Pkg.sql](https://github.com/Snowflake-Labs/sfguide-build-ai-app-using-nvidia-snowpark-container-services/blob/main/Native%20App/Provider/02%20nims_app_pkg.sql)  
3. [Validation and output.sql](https://github.com/Snowflake-Labs/sfguide-build-ai-app-using-nvidia-snowpark-container-services/blob/main/Native%20App/Provider/03%20Validation%20and%20Output.sql)  
4. [Publish Application.sql](https://github.com/Snowflake-Labs/sfguide-build-ai-app-using-nvidia-snowpark-container-services/blob/main/Native%20App/Provider/04%20Publish%20Application.sql)  
  
#### As a Consumer (Template for testing)  
Execute the Following the scripts in this sequence from the Provider scripts.  
5. [Consumer App Template.sql](https://github.com/Snowflake-Labs/sfguide-build-ai-app-using-nvidia-snowpark-container-services/blob/main/Native%20App/Consumer/05%20Consumer%20App%20Template.sql) 


