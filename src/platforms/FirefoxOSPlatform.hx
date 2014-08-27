package platforms;


import helpers.FileHelper;
import helpers.HTML5Helper;
import helpers.FirefoxOSHelper;
import helpers.IconHelper;
import helpers.PathHelper;
import helpers.ZipHelper;
import helpers.LogHelper;
import helpers.ProcessHelper;
import project.HXProject;
import sys.FileSystem;
import utils.PlatformSetup;

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

				var errorMsg = "The application can't be published because it has the following errors:";
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

	@:access(utils.PlatformSetup)
	public override function publish ():Void {

		// find the server to publish
		var devServer = project.targetFlags.exists("dev");
		var forceUpload = project.targetFlags.exists("force");
		var answer:Answer;
		if(!devServer) {

			LogHelper.println("In which server do you want to publish your application?");
			LogHelper.println("\t1. Production server.");
			LogHelper.println("\t2. Development server.");
			LogHelper.println("\tq. Quit.");

			answer = LogHelper.ask ("Which server?", ["1", "2", "q"]);

			switch(answer) {
				case Custom(x):
					switch(x) {
						case "2": devServer = true;
						case "q": Sys.exit(0);
					}
				case _:
			}

		}

		var defines = project.defines;
		var existsProd = defines.exists("FIREFOX_MARKETPLACE_KEY") && defines.exists("FIREFOX_MARKETPLACE_SECRET");
		var existsDev = defines.exists("FIREFOX_MARKETPLACE_DEV_KEY") && defines.exists("FIREFOX_MARKETPLACE_DEV_SECRET");

		if ((!existsProd && !devServer) || (!existsDev && devServer)) {

			PlatformSetup.setupFirefoxOS (false, devServer);
			// we need to get all the defines after configuring the account
			defines = PlatformSetup.getDefines ();

		}

		var baseUrl = devServer ? FirefoxOSHelper.DEVELOPMENT_SERVER_URL : FirefoxOSHelper.PRODUCTION_SERVER_URL;
		var appID:Int = -1;
		var appSlug:String = "";
		var appName = project.meta.title;

		var key = defines.get("FIREFOX_MARKETPLACE" + (devServer ? "_DEV_" : "_") + "KEY");
		var secret = defines.get("FIREFOX_MARKETPLACE" + (devServer ? "_DEV_" : "_") + "SECRET");

		var marketplace = new MarketplaceAPI(key, secret, devServer);

		var error = function (r:Dynamic) {
			Reflect.deleteField(r, "error");
			LogHelper.println("");
			LogHelper.error ((r.customError != null ? r.customError : 'There was an error:\n\n$r')); 
		};

		LogHelper.print("Checking user... ");
		var response:Dynamic = marketplace.getUserAccount();

		if(response.error) {

			response.customError = "There was an error validating your account, please verify your account data.";
			error(response);

		}
		LogHelper.println("OK");

		var apps:List<Dynamic> = Lambda.filter(marketplace.getUserApps(), function(obj) return appName == Reflect.field(obj.name, "en-US"));
		if(!forceUpload && apps.length > 0) {
			var app = apps.first();

			LogHelper.println("This application has already been submitted to the Firefox Marketplace.");
			answer = LogHelper.ask ("Do you want to open the edit page?", ["y", "n"]);

			if(answer == Yes) {
				ProcessHelper.openURL(baseUrl + '/developers/app/${app.slug}/edit');
			}
			
			Sys.exit(0);

		}
		
		LogHelper.println("Publishing '" + appName + "' to " + (devServer ? "development server" : "production server"));
		LogHelper.println("");
		LogHelper.print ("Packaging application... ");
		var packagedFile = compress ();
		LogHelper.println ("DONE");
		
		// Start the validation
		response = marketplace.submitForValidation(packagedFile);
		
		if(response.error || response.id == null) {

			error(response);

		}

		var uploadID = response.id;
		LogHelper.println("");
		LogHelper.print ('Server validation ($uploadID)');

		do {
		
			LogHelper.print(".");
			response = marketplace.checkValidationStatus(uploadID);
			Sys.sleep(1);

		} while (!response.processed);

		if(response.valid) {

			LogHelper.println(" VALID");
			LogHelper.print("Creating application... ");
			response = marketplace.createApp(uploadID);

			if(response.error || response.id == null) {

				LogHelper.println("ERROR");
				error(response);

			}

			appID = response.id;
			appSlug = response.slug;

			LogHelper.println("OK");
			LogHelper.print("Updating application information... ");
			response = marketplace.updateAppInformation(appID, project);

			if(response.error) {

				LogHelper.println("ERROR");
				error(response);

			}

			LogHelper.println("OK");
			LogHelper.println("Updating screenshots:");
			var screenshots = project.config.firefoxos.screenshots;
			for(i in 0...screenshots.length) {

				response = marketplace.uploadScreenshot(appID, i, screenshots[i]);
				LogHelper.println("");

				if(response.error) {

					error(response);

				}

			}

			var urlApp = baseUrl + '/app/$appSlug/';
			var devUrlApp = baseUrl + '/developers/app/$appSlug/';
			var urlContentRatings = devUrlApp + "content_ratings/edit";

			var havePayments = project.config.firefoxos.premiumType != Free;

			LogHelper.println("");
			LogHelper.warn ("Before this application can be reviewed & published:");
			LogHelper.warn("* You will need to fill the contents rating questionnaire *");
			if(havePayments) LogHelper.warn("* You will need to add or link a payment account *");
			LogHelper.println("");
			LogHelper.println("1. Open the contents rating questionnaire page.");
			LogHelper.println("2. Open the application edit page.");
			LogHelper.println("3. Open the application listing page.");
			LogHelper.println("q. I'm fine, thanks.");
			answer = LogHelper.ask ("Open the questionnaire now?", ["1", "2", "3", "q"]);

			switch(answer) {

				case Custom(x): 
					switch(x) {
						case "1": ProcessHelper.openURL(urlContentRatings); 
						case "2": ProcessHelper.openURL(devUrlApp);
						case "3": ProcessHelper.openURL(urlApp);
						case _:
					}
				case _:

			}
			
			LogHelper.println("");
			LogHelper.println('Your application listing page is:');
			LogHelper.println('$urlApp');
			LogHelper.println("");
			LogHelper.println('Good bye!');

		} else {

			LogHelper.println(" FAILED");
			LogHelper.println("");
			var errorMsg = "The following errors where presented:";
			var errors:List<Dynamic> = Lambda.filter(response.validation.messages, function(m) return m.type == "error");
			for(error in errors) {

				errorMsg += ('\n\t- ${error.description.join(" ")}');

			}

			errorMsg += "\nPlease refer to the documentation to fix the issues.";
			marketplace.close();
			LogHelper.error(errorMsg);
		}

		marketplace.close();

	}

	public function compress ():String {

		var source = outputDirectory + "/bin/";
		var packagedFile = project.app.file + ".zip";
		var destination = outputDirectory + "/dist/" + packagedFile;

		ZipHelper.compress (source, destination);	

		return destination;

	}
	
	
	@ignore public override function install ():Void {}
	@ignore public override function trace ():Void {}
	@ignore public override function uninstall ():Void {}
	
	
}