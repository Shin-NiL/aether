package project;


import haxe.io.Path;
import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import helpers.ArrayHelper;
import helpers.CompatibilityHelper;
import helpers.LogHelper;
import helpers.ObjectHelper;
import helpers.PathHelper;
import helpers.PlatformHelper;
import helpers.StringHelper;
import helpers.StringMapHelper;
import project.AssetType;
import sys.FileSystem;
import sys.io.File;

#if lime
import helpers.FileHelper;
import helpers.ProcessHelper;
import sys.io.Process;
#end


class HXProject {
	
	
	public var app:ApplicationData;
	public var architectures:Array <Architecture>;
	public var assets:Array <Asset>;
	public var certificate:Keystore;
	public var command:String;
	public var config:ConfigData;
	public var debug:Bool;
	public var defines:Map <String, Dynamic>;
	public var dependencies:Array <Dependency>;
	public var environment:Map <String, String>;
	public var haxedefs:Map <String, Dynamic>;
	public var haxeflags:Array <String>;
	public var haxelibs:Array <Haxelib>;
	public var host (get_host, null):Platform;
	public var icons:Array <Icon>;
	public var javaPaths:Array <String>;
	public var libraries:Array <Library>;
	public var libraryHandlers:Map <String, String>;
	public var meta:MetaData;
	public var ndlls:Array <NDLL>;
	public var platformType:PlatformType;
	public var samplePaths:Array <String>;
	public var sources:Array <String>;
	public var splashScreens:Array <SplashScreen>;
	public var target:Platform;
	public var targetFlags:Map <String, String>;
	public var targetHandlers:Map <String, String>;
	public var templateContext (get_templateContext, null):Dynamic;
	public var templatePaths:Array <String>;
	@:isVar public var window (get, set):Window;
	public var windows:Array <Window>;
	
	private var defaultApp:ApplicationData;
	private var defaultMeta:MetaData;
	private var defaultWindow:Window;
	
	public static var _command:String;
	public static var _debug:Bool;
	public static var _target:Platform;
	public static var _targetFlags:Map <String, String>;
	public static var _templatePaths:Array <String>;
	
	private static var initialized:Bool;
	
	
	public static function main () {
		
		var args = Sys.args ();
		
		if (args.length < 7) {
			
			return;
			
		}
		
		HXProject._command = args[0];
		HXProject._target = cast args[2];
		HXProject._debug = (args[3] == "true");
		HXProject._targetFlags = Unserializer.run (args[4]);
		HXProject._templatePaths = Unserializer.run (args[5]);
		
		initialize ();
		
		var classRef = Type.resolveClass (args[1]);
		var instance = Type.createInstance (classRef, []);
		
		var serializer = new Serializer ();
		serializer.useCache = true;
		serializer.serialize (instance);
		
		File.saveContent (args[6], serializer.toString ());
		
	}
	
	
	public function new () {
		
		initialize ();
		
		command = _command;
		config = new ConfigData ();
		debug = _debug;
		target = _target;
		targetFlags = StringMapHelper.copy (_targetFlags);
		templatePaths = _templatePaths.copy ();
		
		defaultMeta = { title: "MyApplication", description: "", packageName: "com.example.myapp", version: "1.0.0", company: "Example, Inc.", companyUrl: "", buildNumber: "1", companyId: "" }
		defaultApp = { main: "Main", file: "MyApplication", path: "bin", preloader: "", swfVersion: 11.2, url: "" }
		defaultWindow = { width: 800, height: 600, parameters: "{}", background: 0xFFFFFF, fps: 30, hardware: true, display: 0, resizable: true, borderless: false, orientation: Orientation.AUTO, vsync: false, fullscreen: false, antialiasing: 0, allowShaders: true, requireShaders: false, depthBuffer: false, stencilBuffer: false }
		
		platformType = PlatformType.DESKTOP;
		architectures = [];
		
		switch (target) {
			
			case FLASH:
				
				platformType = PlatformType.WEB;
				architectures = [];
				
			case HTML5, EMSCRIPTEN:
				
				platformType = PlatformType.WEB;
				architectures = [];
				
				defaultWindow.width = 0;
				defaultWindow.height = 0;
				defaultWindow.fps = 0;
			
			case FIREFOX:
				
				platformType = PlatformType.MOBILE;
				architectures = [];
				
				defaultWindow.width = 0;
				defaultWindow.height = 0;
				defaultWindow.fps = 0;
				
			case ANDROID, BLACKBERRY, IOS, TIZEN, WEBOS:
				
				platformType = PlatformType.MOBILE;
				
				if (target == Platform.IOS) {
					
					architectures = [ Architecture.ARMV7 ];
					
				} else if (target == Platform.ANDROID) {
					
					architectures = [ Architecture.ARMV7 ];
					
				} else {
					
					architectures = [ Architecture.ARMV6 ];
					
				}
				
				defaultWindow.width = 0;
				defaultWindow.height = 0;
				defaultWindow.fullscreen = true;
				defaultWindow.requireShaders = true;
				
			case WINDOWS, MAC, LINUX:
				
				platformType = PlatformType.DESKTOP;
				
				if (target == Platform.LINUX || target == Platform.MAC) {
					
					architectures = [ PlatformHelper.hostArchitecture ];
					
				} else {
					
					architectures = [ Architecture.X86 ];
					
				}
			
		}
		
		meta = ObjectHelper.copyFields (defaultMeta, {});
		app = ObjectHelper.copyFields (defaultApp, {});
		window = ObjectHelper.copyFields (defaultWindow, {});
		windows = [ window ];
		assets = new Array <Asset> ();
		defines = new Map <String, Dynamic> ();
		dependencies = new Array <Dependency> ();
		environment = Sys.environment ();
		haxedefs = new Map <String, Dynamic> ();
		haxeflags = new Array <String> ();
		haxelibs = new Array <Haxelib> ();
		icons = new Array <Icon> ();
		javaPaths = new Array <String> ();
		libraries = new Array <Library> ();
		libraryHandlers = new Map <String, String> ();
		ndlls = new Array <NDLL> ();
		sources = new Array <String> ();
		samplePaths = new Array <String> ();
		splashScreens = new Array <SplashScreen> ();
		targetHandlers = new Map <String, String> ();
		
	}
	
	
	public function clone ():HXProject {
		
		var project = new HXProject ();
		
		ObjectHelper.copyFields (app, project.app);
		project.architectures = architectures.copy ();
		project.assets = assets.copy ();
		
		for (i in 0...assets.length) {
			
			project.assets[i] = assets[i].clone ();
			
		}
		
		if (certificate != null) {
			
			project.certificate = certificate.clone ();
			
		}
		
		project.command = command;
		project.config = config.clone ();
		project.debug = debug;
		
		for (key in defines.keys ()) {
			
			project.defines.set (key, defines.get (key));
			
		}
		
		for (dependency in dependencies) {
			
			project.dependencies.push (dependency.clone ());
			
		}
		
		for (key in environment.keys ()) {
			
			project.environment.set (key, environment.get (key));
			
		}
		
		for (key in haxedefs.keys ()) {
			
			project.haxedefs.set (key, haxedefs.get (key));
			
		}
		
		project.haxeflags = haxeflags.copy ();
		
		for (haxelib in haxelibs) {
			
			project.haxelibs.push (haxelib.clone ());
			
		}
		
		for (icon in icons) {
			
			project.icons.push (icon.clone ());
			
		}
		
		project.javaPaths = javaPaths.copy ();
		
		for (library in libraries) {
			
			project.libraries.push (library.clone ());
			
		}
		
		for (key in libraryHandlers.keys ()) {
			
			project.libraryHandlers.set (key, libraryHandlers.get (key));
			
		}
		
		ObjectHelper.copyFields (meta, project.meta);
		
		for (ndll in ndlls) {
			
			project.ndlls.push (ndll.clone ());
			
		}
		
		project.platformType = platformType;
		project.samplePaths = samplePaths.copy ();
		project.sources = sources.copy ();
		
		for (splashScreen in splashScreens) {
			
			project.splashScreens.push (splashScreen.clone ());
			
		}
		
		project.target = target;
		
		for (key in targetFlags.keys ()) {
			
			project.targetFlags.set (key, targetFlags.get (key));
			
		}
		
		for (key in targetHandlers.keys ()) {
			
			project.targetHandlers.set (key, targetHandlers.get (key));
			
		}
		
		project.templatePaths = templatePaths.copy ();
		
		for (i in 0...windows.length) {
			
			project.windows[i] = (ObjectHelper.copyFields (windows[i], {}));
			
		}
		
		return project;
		
	}
	
	
	private function filter (text:String, include:Array <String> = null, exclude:Array <String> = null):Bool {
		
		if (include == null) {
			
			include = [ "*" ];
			
		}
		
		if (exclude == null) {
			
			exclude = [];
			
		}
		
		for (filter in exclude) {
			
			if (filter != "") {
				
				filter = StringTools.replace (filter, ".", "\\.");
				filter = StringTools.replace (filter, "*", ".*");
				
				var regexp = new EReg ("^" + filter, "i");
				
				if (regexp.match (text)) {
					
					return false;
					
				}
				
			}
			
		}
		
		for (filter in include) {
			
			if (filter != "") {
				
				filter = StringTools.replace (filter, ".", "\\.");
				filter = StringTools.replace (filter, "*", ".*");
				
				var regexp = new EReg ("^" + filter, "i");
				
				if (regexp.match (text)) {
					
					return true;
					
				}
				
			}
			
		}
		
		return false;
		
	}
	
	
	#if lime
	
	public static function fromFile (projectFile:String, userDefines:Map <String, Dynamic> = null, includePaths:Array <String> = null):HXProject {
		
		var project:HXProject = null;
		
		var path = FileSystem.fullPath (Path.withoutDirectory (projectFile));
		var name = Path.withoutDirectory (Path.withoutExtension (projectFile));
		name = name.substr (0, 1).toUpperCase () + name.substr (1);
		
		var tempDirectory = PathHelper.getTemporaryDirectory ();
		var classFile = PathHelper.combine (tempDirectory, name + ".hx");
		var nekoOutput = PathHelper.combine (tempDirectory, name + ".n");
		var temporaryFile = PathHelper.combine (tempDirectory, "output.dat");
		
		FileHelper.copyFile (path, classFile);
		
		ProcessHelper.runCommand ("", "haxe", [ name, "-main", "project.HXProject", "-cp", tempDirectory, "-neko", nekoOutput, "-lib", "aether", "-lib", "lime" ]);
		ProcessHelper.runCommand ("", "neko", [ FileSystem.fullPath (nekoOutput), HXProject._command, name, Std.string (HXProject._target), Std.string (HXProject._debug), Serializer.run (HXProject._targetFlags), Serializer.run (HXProject._templatePaths), temporaryFile ]);
		
		try {
			
			var outputPath = PathHelper.combine (tempDirectory, "output.dat");
		
			if (FileSystem.exists (outputPath)) {
				
				var output = File.getContent (outputPath);
				var unserializer = new Unserializer (output);
				unserializer.setResolver (cast { resolveEnum: Type.resolveEnum, resolveClass: resolveClass });
				project = unserializer.unserialize ();
				
			}
			
		} catch (e:Dynamic) {}
		
		PathHelper.removeDirectory (tempDirectory);
		
		if (project != null) {
			
			processHaxelibs (project, userDefines);
			
		}
		
		return project;
		
	}
	
	
	public static function fromHaxelib (haxelib:Haxelib, userDefines:Map <String, Dynamic> = null, clearCache:Bool = false):HXProject {
		
		if (haxelib.name == null || haxelib.name == "") {
			
			return null;
			
		}
		
		var path = PathHelper.getHaxelib (haxelib, false, clearCache);
		
		if (path == null || path == "") {
			
			return null;
			
		}
		
		var files = [ "include.lime", "include.nmml", "include.xml" ];
		var found = false;
		
		for (file in files) {
			
			if (!found && FileSystem.exists (PathHelper.combine (path, file))) {
				
				found = true;
				path = PathHelper.combine (path, file);
				
			}
			
		}
		
		if (found) {
			
			return new ProjectXMLParser (path, userDefines);
			
		}
		
		return null;
		
	}
	
	#end
	
	
	private function getHaxelibVersion (haxelib:Haxelib):String {
		
		var version = haxelib.version;
		
		if (version == "" || version == null) {
			
			var haxelibPath = PathHelper.getHaxelib (haxelib);
			var jsonPath = PathHelper.combine (haxelibPath, "haxelib.json");
			
			try {
				
				if (FileSystem.exists (jsonPath)) {
					
					var json = Json.parse (File.getContent (jsonPath));
					version = json.version;
					
				}
				
			} catch (e:Dynamic) {}
			
		}
		
		return version;
		
	}
	
	
	public function include (path:String):Void {
		
		// extend project file somehow?
		
	}
	
	
	public function includeAssets (path:String, rename:String = null, include:Array <String> = null, exclude:Array <String> = null):Void {
		
		if (include == null) {
			
			include = [ "*" ];
			
		}
		
		if (exclude == null) {
			
			exclude = [];
			
		}
		
		exclude = exclude.concat ([ ".*", "cvs", "thumbs.db", "desktop.ini", "*.hash" ]);
			
		if (path == "") {
			
			return;
			
		}
		
		var targetPath = "";
		
		if (rename != null) {
			
			targetPath = rename;
			
		} else {
			
			targetPath = path;
			
		}
		
		if (!FileSystem.exists (path)) {
			
			LogHelper.error ("Could not find asset path \"" + path + "\"");
			return;
			
		}
		
		var files = FileSystem.readDirectory (path);
		
		if (targetPath != "") {
			
			targetPath += "/";
			
		}
		
		for (file in files) {
			
			if (FileSystem.isDirectory (path + "/" + file)) {
				
				if (filter (file, [ "*" ], exclude)) {
					
					includeAssets (path + "/" + file, targetPath + file, include, exclude);
					
				}
				
			} else {
				
				if (filter (file, include, exclude)) {
					
					assets.push (new Asset (path + "/" + file, targetPath + file));
					
				}
				
			}
			
		}
		
	}
	
	
	private static function initialize ():Void {
		
		if (!initialized) {
			
			if (_target == null) {
				
				_target = PlatformHelper.hostPlatform;
				
			}
			
			if (_targetFlags == null) {
				
				_targetFlags = new Map <String, String> ();
				
			}
			
			if (_templatePaths == null) {
				
				_templatePaths = new Array <String> ();
				
			}
			
			initialized = true;
			
		}
		
	}
	
	
	public function merge (project:HXProject):Void {
		
		if (project != null) {
			
			ObjectHelper.copyUniqueFields (project.meta, meta, project.defaultMeta);
			ObjectHelper.copyUniqueFields (project.app, app, project.defaultApp);
			
			for (i in 0...project.windows.length) {
				
				if (i < windows.length) {
					
					ObjectHelper.copyUniqueFields (project.windows[i], windows[i], project.defaultWindow);
					
				} else {
					
					windows.push (ObjectHelper.copyFields (project.windows[i], {}));
					
				}
				
			}
			
			StringMapHelper.copyUniqueKeys (project.defines, defines);
			StringMapHelper.copyUniqueKeys (project.environment, environment);
			StringMapHelper.copyUniqueKeys (project.haxedefs, haxedefs);
			StringMapHelper.copyUniqueKeys (project.libraryHandlers, libraryHandlers);
			StringMapHelper.copyUniqueKeys (project.targetHandlers, targetHandlers);
			
			if (certificate == null) {
				
				certificate = project.certificate;
				
			} else {
				
				certificate.merge (project.certificate);
				
			}
			
			config.merge (project.config);
			
			assets = ArrayHelper.concatUnique (assets, project.assets);
			dependencies = ArrayHelper.concatUnique (dependencies, project.dependencies, true);
			haxeflags = ArrayHelper.concatUnique (haxeflags, project.haxeflags);
			haxelibs = ArrayHelper.concatUnique (haxelibs, project.haxelibs, true, "name");
			icons = ArrayHelper.concatUnique (icons, project.icons);
			javaPaths = ArrayHelper.concatUnique (javaPaths, project.javaPaths, true);
			libraries = ArrayHelper.concatUnique (libraries, project.libraries, true);
			ndlls = ArrayHelper.concatUnique (ndlls, project.ndlls);
			samplePaths = ArrayHelper.concatUnique (samplePaths, project.samplePaths, true);
			sources = ArrayHelper.concatUnique (sources, project.sources, true);
			splashScreens = ArrayHelper.concatUnique (splashScreens, project.splashScreens);
			templatePaths = ArrayHelper.concatUnique (templatePaths, project.templatePaths, true);
			
		}
		
	}
	
	
	public function path (value:String):Void {
		
		if (host == Platform.WINDOWS) {
			
			setenv ("PATH", value + ";" + Sys.getEnv ("PATH"));
			
		} else {
			
			setenv ("PATH", value + ":" + Sys.getEnv ("PATH"));
			
		}
		
	}
	
	
	#if lime
	
	@:noCompletion private static function processHaxelibs (project:HXProject, userDefines:Map <String, Dynamic>):Void {
		
		var haxelibs = project.haxelibs.copy ();
		project.haxelibs = [];
		
		for (haxelib in haxelibs) {
					
			/*if (haxelib.name == "nme" && userDefines.exists ("openfl")) {
				
				haxelib.name = "openfl-nme-compatibility";
				haxelib.version = "";
				
			}*/
			
			project.haxelibs.push (haxelib);
			
			var includeProject = HXProject.fromHaxelib (haxelib, userDefines);
			
			if (includeProject != null) {
				
				for (ndll in includeProject.ndlls) {
					
					if (ndll.haxelib == null) {
						
						ndll.haxelib = haxelib;
						
					}
					
				}
				
				project.merge (includeProject);
				
			}
			
		}
		
	}
	
	
	@:noCompletion private static function resolveClass (name:String):Class <Dynamic> {
		
		var type = Type.resolveClass (name);
		
		if (type == null) {
			
			return HXProject;
			
		} else {
			
			return type;
			
		}
		
	}
	
	#end
	
	
	public function setenv (name:String, value:String):Void {
		
		Sys.putEnv (name, value);
		
	}
	
	
	
	
	// Getters & Setters
	
	
	
	
	private function get_host ():Platform {
		
		return PlatformHelper.hostPlatform;
		
	}
	
	
	private function get_templateContext ():Dynamic {
		
		var context:Dynamic = {};
		
		if (app == null) app = { };
		if (meta == null) meta = { };
		
		if (window == null) {
			
			window = { };
			windows = [ window ];
			
		}
		
		ObjectHelper.copyMissingFields (defaultApp, app);
		ObjectHelper.copyMissingFields (defaultMeta, meta);
		
		for (item in windows) {
			
			ObjectHelper.copyMissingFields (defaultWindow, item);
			
		}
		
		//config.populate ();
		
		for (field in Reflect.fields (app)) {
			
			Reflect.setField (context, "APP_" + StringHelper.formatUppercaseVariable (field), Reflect.field (app, field));
			
		}
		
		context.BUILD_DIR = app.path;
		
		for (key in environment.keys ()) { 
			
			Reflect.setField (context, "ENV_" + key, environment.get (key));
			
		}
		
		for (field in Reflect.fields (meta)) {
			
			Reflect.setField (context, "APP_" + StringHelper.formatUppercaseVariable (field), Reflect.field (meta, field));
			Reflect.setField (context, "META_" + StringHelper.formatUppercaseVariable (field), Reflect.field (meta, field));
			
		}
		
		context.APP_PACKAGE = context.META_PACKAGE = meta.packageName;
		
		for (field in Reflect.fields (windows[0])) {
			
			Reflect.setField (context, "WIN_" + StringHelper.formatUppercaseVariable (field), Reflect.field (windows[0], field));
			Reflect.setField (context, "WINDOW_" + StringHelper.formatUppercaseVariable (field), Reflect.field (windows[0], field));
			
		}
		
		if (windows[0].orientation == Orientation.LANDSCAPE || windows[0].orientation == Orientation.PORTRAIT) {
			
			context.WIN_ORIENTATION = Std.string (windows[0].orientation).toLowerCase ();
			context.WINDOW_ORIENTATION = Std.string (windows[0].orientation).toLowerCase ();
			
		} else {
			
			context.WIN_ORIENTATION = "";
			context.WINDOW_ORIENTATION = "";
			
		}
		
		for (i in 0...windows.length) {
			
			for (field in Reflect.fields (windows[i])) {
				
				Reflect.setField (context, "WINDOW_" + StringHelper.formatUppercaseVariable (field) + "_" + i, Reflect.field (windows[i], field));
				
			}
			
			if (windows[i].orientation == Orientation.LANDSCAPE || windows[i].orientation == Orientation.PORTRAIT) {
				
				Reflect.setField (context, "WINDOW_ORIENTATION_" + i, Std.string (windows[i].orientation).toLowerCase ());
				
			} else {
				
				Reflect.setField (context, "WINDOW_ORIENTATION_" + i, "");
				
			}
			
		}
		
		for (haxeflag in haxeflags) {
			
			if (StringTools.startsWith (haxeflag, "-lib")) {
				
				Reflect.setField (context, "LIB_" + haxeflag.substr (5).toUpperCase (), "true");
				
			}
			
		}
		
		context.assets = new Array <Dynamic> ();
		
		for (asset in assets) {
			
			if (asset.type != AssetType.TEMPLATE) {
				
				var embeddedAsset:Dynamic = { };
				ObjectHelper.copyFields (asset, embeddedAsset);
				
				if (asset.embed == null) {
					
					embeddedAsset.embed = (platformType == PlatformType.WEB || target == Platform.FIREFOX);
					
				}
				
				embeddedAsset.type = Std.string (asset.type).toLowerCase ();
				context.assets.push (embeddedAsset);
				
			}
			
		}
		
		Reflect.setField (context, "ndlls", ndlls);
		//Reflect.setField (context, "sslCaCert", sslCaCert);
		context.sslCaCert = "";
		
		var compilerFlags = [];
		
		for (haxelib in haxelibs) {
			
			var name = haxelib.name;
			
			if (haxelib.version != "") {
				
				name += ":" + haxelib.version;
				
			}
			
			#if lime
			
			var cache = LogHelper.verbose;
			LogHelper.verbose = false;
			var output = "";
			
			try {
				
				output = ProcessHelper.runProcess ("", "haxelib", [ "path", name ], true, true, true);
				
			} catch (e:Dynamic) { }
			
			LogHelper.verbose = cache;
			
			var split = output.split ("\n");
			
			for (arg in split) {
				
				arg = StringTools.trim (arg);
				
				if (arg != "") {
					
					if (!StringTools.startsWith (arg, "-")) {
						
						if (compilerFlags.indexOf ("-cp " + arg) == -1) {
							
							compilerFlags.push ("-cp " + PathHelper.standardize (arg));
							
						}
						
					} else {
						
						if (StringTools.startsWith (arg, "-D ") && arg.indexOf ("=") == -1) {
							
							var haxelib = new Haxelib (arg.substr (3));
							var path = PathHelper.getHaxelib (haxelib);
							var version = getHaxelibVersion (haxelib);
							
							if (path != null) {
								
								CompatibilityHelper.patchProject (this, haxelib, version);
								compilerFlags = ArrayHelper.concatUnique (compilerFlags, [ "-D " + haxelib.name + "=" + version ], true);
								
							}
							
						} else if (!StringTools.startsWith (arg, "-L")) {
							
							compilerFlags = ArrayHelper.concatUnique (compilerFlags, [ arg ], true);
							
						}
						
					}
					
				}
				
			}
			
			#else
			
			compilerFlags.push ("-lib " + name);
			
			#end
			
			Reflect.setField (context, "LIB_" + haxelib.name.toUpperCase (), true);
			
			if (name == "nme") {
				
				context.EMBED_ASSETS = false;
				
			}
			
		}
		
		for (source in sources) {
			
			compilerFlags.push ("-cp " + source);
			
		}
		
		for (key in defines.keys ()) {
			
			var value = defines.get (key);
			
			if (value == null || value == "") {
				
				Reflect.setField (context, "SET_" + key.toUpperCase (), true);
				
			} else {
				
				Reflect.setField (context, "SET_" + key.toUpperCase (), value);
				
			}
			
		}
		
		for (key in haxedefs.keys ()) {
			
			var value = haxedefs.get (key);
			
			if (value == null || value == "") {
				
				compilerFlags.push ("-D " + key);
				
				Reflect.setField (context, "DEFINE_" + key.toUpperCase (), true);
				
			} else {
				
				compilerFlags.push ("-D " + key + "=" + value);
				
				Reflect.setField (context, "DEFINE_" + key.toUpperCase (), value);
				
			}
			
		}
		
		if (target != Platform.FLASH) {
			
			compilerFlags.push ("-D " + Std.string (target).toLowerCase ());
			
		}
		
		compilerFlags.push ("-D " + Std.string (platformType).toLowerCase ());
		compilerFlags = compilerFlags.concat (haxeflags);
		
		if (compilerFlags.length == 0) {
			
			context.HAXE_FLAGS = "";
			
		} else {
			
			context.HAXE_FLAGS = "\n" + compilerFlags.join ("\n");
			
		}
		
		var main = app.main;
		
		if (main == null) {
			
			main = defaultApp.main;
			
		}
		
		var indexOfPeriod = main.lastIndexOf (".");
        
		context.APP_MAIN_PACKAGE = main.substr (0, indexOfPeriod + 1);
		context.APP_MAIN_CLASS = main.substr (indexOfPeriod + 1);
		
		var type = "release";
		
		if (debug) {
			
			type = "debug";
			
		} else if (targetFlags.exists ("final")) {
			
			type = "final";
			
		}
		
		var hxml = Std.string (target).toLowerCase () + "/hxml/" + type + ".hxml";
		
		for (templatePath in templatePaths) {
			
			var path = PathHelper.combine (templatePath, hxml);
			
			if (FileSystem.exists (path)) {
				
				context.HXML_PATH = path;
				
			}
			
		}
		
		for (field in Reflect.fields (context)) {
			
			//Sys.println ("context." + field + " = " + Reflect.field (context, field));
			
		}
		
		context.DEBUG = debug;
		context.SWF_VERSION = app.swfVersion;
		context.PRELOADER_NAME = app.preloader;
		
		if (certificate != null) {
			
			context.KEY_STORE = PathHelper.tryFullPath (certificate.path);
			
			if (certificate.password != null) {
				
				context.KEY_STORE_PASSWORD = certificate.password;
				
			}
			
			if (certificate.alias != null) {
				
				context.KEY_STORE_ALIAS = certificate.alias;
				
			} else if (certificate.path != null) {
				
				context.KEY_STORE_ALIAS = Path.withoutExtension (Path.withoutDirectory (certificate.path));
				
			}
			
			if (certificate.aliasPassword != null) {
				
				context.KEY_STORE_ALIAS_PASSWORD = certificate.aliasPassword;
				
			} else if (certificate.password != null) {
				
				context.KEY_STORE_ALIAS_PASSWORD = certificate.password;
				
			}
			
			if (certificate.identity != null) {
				
				context.KEY_STORE_IDENTITY = certificate.identity;
				
			}
			
		}
		
		context.config = config;
		
		return context;
		
	}
	
	
	private function get_window ():Window {
		
		if (windows != null) {
			
			return windows[0];
			
		} else {
			
			return window;
			
		}
		
	}
	
	
	private function set_window (value:Window):Window {
		
		if (windows != null) {
			
			return windows[0] = window = value;
			
		} else {
			
			return window = value;
			
		}
		
	}
	

}
