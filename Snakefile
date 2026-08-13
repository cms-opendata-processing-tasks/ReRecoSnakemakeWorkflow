import os

configfile: os.path.join(workflow.basedir, "config.yaml")

EVENTS = config.get("events", 10)
FILES_PER_JOB = config.get("files_per_job", 3)
FILES_AMOUNT = config.get("files_amount", 10)
IMAGE = config.get("image", "gitlab-registry.cern.ch/cms-cloud/cmssw-docker/cmssw_5_3_8_patch3-slc5_amd64_gcc462:latest")
EOS_PATH = config.get("eos_path", "root://eosuser.cern.ch//eos/eos/home-a/aalatalo/snakemaketest/HTCondor-processing")
GLOBAL_TAG = config.get("global_tag", "GR_P_V43F::All")
EOS_MGM_URL = config.get("eos_mgm_url", "root://eospublic.cern.ch")
input_file_list = config.get("input_file_list", "PAHighPt.txt")
output_file_name = input_file_list.split(".")[0]


inputfilepath = os.path.join(workflow.basedir, "files", input_file_list).replace(" ", "")
_all_files = open(inputfilepath).read().strip().split("\n")
_all_files = _all_files[:FILES_AMOUNT] if FILES_AMOUNT > 0 else _all_files 
FILE_CHUNKS = [_all_files[i:i+FILES_PER_JOB] for i in range(0, len(_all_files), FILES_PER_JOB)]
CHUNK_INDICES = list(range(len(FILE_CHUNKS)))

rule all:
    input:
        inputfilepath,
        expand(os.path.join(workflow.basedir, "filesProcessed_{chunk}.txt"), chunk=CHUNK_INDICES)

rule raw2reco:
    input:
        inputfilepath=inputfilepath,

    output:
        os.path.join(workflow.basedir, "filesProcessed_{chunk}.txt"),


    resources:
        compute_backend= "htcondorcern",
        htcondor_max_runtime= 'espresso',
        kerberos= True,
        environment= "LD_LIBRARY_PATH=/afs/cern.ch/user/a/aalatalo/snakemaketest/.pixi/envs/default/lib",  #needs CXXABI_1.3.15

    container:
        IMAGE

       
    shell:
        """
        FILEIN=$(awk "NR > {wildcards.chunk}*{FILES_PER_JOB} && NR <= ({wildcards.chunk}+1)*{FILES_PER_JOB}" \
            {inputfilepath} | sed 's|^|{EOS_MGM_URL}/|' | tr '\n' ',' | sed 's/,$//')

        
        #source /opt/cms/entrypoint.sh
        # set up the specific CMSSW release
        
        export SCRAM_ARCH=slc5_amd64_gcc462
        source /cvmfs/cms.cern.ch/cmsset_default.sh
        cmsrel CMSSW_5_3_8_HI_patch2
        cd CMSSW_5_3_8_HI_patch2/src
        cmsenv

        export http_proxy=http://ca-proxy.cern.ch:3128
        export https_proxy=http://ca-proxy.cern.ch:3128
        export FRONTIER_PROXY=http://ca-proxy.cern.ch:3128

        mkdir -p logs

        if [ ! -d "{EOS_PATH}/{output_file_name}/files" ]; then
            mkdir -p "{EOS_PATH}/{output_file_name}/files"
        fi

        if [ ! -d "{EOS_PATH}/{output_file_name}/logs" ]; then
            mkdir -p "{EOS_PATH}/{output_file_name}/logs"
        fi

        cmsDriver.py --process reRECO --scenario pp \
            -s RAW2DIGI,L1Reco,RECO,USER:EventFilter/HcalRawToDigi/hcallaserhbhehffilter2012_cff.hcallLaser2012Filter \
            --datatier RECO --data --eventcontent RECO \
            --customise Configuration/DataProcessing/RecoTLR.customisePromptHI \
            --conditions {GLOBAL_TAG} -n {EVENTS} --no_exec \
            --fileout file:{EOS_PATH}/{output_file_name}/files/{output_file_name}_reco_{wildcards.chunk}_htcond.root \
            --python reco_2013A_PAHighPt_hcalFilter.py \
            --filein=$FILEIN
        cmsRun reco_2013A_PAHighPt_hcalFilter.py 2>&1 | tee logs/reco_{wildcards.chunk}.log

        echo "Results written to {EOS_PATH}/{output_file_name}/files/{output_file_name}_reco_{wildcards.chunk}.root"
        
        cp logs/reco_{wildcards.chunk}.log {EOS_PATH}/{output_file_name}/logs/reco_{wildcards.chunk}.log
        
        echo "$FILEIN" | tr ',' '\n' >> {output}
        cp {output} {EOS_PATH}/{output_file_name}/logs/filesProcessed_{wildcards.chunk}.txt
       
        """