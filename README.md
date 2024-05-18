# sfguide-build-ai-app-using-nvidia-snowpark-container-services

# NVIDIA NeMo Inference Service (NIM)

#### NVIDIA related

This repo primarily show how to download the Large Language Model from HuggingFace using your login and token. In this case, we are downloading the Mistral-7b-instructv0.1 . On the "Nemo Inference Microservice NIMs" Container and using the instruct.yaml provided by NVIDIA, a compressed model is generated to fit in a A10G GPU (GPU_NV_M) with the model_generator. 

If you are interested to compress a different Large Language Model from Huggingface, we need a different instruct.yaml file that will generate a new model to work on tritron server.

The Microservices version of the NeMo inference engine requires the model to be downlaoded from the NVIDIA repository at [nvcr.io](https://nvcr.io). For that you need a login from NVIDIA for [NGC](https://ngc.nvidia.com/signin). With that you can request an API token to login to the NVIDIA repository.

![](./NVIDIA-NeMo.gif)

#### Huggingface related

Since you are downloading the model from Huggingface, you need to register and create a huggingface user login. After logging into huggingface with your userid and password, create a token to download any model. This is a required step to clone a Large Language model such as Mistral-7b-instructv0.1 
Make sure you edit model_generator.sh and replace the <user> and <token> with your information from huggingface before you move to the next step.
git clone https://<user>:<token>@huggingface.co/mistralai/Mistral-7B-Instruct-v0.1 /blockstore/clone

#### Snowflake related

This is a POC SPCS / NA service implementing the NVIDIA NeMo Microservices inference service. You can access the inference service by a Snowflake UDF. You can find the UDFs in your instance schema under Functions.

Under the hood, this app uses [fastchat api](https://github.com/lm-sys/FastChat/blob/main/docs/openai_api.md) exposed via a [flask app](https://flask.palletsprojects.com/en/3.0.x/).  The flask app currently implements only a completion route but can easily be extended to serve additional routes.


## Installation

The NA is currently installed (consumer side) on [SS_LPRPR_TEST1](https://pkb34677.snowflakecomputing.com).

After the NA has been installed, it presents a worksheet to create an instance of the inference service. You need to provide 
1. an instance name
2. a compute pool
3. a device list, i.e. GPUs to be used
4. number of GPUs per isntance
5. number of inferencing instances 
6. max_tokens and temperature

## User Interface

### The ```ping()``` UDF

The ping function is used to determine if the inference is service is up. It returns *pong*.

```
    SELECT <your instance>.ping()
```

### The ```inference(<model>,<prompt>,<max_tokens>,<temperature>)``` UDF

The inference function requires 4 arguments, i.e. the model name (which is currently always llama2), a prompt, max_tokens, temperature. It returns the completion for each row passed.

```
    SELECT <your instance>.inference(<model>,<prompt>,<max_tokens>,<temperature>)
```

## Known Issues


