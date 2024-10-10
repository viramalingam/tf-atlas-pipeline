version 1.0

task run_shap {
	input {
		String experiment
		File input_json
		File reference_file
		File reference_file_index
		File chrom_sizes
		File chroms_txt
		Array [File] bigwigs
		File peaks
		Array [File] model
		Int seed
		Int input_seq_len
		Int output_len
		String gpuType

  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch v2.1.0-rc.7 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/shap/

		##shap

		echo "run /my_scripts/tf-atlas-pipeline/anvil/shap/shap_pipeline.sh" ${experiment} ${input_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${sep=',' model} ${seed} ${input_seq_len} ${output_len}
		/my_scripts/tf-atlas-pipeline/anvil/shap/shap_pipeline.sh ${experiment} ${input_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${sep=',' model} ${seed} ${input_seq_len} ${output_len}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/shap_dir_peaks /cromwell_root/
		cp -r /project/shap_dir_peaks/counts_scores.h5 /cromwell_root/counts_scores.h5
		cp -r /project/shap_dir_peaks/profile_scores.h5 /cromwell_root/profile_scores.h5
		cp -r /project/shap_dir_peaks/counts_scores.bw /cromwell_root/counts_scores.bw
		cp -r /project/shap_dir_peaks/profile_scores.bw /cromwell_root/profile_scores.bw
	}
	
	output {
		Array[File] shap_dir_peaks = glob("shap_dir_peaks/*")
		File counts_shap_scores = "counts_scores.h5"
		File profile_shap_scores = "profile_scores.h5"
		File counts_shap_scores_bw = "counts_scores.bw"
		File profile_shap_scores_bw = "profile_scores.bw"
		        
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v2.1.0-rc.1'
		memory: 30 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 100 HDD"
		gpuCount: 1
		gpuType: "nvidia-tesla-" + gpuType
		zones: "us-central1-a us-central1-b us-central1-c us-west1-a us-west1-b us-west1-c us-west4-a us-west4-b us-west4-c us-east1-b us-east1-c us-east1-d us-east4-a us-east4-b us-east4-c us-east5-a us-east5-b us-east5-c us-west2-a us-west2-b us-west2-c us-west3-a us-west3-b us-west3-c" 
		nvidiaDriverVersion: "418.87.00"
		maxRetries: 1
	}
}

workflow shap {
	input {
		String experiment
		File input_json
		File reference_file
		File reference_file_index
		File chrom_sizes
		File chroms_txt
		Array [File] bigwigs
		File peaks
		Array [File] model
		Int seed=0
		Int input_seq_len = 2114
		Int output_len = 1000
		String? gpuType="t4"

	}

	call run_shap {
		input:
			experiment = experiment,
			input_json = input_json,
			reference_file = reference_file,
			reference_file_index = reference_file_index,
			chrom_sizes = chrom_sizes,
			chroms_txt = chroms_txt,
			bigwigs = bigwigs,
			peaks = peaks,
			model = model,
			seed = seed,
			input_seq_len = input_seq_len,
			output_len = output_len,
			gpuType = gpuType
	}
	output {
		Array[File] shap_dir_peaks = run_shap.shap_dir_peaks
		File profile_shap_scores = run_shap.profile_shap_scores
		File counts_shap_scores = run_shap.counts_shap_scores
		File profile_shap_scores_bw = run_shap.profile_shap_scores_bw
		File counts_shap_scores_bw = run_shap.counts_shap_scores_bw
		
	}
}
