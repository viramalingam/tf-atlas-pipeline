version 1.0

task run_mean_shap {
    input {
        Array [File]? counts_shap
        Array [File]? profile_shap
        File chrom_sizes
        File peaks
        Int? mem_gb
    }
    
    command {
        #create data directories and download scripts
        
        cd /; mkdir my_scripts
        cd /my_scripts
        git clone --depth 1 --branch v2.1.0-rc.7 https://github.com/viramalingam/tf-atlas-pipeline.git
        chmod -R 777 tf-atlas-pipeline
        cd tf-atlas-pipeline/anvil/shap/
        
        ##mean shap
        
        echo "python /my_scripts/tf-atlas-pipeline/anvil/shap/mean_shap.py" --counts_shaps ${sep=',' counts_shap} --profile_shaps ${sep=',' profile_shap}
        python /my_scripts/tf-atlas-pipeline/anvil/shap/mean_shap.py --counts_shaps ${sep=',' counts_shap} --profile_shaps ${sep=',' profile_shap}
        
        echo "python /my_scripts/tf-atlas-pipeline/anvil/shap/importance_hdf5_to_bigwig.py" -h5 /cromwell_root/profile_mean_shap_scores.h5 -c ${chrom_sizes} -r ${peaks} -o /cromwell_root/profile_mean_shap_scores.bw -s /cromwell_root/profile_mean_shap_scores.stats.txt --gzipped
        
        python /my_scripts/tf-atlas-pipeline/anvil/shap/importance_hdf5_to_bigwig.py -h5 /cromwell_root/profile_mean_shap_scores.h5 -c ${chrom_sizes} -r ${peaks} -o /cromwell_root/profile_mean_shap_scores.bw -s /cromwell_root/profile_mean_shap_scores.stats.txt --gzipped
        
        echo "python /my_scripts/tf-atlas-pipeline/anvil/shap/importance_hdf5_to_bigwig.py" -h5 /cromwell_root/counts_mean_shap_scores.h5 -c ${chrom_sizes} -r ${peaks} -o /cromwell_root/counts_mean_shap_scores.bw -s /cromwell_root/counts_mean_shap_scores.stats.txt --gzipped
        
        python /my_scripts/tf-atlas-pipeline/anvil/shap/importance_hdf5_to_bigwig.py -h5 /cromwell_root/counts_mean_shap_scores.h5 -c ${chrom_sizes} -r ${peaks} -o /cromwell_root/counts_mean_shap_scores.bw -s /cromwell_root/counts_mean_shap_scores.stats.txt --gzipped
        
        ## All output files are in the cromwell_root folder
    }
    
    output {
        File profile_mean_shap_scores_h5 = "profile_mean_shap_scores.h5"
        File counts_mean_shap_scores_h5 = "counts_mean_shap_scores.h5"
        File profile_mean_shap_scores_bw = "profile_mean_shap_scores.bw"
        File counts_mean_shap_scores_bw = "counts_mean_shap_scores.bw"
    }
    
    runtime {
        docker: 'vivekramalingam/tf-atlas:gcp-modeling_v2.1.0-rc.1'
        memory: mem_gb + "GB"
        bootDiskSizeGb: 100
        disks: "local-disk 100 HDD"
    }
}

workflow mean_shap {
    input {
        Array [File]? counts_shap
        Array [File]? profile_shap
        File chrom_sizes
        File peaks
        Int? mem_gb = 32
    }

    call run_mean_shap {
        input:
        counts_shap = counts_shap,
        profile_shap = profile_shap,
        chrom_sizes = chrom_sizes,
        peaks = peaks,
        mem_gb = mem_gb
    }
    output {
        File profile_mean_shap_scores_h5 = run_mean_shap.profile_mean_shap_scores_h5
        File counts_mean_shap_scores_h5 = run_mean_shap.counts_mean_shap_scores_h5
        File profile_mean_shap_scores_bw = run_mean_shap.profile_mean_shap_scores_bw
        File counts_mean_shap_scores_bw = run_mean_shap.counts_mean_shap_scores_bw
    }
}