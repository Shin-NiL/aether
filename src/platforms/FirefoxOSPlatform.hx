package platforms;


import helpers.FileHelper;
import helpers.HTML5Helper;
import helpers.FirefoxOSHelper;
import helpers.IconHelper;
import helpers.PathHelper;
import helpers.ZipHelper;
import helpers.LogHelper;
import project.HXProject;
import sys.FileSystem;


class FirefoxOSPlatform extends HTML5Platform {
	
	public function new (command:String, _project:HXProject, targetFlags:Map <String, String>) {
		
		super (command, _project, targetFlags);
		
	}
	
	
	public override function clean ():Void {
		
		var targetPath = project.app.path + "/firefoxos";
		
		if (FileSystem.exists (targetPath)) {
			
			PathHelper.removeDirectory (targetPath);
			
		}
		
	}
	
	
	private override function initialize (command:String, project:HXProject):Void {
		
		outputDirectory = project.app.path + "/firefoxos";
		outputFile = outputDirectory + "/bin/" + project.app.file + ".js";

		if (command == "publish") {

			var result = FirefoxOSHelper.validate(project);
			if (result.errors.length != 0) {

				var errorMsg = "The project can't be published because it has the following errors:";
				for (error in result.errors) {

					errorMsg += "\n\t- " + error;

				}

				errorMsg += "\nPlease refer to the documentation to fix the issues.";

				LogHelper.error(errorMsg);

			}

		}
		
	}
	
	
	public override function run ():Void {
		
		HTML5Helper.launch (project, project.app.path + "/firefoxos/bin");
		
	}
	
	
	public override function update ():Void {
		
		super.update ();
		
		var destination = outputDirectory + "/bin/";
		var context = project.templateContext;
		
		FileHelper.recursiveCopyTemplate (project.templatePaths, "firefoxos/hxml", destination, context);
		FileHelper.recursiveCopyTemplate (project.templatePaths, "firefoxos/template", destination, context);
		
		var sizes = [ 30, 60, 128 ];
		
		for (size in sizes) {
			
			IconHelper.createIcon (project.icons, size, size, PathHelper.combine (destination, "icon-" + size + ".png"));
			
		}
		
	}

	public override function publish ():Void {

		var packagedFile = compress ();

	}

	public function compress ():String {

		var source = outputDirectory + "/bin/";
		var packagedFile = project.app.file + ".zip";
		var destination = outputDirectory + "/dist/" + packagedFile;

		ZipHelper.compress (source, destination);	

		return packagedFile;

	}
	
	
	@ignore public override function install ():Void {}
	@ignore public override function trace ():Void {}
	@ignore public override function uninstall ():Void {}
	
	
}