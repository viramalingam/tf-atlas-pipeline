version 1.0

task test_primary_motif {
	input {
		String experiment
		String primary_motifs
		Array [File] model
		File reference_file
		File peaks


	}
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch v1.3.8 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modeling/


		#test_primary_motif

		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/test_primary_motif.sh" ${experiment} "${primary_motifs}" ${sep=',' model} ${reference_file} ${peaks}
		/my_scripts/tf-atlas-pipeline/anvil/modeling/test_primary_motif.sh ${experiment} "${primary_motifs}" ${sep=',' model} ${reference_file} ${peaks}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/prediction/median_log2_fold_change.txt /cromwell_root/median_log2_fold_change.txt
		cp -r /project/prediction/all_log2_fold_changes.txt /cromwell_root/all_log2_fold_changes.txt
		cp -r /project/prediction/median_log2_fold_change_rc.txt /cromwell_root/median_log2_fold_change_rc.txt
		cp -r /project/prediction/all_log2_fold_changes_rc.txt /cromwell_root/all_log2_fold_changes_rc.txt
	}
	
	output {
		Float primary_log2_fold_change = read_float("median_log2_fold_change.txt")
		String all_log2_fold_changes = read_string("all_log2_fold_changes.txt")
		Float primary_log2_fold_change_rc = read_float("median_log2_fold_change_rc.txt")
		String all_log2_fold_changes_rc = read_string("all_log2_fold_changes_rc.txt")
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v1.3.0'
		memory: 16 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 20 HDD"
		gpuType: "nvidia-tesla-k80"
		gpuCount: 1
		nvidiaDriverVersion: "418.87.00"
		maxRetries: 1
	}
}

workflow test_primary_motif_workflow {
	input {
		String experiment
		String primary_motifs
		Array [File] model
		File reference_file
		File peaks
	}

	call test_primary_motif {
		input:
			experiment = experiment,
			primary_motifs = primary_motifs,
			model = model,
			reference_file = reference_file,
			peaks = peaks
 	}
	output {
		Float primary_log2_fold_change = test_primary_motif.primary_log2_fold_change
		String all_log2_fold_changes = test_primary_motif.all_log2_fold_changes
		Float primary_log2_fold_change_rc = test_primary_motif.primary_log2_fold_change_rc
		String all_log2_fold_changes_rc = test_primary_motif.all_log2_fold_changes_rc
	}
}