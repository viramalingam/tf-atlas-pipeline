version 1.0

task run_mean_prediction {
    input {
        Array [File] prediction_h5s
        File chrom_sizes
        Int? mem_gb
    }
    
    command {
        #create data directories and download scripts
        
        cd /; mkdir my_scripts
        cd /my_scripts
        git clone --depth 1 --branch main https://github.com/viramalingam/tf-atlas-pipeline.git
        chmod -R 777 tf-atlas-pipeline
        cd tf-atlas-pipeline/anvil/modeling/
        
        ##mean prediction
        
        mkdir /mean_prediction_data
        
        echo "python /my_scripts/tf-atlas-pipeline/anvil/modeling/mean_predictions.py" --prediction_h5s ${sep=',' prediction_h5s} --generate_bigwigs --chrom_sizes ${chrom_sizes} --output_dir /mean_prediction_data
        
        python /my_scripts/tf-atlas-pipeline/anvil/modeling/mean_predictions.py --prediction_h5s ${sep=',' prediction_h5s} --generate_bigwigs --chrom_sizes ${chrom_sizes} --output_dir /mean_prediction_data
        
            
        ## All output files are in the cromwell_root folder
        
        tar -xvf /mean_prediction_data/* /cromwell_root
        
        tar -cf /cromwell_root/mean_prediction.tar /mean_prediction_data

    }
    
    output {
        File mean_prediction_tar = "mean_prediction.tar"
    }
    
    runtime {
        docker: 'vivekramalingam/tf-atlas:gcp-modeling_v2.1.0-rc.1'
        memory: mem_gb + "GB"
        bootDiskSizeGb: 100
        disks: "local-disk 100 HDD"
    }
}

workflow mean_prediction {
    input {
        Array [File] prediction_h5s
        File chrom_sizes
        Int? mem_gb = 32
    }

    call run_mean_prediction {
        input:
        prediction_h5s = prediction_h5s,
        chrom_sizes = chrom_sizes,
        mem_gb = mem_gb
    }
    output {
        File mean_prediction_tar = run_mean_prediction.mean_prediction_tar
    }
}