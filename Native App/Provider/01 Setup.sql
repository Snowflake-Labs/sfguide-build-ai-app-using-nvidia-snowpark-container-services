-- ########## BEGIN INITIALIZATION  ######################################
-- Create Compute pool using GPU_NV_M instance family
CREATE COMPUTE POOL <COMPUTE_POOL_NAME>
  MIN_NODES=1
  MAX_NODES=1
  INSTANCE_FAMILY=GPU_NV_M; -- DO NOT CHANGE SIZE AS THE instruct.yaml is defined to work on A10G GPU with higher memory. 
                            -- GPU_NV_S may work but not guarenteed.

SET APP_OWNER_ROLE = 'SPCS_PSE_PROVIDER_ROLE';
SET APP_WAREHOUSE = 'XS_WH';
SET APP_COMPUTE_POOL = 'COMPUTE_POOL_NAME';
SET APP_DISTRIBUTION = 'INTERNAL'; -- change to external when you are ready to publish outside your snowflake organization

USE ROLE identifier($APP_OWNER_ROLE);

-- DROP DATABASE IF EXISTS NVIDIA_NEMO_MS_APP_PKG ; --OPTIONAL STEP IF YOU WANT TO DROP THE APPLICATION PACKAGE. DONT UNCOMMENT

USE WAREHOUSE identifier($APP_WAREHOUSE);

CREATE DATABASE IF NOT EXISTS NVIDIA_NEMO_MS_MASTER;
USE DATABASE NVIDIA_NEMO_MS_MASTER;
CREATE SCHEMA IF NOT EXISTS CODE_SCHEMA;
USE SCHEMA CODE_SCHEMA;
CREATE IMAGE REPOSITORY IF NOT EXISTS SERVICE_REPO;

CREATE APPLICATION PACKAGE IF NOT EXISTS NVIDIA_NEMO_MS_APP_PKG;

USE DATABASE NVIDIA_NEMO_MS_APP_PKG;
CREATE SCHEMA IF NOT EXISTS CODE_SCHEMA;
CREATE STAGE IF NOT EXISTS APP_CODE_STAGE;

-- ##########  END INITIALIZATION   ######################################

SHOW IMAGE REPOSITORIES;

-- Copy the image repository URL and use it to push the image from Docker installed machine (AWS EC2 instance preferred) to Snowflake.
-- STOP HERE AND UPLOAD ALL REQUIRED CONTAINERS INTO THE IMAGE REPO
-- Follow steps in 'docker.md' to run the commands using docker installed machine (AWS EC2 instance preferred).
-- Continue below steps after all 4 images are pushed to snowflake image repository
