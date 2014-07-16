package platforms;


import helpers.FileHelper;
import helpers.HTML5Helper;
import helpers.IconHelper;
import helpers.PathHelper;
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
	
	
	private override function initialize (project:HXProject):Void {
		
		outputDirectory = project.app.path + "/firefoxos";
		outputFile = outputDirectory + "/bin/" + project.app.file + ".js";
		
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
	
	
	@ignore public override function install ():Void {}
	@ignore public override function trace ():Void {}
	@ignore public override function uninstall ():Void {}
	
	
}