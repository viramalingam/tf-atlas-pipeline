version 1.0

task run_performance_reports{
	input {
		String experiment
		File peaks
		Array [File] predictions_test_peaks
		Array [File] predictions_all_peaks
		File splits_json


	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch v1.6.7 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/reports/

		##reports

		echo "run /my_scripts/tf-atlas-pipeline/anvil/reports/performance_reports_pipeline.sh" ${experiment} ${peaks} ${sep=',' predictions_test_peaks} ${sep=',' predictions_all_peaks} ${splits_json}
		/my_scripts/tf-atlas-pipeline/anvil/reports/performance_reports_pipeline.sh ${experiment} ${peaks} ${sep=',' predictions_test_peaks} ${sep=',' predictions_all_peaks} ${splits_json}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/reports /cromwell_root/

		ls /project/reports

		
	}
	
	output {

		File performance_reports_peak_only = "reports/performance.html"
		File performance_reports_all_regions = "reports/performance_allpeaks.html"
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-reports'
		memory: 4 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
		maxRetries: 1
	}
}

workflow performance_reports {
	input {
		String experiment
		File peaks
		Array [File] predictions_test_peaks
		Array [File] predictions_all_peaks
		File splits_json

	}

	call run_performance_reports {
		input:
			experiment = experiment,
			peaks = peaks,
			predictions_test_peaks = predictions_test_peaks,
			predictions_all_peaks = predictions_all_peaks,
			splits_json = splits_json
	}
	output {
		File performance_reports_peak_only = run_performance_reports.performance_reports_peak_only
		File performance_reports_all_regions = run_performance_reports.performance_reports_all_regions
	}
}
