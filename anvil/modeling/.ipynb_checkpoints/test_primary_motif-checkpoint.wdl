version 1.0
	
task test_primary_motif {
	input {
		String experiment
		String primary_motifs
		Array [File] model
		File reference_file
		File peaks
		String? sep_training_input_json = 'False'
		File? training_input_json
	
	
	}
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch merge_single_joint_multi https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modeling/
		
		
		#test_primary_motif
		if [ ${sep_training_input_json} = 'False' ]; then
		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/test_primary_motif.sh" ${experiment} "${primary_motifs}" ${sep=',' model} ${reference_file} ${peaks} ''
		/my_scripts/tf-atlas-pipeline/anvil/modeling/test_primary_motif.sh ${experiment} "${primary_motifs}" ${sep=',' model} ${reference_file} ${peaks} ''
		else
		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/test_primary_motif.sh" ${experiment} "${primary_motifs}" ${sep=',' model} ${reference_file} ${peaks} ${training_input_json}
		/my_scripts/tf-atlas-pipeline/anvil/modeling/test_primary_motif.sh ${experiment} "${primary_motifs}" ${sep=',' model} ${reference_file} ${peaks} ${training_input_json}
		fi
		
		echo "copying all files to cromwell_root folder"
		
		cp -r /project/prediction/median_log2_fold_change.txt /cromwell_root/median_log2_fold_change.txt
		cp -r /project/prediction/all_log2_fold_changes.txt /cromwell_root/all_log2_fold_changes.txt
		cp -r /project/prediction/median_log2_fold_change_rc.txt /cromwell_root/median_log2_fold_change_rc.txt
		cp -r /project/prediction/all_log2_fold_changes_rc.txt /cromwell_root/all_log2_fold_changes_rc.txt
		
		cp -r /project/prediction/median_jsd.txt /cromwell_root/median_jsd.txt
		cp -r /project/prediction/all_jsd.txt /cromwell_root/all_jsd.txt
		cp -r /project/prediction/median_jsd_rc.txt /cromwell_root/median_jsd_rc.txt
		cp -r /project/prediction/all_jsd_rc.txt /cromwell_root/all_jsd_rc.txt
	}
	
	output {
		Float primary_log2_fold_change = read_float("median_log2_fold_change.txt")
		String all_log2_fold_changes = read_string("all_log2_fold_changes.txt")
		Float primary_log2_fold_change_rc = read_float("median_log2_fold_change_rc.txt")
		String all_log2_fold_changes_rc = read_string("all_log2_fold_changes_rc.txt")
		
		Float primary_jsd = read_float("median_jsd.txt")
		String all_jsd = read_string("all_jsd.txt")
		Float primary_jsd_rc = read_float("median_jsd_rc.txt")
		String all_jsd_rc = read_string("all_jsd_rc.txt")
	}
	
	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_merge_single_joint_multi'
		memory: 16 + "GB"
		bootDiskSizeGb: 20
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
		String? sep_training_input_json = 'False'
		File? training_input_json
	}
	
	call test_primary_motif {
		input:
			experiment = experiment,
			primary_motifs = primary_motifs,
			model = model,
			reference_file = reference_file,
			peaks = peaks,
			sep_training_input_json = sep_training_input_json,
			training_input_json = training_input_json
	}
	output {
		Float primary_log2_fold_change = test_primary_motif.primary_log2_fold_change
		String all_log2_fold_changes = test_primary_motif.all_log2_fold_changes
		Float primary_log2_fold_change_rc = test_primary_motif.primary_log2_fold_change_rc
		String all_log2_fold_changes_rc = test_primary_motif.all_log2_fold_changes_rc
		     
		Float primary_jsd = test_primary_motif.primary_jsd
		String all_jsd = test_primary_motif.all_jsd
		Float primary_jsd_rc = test_primary_motif.primary_jsd_rc
		String all_jsd_rc = test_primary_motif.all_jsd_rc
	}
}