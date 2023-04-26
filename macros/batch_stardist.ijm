
/* Macro for batch processing image files with StarDist. Saves individual csv files for each image
 *  as well as a csv summary file. Overlays showing segmentation results also created and saved as
 *  pngs.
 *  
 *  https://imagej.net/plugins/stardist
 *  
 *  Schmidt, U., Weigert, M., Broaddus, C., & Myers, G. (2018). Cell Detection with Star-Convex Polygons. 
 *  In Medical Image Computing and Computer Assisted Intervention – MICCAI 2018 (pp. 265–273). 
 *  Springer International Publishing. doi:10.1007/978-3-030-00934-2_30
 *  
*/
// Author: Jeremy Pike
// Course Website: https://jeremypike.github.io/intermediate-image-analysis/

// Contruct a interface using script parameters such that the user can specify both
// a file extension, a directory containing files and which model they want to use.

#@ File (label = "Input directory", style = "directory") input
#@ String (label = "File suffix", value = ".tif") suffix
#@ Boolean (label = "H&E pretrained model? Othewise used fluorescent pretrained model", value = true) he

// Batch mode on/off. Turn off when debugging
setBatchMode(true);

// Create model string as expected by stardist plugin
if (he) {
	model = "Versatile (H&E nuclei)";
}
else {
	model = "Versatile (fluorescent nuclei)";
}

// Specifies what we want to measure for each nuclei
run("Set Measurements...", "area mean min center perimeter redirect=None decimal=3");

// Create a empty table (or clear if exists already) for the summary stats
Table.create("summary_measurments");

// Make sure we start with a clean slate by closing any open image windows as well as clearing the ROI manager / Results table
run("Close All");
roiManager("reset")
run("Clear Results");

// Call our function which processes all images in specified directory (and sub-directories)
processFolder(input);

// Function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, list[i]);
	}
}

// Function to process each file
function processFile(input, file) {

	// This prints to the log window
	print("Processing: " + input + File.separator + file);
	
	open(input + File.separator + file);
	// Rename so we are sure what the image window is called
	rename(file);
	// Run stardist using recorded command. Note modifying the input to use window name and model choice is a bit awkward (string within string).
	// We output results to the ROI manager rather than using masks as this is more convienient for our purposes
	run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args=['input':'" + file + "', 'modelChoice':'" + model + "', 'normalizeInput':'true', 'percentileBottom':'1.0', 'percentileTop':'99.8', 'probThresh':'0.5', 'nmsThresh':'0.4', 'outputType':'ROI Manager', 'nTiles':'1', 'excludeBoundary':'2', 'roiPosition':'Automatic', 'verbose':'false', 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]");
	
	// Make sure we have no individual ROI(s) selected before running measure.
	// This will ouput measurements for each ROI (nuclei) to the Results Table
	roiManager("deselect") 
	roiManager("Show All");
	roiManager("Measure");
	
	// Select the Results Table and retrive the number of rows.
	// This gives us the number of ROI (nuclei) as a variable.
	selectWindow("Results");
	n_nuclei = nResults;
	// We also want the mean/std of the "Area" column as variables for our summary table.
	Array.getStatistics(Table.getColumn("Area") , min_area, max_area, mean_area, std_area);
	
	// We can now add a row to our customised summary table
	selectWindow("summary_measurments");
	row = Table.size;
	Table.set("file", row, file);
	Table.set("n_nuclei", row, n_nuclei);
	Table.set("mean_area", row, mean_area);
	Table.set("std_area", row, std_area);
	Table.update;
	
	// Save both tables as csv files
	selectWindow("Results");
	Table.save(input + File.separator + replace(file, suffix, "_nuclei_stats.csv"));
	selectWindow("summary_measurments");
	Table.save(input + File.separator + "nuclei_summary_measurments.csv");
	
	// This "prints" outlines of the ROIs onto the image before saving as a png
	// For visualisation purposes only
	selectWindow(file);
	roiManager("Show All");
	run("Flatten");
	saveAs("PNG", input + File.separator + replace(file, suffix, "_nuclei_overlay.png"));
	
	// Uncomment this command to pause the script after processing each file. Useful for debugging.
	//waitForUser("OK");
	
	// Clear ROI manager and Results Table
	roiManager("reset")
	run("Clear Results");
	// Close all open images
	run("Close All");
}	
