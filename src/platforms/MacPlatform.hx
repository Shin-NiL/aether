package platforms;


import haxe.io.Path;
import haxe.Template;
import helpers.AssetHelper;
import helpers.CPPHelper;
import helpers.FileHelper;
import helpers.IconHelper;
import helpers.NekoHelper;
import helpers.PathHelper;
import helpers.PlatformHelper;
import helpers.ProcessHelper;
import project.AssetType;
import project.Architecture;
import project.HXProject;
import project.Platform;
import project.PlatformTarget;
import sys.io.File;
import sys.FileSystem;

class MacPlatform extends PlatformTarget {
	
	
	private var applicationDirectory:String;
	private var contentDirectory:String;
	private var executableDirectory:String;
	private var executablePath:String;
	private var is64:Bool;
	private var targetDirectory:String;
	private var useNeko:Bool;
	
	
	public function new (command:String, _project:HXProject, targetFlags:Map <String, String> ) {
		
		super (command, _project, targetFlags);
		
		if (project.targetFlags.exists ("neko") || project.target != PlatformHelper.hostPlatform) {
			
			useNeko = true;
			
		}
		
		for (architecture in project.architectures) {
			
			if (architecture == Architecture.X64) {
				
				is64 = true;
				
			}
			
		}
		
		if (!useNeko) {
			
			targetDirectory = project.app.path + "/mac" + (is64 ? "64" : "") + "/cpp";
			
		} else {
			
			targetDirectory = project.app.path + "/mac" + (is64 ? "64" : "") + "/neko";
			
		}
		
		applicationDirectory = targetDirectory + "/bin/" + project.app.file + ".app";
		contentDirectory = applicationDirectory + "/Contents/Resources";
		executableDirectory = applicationDirectory + "/Contents/MacOS";
		executablePath = executableDirectory + "/" + project.app.file;
		
	}
	
	
	public override function build ():Void {
		
		var type = "release";
		
		if (project.debug) {
			
			type = "debug";
			
		} else if (project.targetFlags.exists ("final")) {
			
			type = "final";
			
		}
		
		var hxml = targetDirectory + "/haxe/" + type + ".hxml";
		
		PathHelper.mkdir (targetDirectory);
		
		for (ndll in project.ndlls) {
			
			FileHelper.copyLibrary (project, ndll, "Mac" + (is64 ? "64" : ""), "", (ndll.haxelib != null && (ndll.haxelib.name == "hxcpp" || ndll.haxelib.name == "hxlibc")) ? ".dylib" : ".ndll", executableDirectory, project.debug);
			
		}
		
		if (useNeko) {
			
			ProcessHelper.runCommand ("", "haxe", [ hxml ]);
			NekoHelper.createExecutable (project.templatePaths, "Mac" + (is64 ? "64" : ""), targetDirectory + "/obj/ApplicationMain.n", executablePath);
			NekoHelper.copyLibraries (project.templatePaths, "Mac" + (is64 ? "64" : ""), executableDirectory);
			
		} else {
			
			var haxeArgs = [ hxml, "-D", "HXCPP_CLANG" ];
			var flags = [ "-DHXCPP_CLANG" ];
			
			if (is64) {
				
				haxeArgs.push ("-D");
				haxeArgs.push ("HXCPP_M64");
				flags.push ("-DHXCPP_M64");
				
			}
			
			ProcessHelper.runCommand ("", "haxe", haxeArgs);
			CPPHelper.compile (project, targetDirectory + "/obj", flags);
			FileHelper.copyFile (targetDirectory + "/obj/ApplicationMain" + (project.debug ? "-debug" : ""), executablePath);
			
		}
		
		if (PlatformHelper.hostPlatform != Platform.WINDOWS) {
			
			ProcessHelper.runCommand ("", "chmod", [ "755", executablePath ]);
			
		}
		
	}
	
	
	public override function clean ():Void {
		
		if (FileSystem.exists (targetDirectory)) {
			
			PathHelper.removeDirectory (targetDirectory);
			
		}
		
	}
	
	
	public override function display ():Void {
		
		var type = "release";
		
		if (project.debug) {
			
			type = "debug";
			
		} else if (project.targetFlags.exists ("final")) {
			
			type = "final";
			
		}
		
		var hxml = PathHelper.findTemplate (project.templatePaths, (useNeko ? "neko" : "cpp") + "/hxml/" + type + ".hxml");
		var template = new Template (File.getContent (hxml));
		Sys.println (template.execute (generateContext ()));
		
	}
	
	
	private function generateContext ():Dynamic {
		
		var context = project.templateContext;
		context.NEKO_FILE = targetDirectory + "/obj/ApplicationMain.n";
		context.CPP_DIR = targetDirectory + "/obj/";
		context.BUILD_DIR = project.app.path + "/mac" + (is64 ? "64" : "");
		
		return context;
		
	}
	
	
	public override function run ():Void {
		
		var arguments = [];
		
		if (project.target == PlatformHelper.hostPlatform) {
			
			arguments = arguments.concat ([ "-livereload" ]);
			ProcessHelper.runCommand (executableDirectory, "./" + Path.withoutDirectory (executablePath), arguments);
			
		}
		
	}
	
	
	public override function update ():Void {
		
		project = project.clone ();
		
		if (project.targetFlags.exists ("xml")) {
			
			project.haxeflags.push ("-xml " + targetDirectory + "/types.xml");
			
		}
		
		var context = generateContext ();
		
		PathHelper.mkdir (targetDirectory);
		PathHelper.mkdir (targetDirectory + "/obj");
		PathHelper.mkdir (targetDirectory + "/haxe");
		PathHelper.mkdir (applicationDirectory);
		PathHelper.mkdir (contentDirectory);
		
		//SWFHelper.generateSWFClasses (project, targetDirectory + "/haxe");
		
		FileHelper.recursiveCopyTemplate (project.templatePaths, "haxe", targetDirectory + "/haxe", context);
		FileHelper.recursiveCopyTemplate (project.templatePaths, (useNeko ? "neko" : "cpp") + "/hxml", targetDirectory + "/haxe", context);
		FileHelper.copyFileTemplate (project.templatePaths, "mac/Info.plist", targetDirectory + "/bin/" + project.app.file + ".app/Contents/Info.plist", context);
		FileHelper.copyFileTemplate (project.templatePaths, "mac/Entitlements.plist", targetDirectory + "/bin/" + project.app.file + ".app/Contents/Entitlements.plist", context);
		
		context.HAS_ICON = IconHelper.createMacIcon (project.icons, PathHelper.combine (contentDirectory,"icon.icns"));
		
		for (asset in project.assets) {
			
			if (asset.embed != true) {
			
				if (asset.type != AssetType.TEMPLATE) {
					
					PathHelper.mkdir (Path.directory (PathHelper.combine (contentDirectory, asset.targetPath)));
					FileHelper.copyAssetIfNewer (asset, PathHelper.combine (contentDirectory, asset.targetPath));
					
				} else {
					
					PathHelper.mkdir (Path.directory (PathHelper.combine (targetDirectory, asset.targetPath)));
					FileHelper.copyAsset (asset, PathHelper.combine (targetDirectory, asset.targetPath), context);
					
				}
				
			}
			
		}
		
		AssetHelper.createManifest (project, PathHelper.combine (contentDirectory, "manifest"));
		
	}
	
	
	@ignore public override function install ():Void {}
	@ignore public override function trace ():Void {}
	@ignore public override function uninstall ():Void {}
	
	
}