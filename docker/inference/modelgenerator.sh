# make directory for the model download from huggingface
mkdir /blockstore/clone
mkdir -p /blockstore/model/store

# download model from huggingface
git clone https://<user>:<token>@huggingface.co/mistralai/Mistral-7B-Instruct-v0.1 /blockstore/clone

# modes generator step to fit the model on A10G (NV_M)
model_repo_generator llm --verbose --yaml_config_file=/home/ubuntu/instruct.yaml

#softlink the trt llm models from blockstorage to /model-store
ln -s /blockstore/model/store/ensemble /model-store/ensemble

#softlink the trt llm models from blockstorage to /model-store
ln -s /blockstore/model/store/trt_llm_0.0.1_trtllm /model-store/trt_llm_0.0.1_trtllm