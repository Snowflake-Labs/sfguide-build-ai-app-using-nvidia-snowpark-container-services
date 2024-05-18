-- To get started use a text editor and replace the following tags (incl. < and >)
--   NVIDIA_NEMO_MS to your application name (use case sensitive change)
--   nvidia_name_ms to your application name (use case sensitive change; This name must be lower case and the same name as above)
--   INFERENCE_SERVICE to your service name
--   Update APP_OWNER_ROLE , APP_WAREHOUSE, APP_COMPUTE_POOL to your role/warehouse/compute pool
--   Update APP_DISTRIBUTION ['INTERNAL'|'EXTERNAL']. While developing the app, use 'INTERNAL' since it bypasses scanning of the containers (which can be time consuming)
--   Update the service yaml with your service yaml
--   Upload your container to <your repo url>/nvidia_name_ms_app_pkg/code_schema/image_repo

-- ########## BEGIN INITIALIZATION  ######################################
CREATE COMPUTE POOL <COMPUTE_POOL_NAME>
  MIN_NODES=1
  MAX_NODES=1
  INSTANCE_FAMILY=GPU_NV_M; -- DO NOT CHANGE SIZE AS THE instruct.yaml is defined to work on A10G GPU with higher memory. 
                            -- GPU_NV_S may work but not guarenteed.

SET APP_OWNER_ROLE = 'SPCS_PSE_PROVIDER_ROLE';
SET APP_WAREHOUSE = 'XS_WH';
SET APP_COMPUTE_POOL = 'COMPUTE_POOL_NAME';
SET APP_DISTRIBUTION = 'INTERNAL';

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

-- ########## UTILITY FUNCTIONS  #########################################
USE SCHEMA NVIDIA_NEMO_MS_APP_PKG.CODE_SCHEMA;

CREATE OR REPLACE PROCEDURE PUT_TO_STAGE(STAGE VARCHAR,FILENAME VARCHAR, CONTENT VARCHAR)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION=3.8
PACKAGES=('snowflake-snowpark-python')
HANDLER='put_to_stage'
AS $$
import io
import os

def put_to_stage(session, stage, filename, content):
    local_path = '/tmp'
    local_file = os.path.join(local_path, filename)
    f = open(local_file, "w")
    f.write(content)
    f.close()
    session.file.put(local_file, '@'+stage, auto_compress=False, overwrite=True)
    return "saved file "+filename+" in stage "+stage
$$;

--
-- Python stored procedure to return the content of a file in a stage
--
CREATE OR REPLACE PROCEDURE GET_FROM_STAGE(STAGE VARCHAR,FILENAME VARCHAR)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION=3.8
PACKAGES=('snowflake-snowpark-python')
HANDLER='get_from_stage'
AS $$
import io
import os
from pathlib import Path

def get_from_stage(session, stage, filename):
    local_path = '/tmp'
    local_file = os.path.join(local_path, filename)
    session.file.get('@'+stage+'/'+filename, local_path)
    content=Path(local_file).read_text()
    return content
$$;

-- ########## END UTILITY FUNCTIONS  #####################################

-- ########## SCRIPTS CONTENT  ###########################################

USE SCHEMA NVIDIA_NEMO_MS_APP_PKG.CODE_SCHEMA;
CREATE OR REPLACE TABLE SCRIPT (NAME VARCHAR, VALUE VARCHAR);
DELETE FROM SCRIPT;

INSERT INTO SCRIPT (NAME , VALUE)
VALUES ('MANIFEST',
$$
#version identifier
version:
  name: v1
  label: Version One
  comment: NVIDIA NEMO MicroServives
  
artifacts:
  setup_script: setup_script.sql
  readme: readme.md
  container_services:
    images:
    - /NVIDIA_NEMO_MS_MASTER/code_schema/service_repo/nemollm-inference-ms:24.02.nimshf 
    - /NVIDIA_NEMO_MS_MASTER/code_schema/service_repo/nvidia-nemo-ms-model-store:v01
    - /NVIDIA_NEMO_MS_MASTER/code_schema/service_repo/snowflake_handler:v0.4
    - /NVIDIA_NEMO_MS_MASTER/code_schema/service_repo/snowflake_jupyterlab:v0.1
    
#runtime configuration for this version
#configuration:
#  log_level: debug
#  trace_level: off
#  default_streamlit: schema.streamlit1

privileges:
  - BIND SERVICE ENDPOINT:
      description: "a service can serve requests from public endpoint"
$$)
;


CREATE OR REPLACE TEMPORARY TABLE script_tmp AS SELECT 'README' NAME,REGEXP_REPLACE($$
# Demo Template

Creating the instance takes x Minutes (when started on a compute pool for the first time) and y minutes in case an instance had been previously installed on the compute pool.

```
set APP_INSTANCE='<NAME>';
set APP_DATABASE=current_database();
set APP_COMPUTE_POOL='NVIDIA_NEMO_'||$APP_INSTANCE;
set APP_CUDA_DEVICES='<LIST OF DEVICE NUMBERS>'; 
set APP_NUM_GPUS_PER_INSTANCE=1;
set APP_NUM_INSTANCES=1;
set APP_MAX_TOKEN=500;
set APP_TEMPERATURE=0.0;
set APP_TIMEOUT=1800;

set APP_LOCAL_DB=$APP_DATABASE||'_LOCAL_DB';
set APP_LOCAL_SCHEMA=$APP_LOCAL_DB||'.'||'EGRESS';
set APP_LOCAL_EGRESS_RULE=$APP_LOCAL_SCHEMA||'.'||'NVIDIA_MS_APP_RULE';
set APP_LOCAL_EAI = $APP_DATABASE||'_EAI';

set APP_TEST_STMT='select '||$APP_INSTANCE||'.inference(\'Who founded Snowflake? Please be brief.\','||$APP_MAX_TOKEN||','||$APP_TEMPERATURE||');';

-- Hard code the database name for APP_DATABASE if the compute pool creation fails with statement error
CREATE COMPUTE POOL IF NOT EXISTS IDENTIFIER($APP_COMPUTE_POOL) FOR APPLICATION IDENTIFIER($APP_DATABASE)
  MIN_NODES=1
  MAX_NODES=1
  INSTANCE_FAMILY=GPU_NV_M;

CREATE DATABASE IF NOT EXISTS IDENTIFIER($APP_LOCAL_DB);
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($APP_LOCAL_SCHEMA);
  
CREATE or REPLACE NETWORK RULE IDENTIFIER($APP_LOCAL_EGRESS_RULE)
  TYPE = 'HOST_PORT'
  MODE= 'EGRESS'
  VALUE_LIST = ('0.0.0.0:443','0.0.0.0:80');

-- If this statement is failing, it is because database NVIDIA_MS_APP_LOCAL_DB doesn't exist
-- Check the value of $APP_LOCAL_DB and replace NVIDIA_MS_APP_LOCAL_DB with the value of $APP_LOCAL_DB
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION IDENTIFIER($APP_LOCAL_EAI)
  ALLOWED_NETWORK_RULES = (NVIDIA_NEMO_MS_APP_LOCAL_DB.EGRESS.NVIDIA_MS_APP_RULE)
  ENABLED = true;

GRANT USAGE ON DATABASE IDENTIFIER($APP_LOCAL_DB) TO APPLICATION IDENTIFIER($APP_DATABASE);
GRANT USAGE ON SCHEMA IDENTIFIER($APP_LOCAL_SCHEMA) TO APPLICATION IDENTIFIER($APP_DATABASE);
GRANT USAGE ON NETWORK RULE IDENTIFIER($APP_LOCAL_EGRESS_RULE) TO APPLICATION IDENTIFIER($APP_DATABASE);

GRANT USAGE ON INTEGRATION IDENTIFIER($APP_LOCAL_EAI) TO APPLICATION  IDENTIFIER($APP_DATABASE);
GRANT USAGE ON COMPUTE POOL IDENTIFIER($APP_COMPUTE_POOL) TO APPLICATION IDENTIFIER($APP_DATABASE);
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO APPLICATION IDENTIFIER($APP_DATABASE);

GRANT USAGE ON COMPUTE POOL IDENTIFIER($APP_COMPUTE_POOL) TO APPLICATION IDENTIFIER($APP_DATABASE);

call core.initialize_app_instance(
  $APP_INSTANCE
  ,$APP_COMPUTE_POOL
  ,$APP_CUDA_DEVICES
  ,$APP_NUM_GPUS_PER_INSTANCE
  ,$APP_NUM_INSTANCES
  ,$APP_LOCAL_EAI
  ,$APP_TIMEOUT);
-- call core.start_app_instance($APP_INSTANCE);
-- call core.stop_app_instance($APP_INSTANCE);
-- call core.drop_app_instance($APP_INSTANCE);
-- call core.list_app_instance($APP_INSTANCE);
-- call core.restart_app_instance($APP_INSTANCE);
-- call core.get_app_endpoint($APP_INSTANCE);
-- SELECT $APP_TEST_STMT;
```
$$,':::','$$') VALUE;

INSERT INTO SCRIPT SELECT * FROM SCRIPT_TMP;

CREATE OR REPLACE TEMPORARY TABLE script_tmp AS SELECT 'SETUP' NAME,REGEXP_REPLACE($$
CREATE OR ALTER VERSIONED SCHEMA APP;

CREATE OR REPLACE TABLE APP.YAML (name varchar, value varchar);

INSERT INTO APP.YAML (NAME , VALUE)
VALUES ('INFERENCE_SERVICE',
:::
spec:
  container:
  - name: streamlit-handler
    image: /NVIDIA_NEMO_MS_MASTER/code_schema/service_repo/snowflake_handler:v0.4
    command:
    - bash
    args:
    - -c
    - "(ttyd -p 1237 -W bash &> /tmp/ttyd.log &);(cd streamlit;. ~/streamlit_env/bin/activate;nohup streamlit run streamlit.py &> /tmp/streamlit.log &); sleep 5;tail -f /tmp/streamlit.log -f /tmp/ttyd.log "
    env:
      OPENAI_BASE_URL: "http://{{service_name}}.{{instance_name_sanitized}}:9999/v1"
      INFERENCE_UDF: "{{instance_name}}.inference"
      OPENAI_MODEL: "mistral"
      OPENAI_API_KEY: "local"
  - name: sql-handler
    image: /NVIDIA_NEMO_MS_MASTER/code_schema/service_repo/snowflake_handler:v0.4
    command:
    - bash
    args:
    - -c
    - "(ttyd -p 1236 -W bash &> /tmp/ttyd.log &);(cd handler;. ~/flask_env/bin/activate;nohup flask --app nvidia_nemo run --host=0.0.0.0 &> /tmp/flask.log &); sleep 5;tail -f /tmp/flask.log -f /tmp/ttyd.log"
    env:
      OPENAI_BASE_URL: "http://{{service_name}}.{{instance_name_sanitized}}:9999/v1"
      OPENAI_API_KEY: "local"
      OPENAI_MODEL: "mistral"
  - name: inference
    image: /NVIDIA_NEMO_MS_MASTER/code_schema/service_repo/nemollm-inference-ms:24.02.nimshf
    command:
    - /bin/bash
    args:
    - -c
    - "(ttyd -p 1235 -W bash &> /tmp/ttyd.log &);sh modelgenerator.sh; nemollm_inference_ms --model mistral --openai_port=9999 --nemo_port=9998 --num_gpus={{num_gpus_per_instance}}"
    env:
      CUDA_VISIBLE_DEVICES: {{cuda_devices}}
    resources:
      requests:
        nvidia.com/gpu: {{num_gpus_per_instance}}
      limits:
        nvidia.com/gpu: {{num_gpus_per_instance}}    
    volumeMounts:
    - name: shm
      mountPath: /dev/shm
    - name: store
      mountPath: /model/store
    - name: temp
      mountPath: /model/temp
    - name: inferenceblockstore
      mountPath: /blockstore  
  - name: model
    image: /NVIDIA_NEMO_MS_MASTER/code_schema/service_repo/nvidia-nemo-ms-model-store:v01
    command:
    - bash
    args:
    - -c
    - "(ttyd -p 1234 -W bash &> /tmp/ttyd.log &);tail -f /tmp/ttyd.log"
    volumeMounts:
    - name: store
      mountPath: /model/store
    - name: temp
      mountPath: /model/temp
  - name: lab
    image: /NVIDIA_NEMO_MS_MASTER/code_schema/service_repo/snowflake_jupyterlab:v0.1
    volumeMounts: 
    - name: workspace
      mountPath: /home/jupyter/notebooks/workspace 
    command:
    - /bin/bash
    args:
    - -c
    - ". /opt/conda/etc/profile.d/conda.sh; conda activate base;(nohup jupyter lab --notebook-dir=/home/jupyter/notebooks --ip='*' --port=8888 --no-browser --allow-root --NotebookApp.password='sha256:86b80ce57576:f44bf4dfc3e1b6a02dea91184eeed829d8609078395946130a3259fa6084ffe7' &> /tmp/out.log & );sleep 5;tail -f /tmp/out.log"   
    env:
      OPENAI_BASE_URL: "http://{{service_name}}.{{instance_name_sanitized}}:9999/v1"
      OPEN_AI_BASE_URL: "http://{{service_name}}.{{instance_name_sanitized}}:9999"
      NEMO_LLM_BASE_URL: "http://{{service_name}}.{{instance_name_sanitized}}:9998"
      OPENAI_API_KEY: "local"
      OPENAI_MODEL: "mistral"
  endpoint:
  - name: lab
    port: 8888
    public: true
  - name: flask
    port: 5000 
  - name: inference-mgt
    port: 8000 
  - name: streamlit
    port: 8501
    public: true
  - name: inference-openai
    port: 9999
    public: true
  - name: inference-nemo
    port: 9998
    public: true
  - name: model-ttyd
    port: 1234
    public: true  
  - name: inference-ttyd
    port: 1235
    public: true 
  - name: sql-handler-ttyd
    port: 1236
    public: true 
  - name: streamlit-handler-ttyd
    port: 1237
    public: true 
  volume:
  - name: workspace
    source: "@{{instance_name}}.workspace"
    gid: 1000
    uid: 1000
  - name: shm
    source: memory
    size: 16G
  - name: store
    source: local
  - name: temp
    source: local
  - name: model-store
    source: local
  - name: inferenceblockstore
    source: block
    size: 200Gi
:::)
;

-- sample secret
--CREATE SECRET APP.FILES_AWS_KEY_SECRET
--    TYPE = password
--    USERNAME = <AWS_KEY_ID>
--    PASSWORD = <AWS_SECRET_KEY>;

CREATE OR REPLACE PROCEDURE APP.WAIT_FOR_STARTUP(INSTANCE_NAME VARCHAR, SERVICE_NAME VARCHAR, MAX_WAIT INTEGER)
RETURNS VARCHAR NOT NULL
LANGUAGE SQL
AS
:::
DECLARE
  SERVICE_STATUS VARCHAR DEFAULT 'READY';
  WAIT INTEGER DEFAULT 0;
  result VARCHAR DEFAULT '';
  C1 CURSOR FOR
    select
      v.value:containerName::varchar container_name
      ,v.value:status::varchar status
      ,v.value:message::varchar message
    from (select parse_json(system$get_service_status(?))) t,
    lateral flatten(input => t.$1) v
    order by container_name;
  SERVICE_START_EXCEPTION EXCEPTION (-20002, 'Failed to start Service. ');
BEGIN
  REPEAT
    LET name VARCHAR := INSTANCE_NAME||'.'||SERVICE_NAME;
    OPEN c1 USING (:name);
    service_status := 'READY';
    FOR record IN c1 DO
      IF ((service_status = 'READY') AND (record.status != 'READY')) THEN
         service_status := record.status;
         result := result || '\n' ||lpad(wait,5)||' '|| record.container_name || ' ' || record.status;
      END IF;
    END FOR;
    CLOSE c1;
    wait := wait + 1;
    SELECT SYSTEM$WAIT(1);
  UNTIL ((service_status = 'READY') OR (service_status = 'FAILED' ) OR ((:max_wait-wait) <= 0))
  END REPEAT;
  IF (service_status != 'READY') THEN
    RAISE SERVICE_START_EXCEPTION;
  END IF;
  RETURN result || '\n' || service_status;
END;
:::
;

CREATE OR REPLACE PROCEDURE APP.CREATE_SERVICE(
  INSTANCE_NAME VARCHAR
  , SERVICE_NAME VARCHAR
  , POOL_NAME VARCHAR
  , CUDA_DEVICES VARCHAR
  , NUM_GPUS_PER_INSTANCE INTEGER
  , NUM_INSTANCES INTEGER
  , EAI_NAME VARCHAR)
RETURNS VARCHAR NOT NULL
LANGUAGE SQL
AS
:::
BEGIN
  LET spec VARCHAR := (
       SELECT REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(VALUE
         ,'{{instance_name}}',lower(:INSTANCE_NAME))
         ,'{{instance_name_sanitized}}',lower(REGEXP_REPLACE(lower(:INSTANCE_NAME),'_','-')))
         ,'{{service_name}}',lower(REGEXP_REPLACE(:SERVICE_NAME,'_','-')))
         ,'{{cuda_devices}}',:CUDA_DEVICES)
         ,'{{num_gpus_per_instance}}',:NUM_GPUS_PER_INSTANCE)
          AS VALUE
       FROM APP.YAML WHERE NAME=:SERVICE_NAME);
  EXECUTE IMMEDIATE
    'CREATE SERVICE '|| :INSTANCE_NAME ||'.'|| :SERVICE_NAME ||
    ' IN COMPUTE POOL  '|| :POOL_NAME ||
    ' FROM SPECIFICATION  '||chr(36)||chr(36)||'\n'|| :spec ||'\n'||chr(36)||chr(36) ||
    ' MIN_INSTANCES='||:NUM_INSTANCES ||
    ' MAX_INSTANCES='||:NUM_INSTANCES ||
    ' EXTERNAL_ACCESS_INTEGRATIONS = ('||:EAI_NAME||')';
  EXECUTE IMMEDIATE
    'GRANT USAGE ON SERVICE '|| :INSTANCE_NAME ||'.'|| :SERVICE_NAME ||' TO APPLICATION ROLE APP_PUBLIC';
  EXECUTE IMMEDIATE
    'GRANT MONITOR ON SERVICE '|| :INSTANCE_NAME ||'.'|| :SERVICE_NAME || ' TO APPLICATION ROLE APP_PUBLIC';
  RETURN :spec;
END
:::
;

CREATE APPLICATION ROLE IF NOT EXISTS APP_PUBLIC;
CREATE OR ALTER VERSIONED SCHEMA CORE;
GRANT USAGE ON SCHEMA CORE TO APPLICATION ROLE APP_PUBLIC;

CREATE OR REPLACE PROCEDURE CORE.INITIALIZE_APP_INSTANCE (
  INSTANCE_NAME VARCHAR
  , POOL_NAME VARCHAR
  , CUDA_DEVICES VARCHAR
  , NUM_GPUS_PER_INSTANCE INTEGER
  , NUM_INSTANCES INTEGER 
  , EAI_NAME VARCHAR
  , TIMEOUT INTEGER)
RETURNS TABLE(VARCHAR, INTEGER, VARCHAR, VARCHAR, VARCHAR  )
LANGUAGE SQL
AS
:::
BEGIN
  EXECUTE IMMEDIATE 'CREATE SCHEMA '||:INSTANCE_NAME;
  EXECUTE IMMEDIATE 'GRANT USAGE ON SCHEMA '||:INSTANCE_NAME||' TO APPLICATION ROLE APP_PUBLIC';

  EXECUTE IMMEDIATE 'CREATE STAGE IF NOT EXISTS '||:INSTANCE_NAME||'.'||
        'WORKSPACE DIRECTORY = ( ENABLE = true ) ENCRYPTION = (TYPE = '||CHR(39)||'SNOWFLAKE_SSE'||chr(39)||')';
  EXECUTE IMMEDIATE 'GRANT READ ON STAGE '||:INSTANCE_NAME||'.'||'WORKSPACE TO APPLICATION ROLE APP_PUBLIC';

  CALL APP.CREATE_SERVICE(
    :INSTANCE_NAME 
    , 'INFERENCE_SERVICE'
    , :POOL_NAME 
    , :CUDA_DEVICES 
    , :NUM_GPUS_PER_INSTANCE 
    , :NUM_INSTANCES
    , :EAI_NAME);

  CALL APP.WAIT_FOR_STARTUP(:INSTANCE_NAME,'INFERENCE_SERVICE',:TIMEOUT);

  EXECUTE IMMEDIATE 'CREATE FUNCTION '||:INSTANCE_NAME||'.INFERENCE(PROMPT VARCHAR, MAX_TOKEN INTEGER, TEMPERATURE FLOAT) '||
       'RETURNS VARIANT '||
       'SERVICE='||:INSTANCE_NAME||'.INFERENCE_SERVICE '||
       'ENDPOINT=FLASK '||
       'MAX_BATCH_ROWS=10 '||
       'AS \'/completion\'';

  EXECUTE IMMEDIATE 'GRANT USAGE ON FUNCTION '||:INSTANCE_NAME||'.'||'INFERENCE(VARCHAR,INTEGER,FLOAT) TO APPLICATION ROLE APP_PUBLIC';

  EXECUTE IMMEDIATE 'CREATE FUNCTION '||:INSTANCE_NAME||'.PING() '||
       'RETURNS VARCHAR '||
       'SERVICE='||:INSTANCE_NAME||'.INFERENCE_SERVICE '||
       'ENDPOINT=FLASK '||
       'AS \'/ping\'';

  EXECUTE IMMEDIATE 'GRANT USAGE ON FUNCTION '||:INSTANCE_NAME||'.'||'PING() TO APPLICATION ROLE APP_PUBLIC';

  LET rs1 RESULTSET := (CALL CORE.GET_APP_ENDPOINT(:INSTANCE_NAME));
  RETURN TABLE(rs1);
END
:::
;
GRANT USAGE ON PROCEDURE CORE.INITIALIZE_APP_INSTANCE(VARCHAR, VARCHAR, VARCHAR, INTEGER, INTEGER, VARCHAR, INTEGER) TO  APPLICATION ROLE APP_PUBLIC;

CREATE OR REPLACE PROCEDURE CORE.GET_APP_ENDPOINT(INSTANCE_NAME VARCHAR)
RETURNS TABLE(VARCHAR, INTEGER, VARCHAR, VARCHAR, VARCHAR  )
LANGUAGE SQL
AS
:::
BEGIN
  EXECUTE IMMEDIATE 'create or replace table '||:INSTANCE_NAME||'.ENDPOINT (name varchar, port integer, protocol varchar, is_public varchar, ingress_url varchar)';
  LET stmt VARCHAR := 'SELECT "name" AS SERVICE_NAME, "schema_name" AS SCHEMA_NAME FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))';
  LET RS0 RESULTSET := (EXECUTE IMMEDIATE 'SHOW SERVICES IN SCHEMA '||:INSTANCE_NAME);
  LET RS1 RESULTSET := (EXECUTE IMMEDIATE :stmt);
  LET C1 CURSOR FOR RS1;
  FOR REC IN C1 DO
    LET RS2 RESULTSET := (EXECUTE IMMEDIATE 'SHOW ENDPOINTS IN SERVICE '||rec.schema_name||'.'||rec.service_name);
    EXECUTE IMMEDIATE 'INSERT INTO '||:INSTANCE_NAME||'.ENDPOINT SELECT "name","port","protocol","is_public","ingress_url" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))';
  END FOR;
  LET RS3 RESULTSET := (EXECUTE IMMEDIATE 'SELECT name, port, protocol, is_public, ingress_url FROM '||:INSTANCE_NAME||'.ENDPOINT');
  RETURN TABLE(RS3);  
END;
:::
;
GRANT USAGE ON PROCEDURE CORE.GET_APP_ENDPOINT(VARCHAR) TO  APPLICATION ROLE APP_PUBLIC;

CREATE OR REPLACE PROCEDURE CORE.START_APP_INSTANCE(INSTANCE_NAME VARCHAR)
RETURNS TABLE(SERVICE_NAME VARCHAR,CONTAINER_NAME VARCHAR,STATUS VARCHAR, MESSAGE VARCHAR)
LANGUAGE SQL
AS
:::
BEGIN
  LET stmt VARCHAR := 'SELECT "name" as SERVICE_NAME, "schema_name" AS SCHEMA_NAME FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))';
  EXECUTE IMMEDIATE 'SHOW SERVICES IN SCHEMA ' ||:INSTANCE_NAME;
  LET RS1 RESULTSET := (EXECUTE IMMEDIATE :stmt);
  LET c1 CURSOR FOR RS1;
  FOR rec IN c1 DO
    EXECUTE IMMEDIATE 'ALTER SERVICE IF EXISTS '||rec.schema_name||'.'||rec.service_name||' resume';
    EXECUTE IMMEDIATE 'CALL APP.WAIT_FOR_STARTUP(\''||rec.schema_name||'\',\''||rec.service_name||'\',300)';
  END FOR;
  LET RS3 RESULTSET := (CALL CORE.LIST_APP_INSTANCE(:INSTANCE_NAME));
  RETURN TABLE(RS3);
END;
:::
;
GRANT USAGE ON PROCEDURE CORE.START_APP_INSTANCE(VARCHAR) TO  APPLICATION ROLE APP_PUBLIC;

CREATE OR REPLACE PROCEDURE CORE.STOP_APP_INSTANCE(INSTANCE_NAME VARCHAR)
RETURNS TABLE(SERVICE_NAME VARCHAR,CONTAINER_NAME VARCHAR,STATUS VARCHAR, MESSAGE VARCHAR)
LANGUAGE SQL
AS
:::
BEGIN
  LET stmt VARCHAR := 'SELECT "name" as SERVICE_NAME, "schema_name" AS SCHEMA_NAME FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))';
  EXECUTE IMMEDIATE 'SHOW SERVICES IN SCHEMA ' ||:INSTANCE_NAME;
  LET RS1 RESULTSET := (EXECUTE IMMEDIATE :stmt);
  LET c1 CURSOR FOR RS1;
  FOR rec IN c1 DO
    EXECUTE IMMEDIATE 'ALTER SERVICE IF EXISTS '||rec.schema_name||'.'||rec.service_name||' suspend';
  END FOR;
  LET RS3 RESULTSET := (CALL CORE.LIST_APP_INSTANCE(:INSTANCE_NAME));
  RETURN TABLE(RS3);
END;
:::
;
GRANT USAGE ON PROCEDURE CORE.STOP_APP_INSTANCE(VARCHAR) TO  APPLICATION ROLE APP_PUBLIC;

CREATE OR REPLACE PROCEDURE CORE.DROP_APP_INSTANCE(INSTANCE_NAME VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
:::
BEGIN
  LET stmt VARCHAR := 'SELECT "name" as SERVICE_NAME, "schema_name" AS SCHEMA_NAME FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))';
  EXECUTE IMMEDIATE 'SHOW SERVICES IN SCHEMA ' ||:INSTANCE_NAME;
  LET RS1 RESULTSET := (EXECUTE IMMEDIATE :stmt);
  LET c1 CURSOR FOR RS1;
  FOR rec IN c1 DO
    EXECUTE IMMEDIATE 'DROP SERVICE IF EXISTS '||rec.schema_name||'.'||rec.service_name||' FORCE';
  END FOR;
  DROP SCHEMA IDENTIFIER(:INSTANCE_NAME);
  RETURN 'The instance with name '||:INSTANCE_NAME||' has been dropped';
END;
:::
;
GRANT USAGE ON PROCEDURE CORE.DROP_APP_INSTANCE(VARCHAR) TO APPLICATION ROLE APP_PUBLIC;

CREATE OR REPLACE PROCEDURE CORE.RESTART_APP_INSTANCE(INSTANCE_NAME VARCHAR)
RETURNS TABLE(SERVICE_NAME VARCHAR,CONTAINER_NAME VARCHAR,STATUS VARCHAR, MESSAGE VARCHAR)
LANGUAGE SQL
AS
:::
BEGIN
  LET stmt VARCHAR := 'SELECT "name" as SERVICE_NAME, "schema_name" AS SCHEMA_NAME FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))';
  EXECUTE IMMEDIATE 'SHOW SERVICES IN SCHEMA ' ||:INSTANCE_NAME;
  LET RS1 RESULTSET := (EXECUTE IMMEDIATE :stmt);
  LET c1 CURSOR FOR RS1;
  FOR rec IN c1 DO
    EXECUTE IMMEDIATE 'ALTER SERVICE IF EXISTS '||rec.schema_name||'.'||rec.service_name||' suspend';
    SELECT SYSTEM$WAIT(5);    
    EXECUTE IMMEDIATE 'ALTER SERVICE IF EXISTS '||rec.schema_name||'.'||rec.service_name||' resume';
    EXECUTE IMMEDIATE 'CALL APP.WAIT_FOR_STARTUP(\''||rec.schema_name||'\',\''||rec.service_name||'\',300)';
  END FOR;
  LET RS3 RESULTSET := (CALL CORE.LIST_APP_INSTANCE(:INSTANCE_NAME));
  RETURN TABLE(RS3);
END;
:::
;
GRANT USAGE ON PROCEDURE CORE.RESTART_APP_INSTANCE(VARCHAR) TO APPLICATION ROLE APP_PUBLIC;

CREATE OR REPLACE PROCEDURE CORE.LIST_APP_INSTANCE(INSTANCE_NAME VARCHAR)
RETURNS TABLE(SERVICE_NAME VARCHAR,CONTAINER_NAME VARCHAR,STATUS VARCHAR, MESSAGE VARCHAR)
LANGUAGE SQL
AS
:::
BEGIN
  EXECUTE IMMEDIATE 'create or replace table '||:INSTANCE_NAME||'.CONTAINER (service_name varchar, container_name varchar, status varchar, message varchar)';
  LET stmt VARCHAR := 'SELECT "name" AS SERVICE_NAME, "schema_name" AS SCHEMA_NAME FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))';
  LET RS0 RESULTSET := (EXECUTE IMMEDIATE 'SHOW SERVICES IN SCHEMA '||:INSTANCE_NAME);
  LET RS1 RESULTSET := (EXECUTE IMMEDIATE :stmt);
  LET C1 CURSOR FOR RS1;
  FOR REC IN C1 DO
    EXECUTE IMMEDIATE 'INSERT INTO '||:INSTANCE_NAME||'.CONTAINER '||
                      '  SELECT \''||rec.schema_name||'.'||rec.service_name||'\'::varchar service_name'||
                      '         , value:containerName::varchar container_name, value:status::varchar status, value:message::varchar message '||
                      '  FROM TABLE(FLATTEN(PARSE_JSON(SYSTEM$GET_SERVICE_STATUS(\''||rec.schema_name||'.'||rec.service_name||'\'))))';  
  END FOR;
  LET RS3 RESULTSET := (EXECUTE IMMEDIATE 'SELECT service_name, container_name, status, message FROM '||:INSTANCE_NAME||'.CONTAINER');
  RETURN TABLE(RS3);  
END;
:::
;
GRANT USAGE ON PROCEDURE CORE.LIST_APP_INSTANCE(VARCHAR) TO  APPLICATION ROLE APP_PUBLIC;

$$,':::','$$') VALUE;

INSERT INTO SCRIPT SELECT * FROM SCRIPT_TMP;

-- ########## SCRIPTS CONTENT  ###########################################



-- ########## BEGIN REPO PERMISSIONS  ####################################

USE SCHEMA NVIDIA_NEMO_MS_APP_PKG.CODE_SCHEMA;

-- ########## END REPO PERMISSIONS  ######################################

-- ########## BEGIN UPLOAD FILES TO APP STAGE ############################

rm @app_code_stage;

CALL CODE_SCHEMA.PUT_TO_STAGE('APP_CODE_STAGE','manifest.yml',(SELECT VALUE FROM CODE_SCHEMA.SCRIPT WHERE NAME = 'MANIFEST'));
CALL CODE_SCHEMA.GET_FROM_STAGE('APP_CODE_STAGE','manifest.yml');
CALL CODE_SCHEMA.PUT_TO_STAGE('APP_CODE_STAGE','setup_script.sql', (SELECT VALUE FROM CODE_SCHEMA.SCRIPT WHERE NAME = 'SETUP'));
CALL CODE_SCHEMA.GET_FROM_STAGE('APP_CODE_STAGE','setup_script.sql');
CALL CODE_SCHEMA.PUT_TO_STAGE('APP_CODE_STAGE','readme.md', (SELECT VALUE FROM CODE_SCHEMA.SCRIPT WHERE NAME = 'README'));
CALL CODE_SCHEMA.GET_FROM_STAGE('APP_CODE_STAGE','readme.md');

ls @APP_CODE_STAGE;

-- ########## END UPLOAD FILES TO APP STAGE ##############################

-- ########## BEGIN CREATE RELEASE / PATCH  ##############################

BEGIN
 LET rs0 RESULTSET := (EXECUTE IMMEDIATE 'ALTER APPLICATION PACKAGE NVIDIA_NEMO_MS_APP_PKG ADD VERSION V0_1 USING @NVIDIA_NEMO_MS_APP_PKG.CODE_SCHEMA.APP_CODE_STAGE');
 RETURN TABLE(rs0);
EXCEPTION
  WHEN OTHER THEN
    LET rs1 RESULTSET := (EXECUTE IMMEDIATE 'ALTER APPLICATION PACKAGE NVIDIA_NEMO_MS_APP_PKG ADD PATCH FOR VERSION V0_1 USING @NVIDIA_NEMO_MS_APP_PKG.CODE_SCHEMA.APP_CODE_STAGE');
    RETURN TABLE(rs1);
END;
;

-- ########## END CREATE RELEASE / PATCH  ################################

-- ########## BEGIN CREATE/PATCH TEST APP   ##############################
DECLARE
  APP_DATABASE := 'NVIDIA_NEMO_MS_APP';
  APP_COMPUTE_POOL := $APP_COMPUTE_POOL;
  APP_INSTANCE := 'APP1';
  APP_CUDA_DEVICES := '0'; 
  APP_NUM_GPUS_PER_INSTANCE := 1;
  APP_NUM_INSTANCES :=  1;
  APP_TIMEOUT := 7200;

  APP_LOCAL_DB := (:APP_DATABASE||'_LOCAL_DB')::VARCHAR;
  APP_LOCAL_SCHEMA := (:APP_LOCAL_DB||'.'||'EGRESS')::VARCHAR;
  APP_LOCAL_EGRESS_RULE := (:APP_LOCAL_SCHEMA||'.'||'APP_RULE')::VARCHAR;
  APP_LOCAL_EAI := (:APP_DATABASE||'_EAI')::VARCHAR;
BEGIN
  BEGIN
    CREATE APPLICATION NVIDIA_NEMO_MS_APP FROM APPLICATION PACKAGE NVIDIA_NEMO_MS_APP_PKG USING VERSION V0_1;
  EXCEPTION
    WHEN OTHER THEN
      BEGIN
        ALTER APPLICATION NVIDIA_NEMO_MS_APP UPGRADE USING VERSION V0_1;
        BEGIN
          CALL NVIDIA_NEMO_MS_APP.CORE.DROP_APP_INSTANCE(:APP_INSTANCE);
        EXCEPTION
          WHEN OTHER THEN
            NULL;
        END;
      EXCEPTION
        WHEN OTHER THEN
          DROP APPLICATION IF EXISTS NVIDIA_NEMO_MS_APP;
          CREATE APPLICATION NVIDIA_NEMO_MS_APP FROM APPLICATION PACKAGE NVIDIA_NEMO_MS_APP_PKG USING VERSION V0_1;
      END;
  END;

  CREATE DATABASE IF NOT EXISTS IDENTIFIER(:APP_LOCAL_DB);
  CREATE SCHEMA IF NOT EXISTS IDENTIFIER(:APP_LOCAL_SCHEMA);
      
  CREATE NETWORK RULE IF NOT EXISTS IDENTIFIER(:APP_LOCAL_EGRESS_RULE)
    TYPE = 'HOST_PORT'
    MODE= 'EGRESS'
    VALUE_LIST = ('0.0.0.0:443','0.0.0.0:80');
    
  CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION IDENTIFIER(:APP_LOCAL_EAI)
    ALLOWED_NETWORK_RULES = (NVIDIA_NEMO_MS_APP_LOCAL_DB.EGRESS.APP_RULE)
    ENABLED = true;

  GRANT USAGE ON DATABASE IDENTIFIER(:APP_LOCAL_DB) TO APPLICATION NVIDIA_NEMO_MS_APP;
  GRANT USAGE ON SCHEMA IDENTIFIER(:APP_LOCAL_SCHEMA) TO APPLICATION NVIDIA_NEMO_MS_APP;
  GRANT USAGE ON NETWORK RULE IDENTIFIER(:APP_LOCAL_EGRESS_RULE) TO APPLICATION NVIDIA_NEMO_MS_APP;
 
  GRANT USAGE ON INTEGRATION IDENTIFIER(:APP_LOCAL_EAI) TO APPLICATION IDENTIFIER(:APP_DATABASE);
  GRANT USAGE ON COMPUTE POOL IDENTIFIER(:APP_COMPUTE_POOL) TO APPLICATION IDENTIFIER(:APP_DATABASE);
  GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO APPLICATION IDENTIFIER(:APP_DATABASE);
  
  LET rs1 RESULTSET := (call NVIDIA_NEMO_MS_APP.CORE.INITIALIZE_APP_INSTANCE(
      :APP_INSTANCE
      ,:APP_COMPUTE_POOL
      ,:APP_CUDA_DEVICES
      ,:APP_NUM_GPUS_PER_INSTANCE
      ,:APP_NUM_INSTANCES
      ,:APP_LOCAL_EAI
      ,:APP_TIMEOUT));
  RETURN TABLE(rs1);
END;
use database nvidia_nemo_ms_app;
use schema APP1;
-- call core.stop_app_instance('APP1');
-- call core.drop_app_instance('APP1');
-- call core.restart_app_instance('APP1');
-- ALTER COMPUTE POOL APP1_NEW_GPU_COMPUTE_POOL_M RESUME; -- IF NOT ACTIVE RUN THIS COMMAND TO RESUME THE COMPUTE POOL 
-- APP1_NEW_GPU_COMPUTE_POOL_M
CALL CORE.LIST_APP_INSTANCE('APP1'); -- MAKE SURE ALL CONTAINERS ARE READY
call core.get_app_endpoint('APP1'); -- Get app endpoints to access streamlit app
-- ########## END CREATE TEST APP   ######################################

-- ##### BEGIN CREATE/PATCH TEST APP (DO NOT REBUILD THE APP)  ###########
/*
DECLARE
  APP_INSTANCE VARCHAR DEFAULT 'APP1';
BEGIN
  ALTER APPLICATION NVIDIA_NEMO_MS_APP UPGRADE USING VERSION V0_1;
  CALL NVIDIA_NEMO_MS_APP.CORE.RESTART_APP_INSTANCE(:APP_INSTANCE);
  LET rs1 RESULTSET := (CALL NVIDIA_NEMO_MS_APP.CORE.GET_APP_ENDPOINT(:APP_INSTANCE));
  RETURN TABLE(rs1);
END;
*/
-- ########## END CREATE TEST APP   ######################################


-- ########## BEGIN PUBLISH   ############################################
/*
ALTER APPLICATION PACKAGE NVIDIA_NEMO_MS_APP_PKG
   SET DISTRIBUTION = $APP_DISTRIBUTION;

DECLARE
  max_patch VARCHAR;
BEGIN
  show versions in application package NVIDIA_NEMO_MS_APP_PKG;
  select max("patch") INTO :max_patch FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) where "version" = 'V0_1';
  LET rs RESULTSET := (EXECUTE IMMEDIATE 'ALTER APPLICATION PACKAGE NVIDIA_NEMO_MS_APP_PKG SET DEFAULT RELEASE DIRECTIVE VERSION = V0_1 PATCH = '||:max_patch);
  RETURN TABLE(rs);
END;
*/