package utils.publish;


import helpers.CLIHelper;
import helpers.LogHelper;
import helpers.ZipHelper;
import helpers.ProcessHelper;
import project.HXProject;
import utils.PlatformSetup;
import project.ConfigData;


import haxe.crypto.Base64;
import haxe.io.Path;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import project.HXProject;
import lime.graphics.Image;
import lime.net.*;
import lime.net.oauth.*;
import helpers.CLIHelper;
import helpers.LogHelper;
import project.PlatformConfig;




@:access(utils.PlatformSetup)


class FirefoxMarketplace {
	
	
	private static function compress (project:HXProject):String {
		
		var outputDirectory = project.app.path + "/firefox";
		var source = outputDirectory + "/bin/";
		var packagedFile = project.app.file + ".zip";
		var destination = outputDirectory + "/dist/" + packagedFile;
		
		ZipHelper.compress (source, destination);
		
		return destination;
		
	}
	
	
	public static function isValid (project:HXProject):Bool {
		
		var result = FirefoxHelper.validate (project);
		
		if (result.errors.length != 0) {
			
			var errorMsg = "The application can't be published because it has the following errors:";
			for (error in result.errors) {
				
				errorMsg += "\n\t- " + error;
				
			}
			
			errorMsg += "\nPlease refer to the documentation to fix the issues.";
			
			LogHelper.error (errorMsg);
			
			return false;
			
		}
		
		return true;
		
	}
	
	
	public static function publish (project:HXProject):Void {
		
		var devServer = project.targetFlags.exists ("dev");
		var forceUpload = project.targetFlags.exists ("force");
		var answer:Answer;
		
		if (!devServer) {
			
			LogHelper.println ("In which server do you want to publish your application?");
			LogHelper.println ("\t1. Production server.");
			LogHelper.println ("\t2. Development server.");
			LogHelper.println ("\tq. Quit.");
			
			answer = CLIHelper.ask ("Which server?", ["1", "2", "q"]);
			
			switch (answer) {
				
				case CUSTOM (x):
					
					switch (x) {
						
						case "2": devServer = true;
						case "q": Sys.exit (0);
						
					}
				
				default:
					
				
			}
			
		}
		
		var defines = project.defines;
		var existsProd = defines.exists("FIREFOX_MARKETPLACE_KEY") && defines.exists("FIREFOX_MARKETPLACE_SECRET");
		var existsDev = defines.exists("FIREFOX_MARKETPLACE_DEV_KEY") && defines.exists("FIREFOX_MARKETPLACE_DEV_SECRET");
		
		if ((!existsProd && !devServer) || (!existsDev && devServer)) {
			
			setup (false, devServer);
			// we need to get all the defines after configuring the account
			defines = PlatformSetup.getDefines ();
			
		}
		
		var baseUrl = devServer ? FirefoxHelper.DEVELOPMENT_SERVER_URL : FirefoxHelper.PRODUCTION_SERVER_URL;
		var appID:Int = -1;
		var appSlug:String = "";
		var appName = project.meta.title;
		
		var key = defines.get ("FIREFOX_MARKETPLACE" + (devServer ? "_DEV_" : "_") + "KEY");
		var secret = defines.get ("FIREFOX_MARKETPLACE" + (devServer ? "_DEV_" : "_") + "SECRET");
		
		var marketplace = new MarketplaceAPI (key, secret, devServer);
		
		var error = function (r:Dynamic) {
			
			Reflect.deleteField (r, "error");
			LogHelper.println ("");
			LogHelper.error ((r.customError != null ? r.customError : 'There was an error:\n\n$r')); 
			
		};
		
		LogHelper.print ("Checking user... ");
		var response:Dynamic = marketplace.getUserAccount ();
		
		if (response.error) {
			
			response.customError = "There was an error validating your account, please verify your account data.";
			error (response);
			
		}
		
		LogHelper.println ("OK");
		
		var apps:List<Dynamic> = Lambda.filter (marketplace.getUserApps (), function(obj) return appName == Reflect.field (obj.name, "en-US"));
		
		if (!forceUpload && apps.length > 0) {
			
			var app = apps.first ();
			
			LogHelper.println ("This application has already been submitted to the Firefox Marketplace.");
			answer = CLIHelper.ask ("Do you want to open the edit page?", ["y", "n"]);
			
			if (answer == YES) {
				
				ProcessHelper.openURL (baseUrl + '/developers/app/${app.slug}/edit');
				
			}
			
			Sys.exit (0);
			
		}
		
		LogHelper.println ("Publishing '" + appName + "' to " + (devServer ? "development server" : "production server"));
		LogHelper.println ("");
		LogHelper.print ("Packaging application... ");
		var packagedFile = compress (project);
		LogHelper.println ("DONE");
		
		// Start the validation
		response = marketplace.submitForValidation (packagedFile);
		
		if (response.error || response.id == null) {
			
			error (response);
			
		}
		
		var uploadID = response.id;
		LogHelper.println ("");
		LogHelper.print ('Server validation ($uploadID)');
		
		do {
			
			LogHelper.print (".");
			response = marketplace.checkValidationStatus (uploadID);
			Sys.sleep (1);
			
		} while (!response.processed);
		
		if (response.valid) {
			
			LogHelper.println (" VALID");
			LogHelper.print ("Creating application... ");
			response = marketplace.createApp (uploadID);
			
			if (response.error || response.id == null) {
				
				LogHelper.println ("ERROR");
				error (response);
				
			}
			
			appID = response.id;
			appSlug = response.slug;
			
			LogHelper.println ("OK");
			LogHelper.print ("Updating application information... ");
			response = marketplace.updateAppInformation (appID, project);
			
			if (response.error) {
				
				LogHelper.println ("ERROR");
				error (response);
				
			}
			
			LogHelper.println ("OK");
			LogHelper.println ("Updating screenshots:");
			
			var screenshots:Array<String> = project.config.getArrayString ("firefox-marketplace.screenshots.screenshot", "path");
			
			for (i in 0...screenshots.length) {
				
				response = marketplace.uploadScreenshot (appID, i, screenshots[i]);
				LogHelper.println ("");
				
				if (response.error) {
					
					error (response);
					
				}
				
			}
			
			var urlApp = baseUrl + '/app/$appSlug/';
			var devUrlApp = baseUrl + '/developers/app/$appSlug/';
			var urlContentRatings = devUrlApp + "content_ratings/edit";
			
			var havePayments = project.config.getString ("firefox-marketplace.premiumType") != cast PremiumType.Free;
			
			LogHelper.println ("");
			LogHelper.warn ("Before this application can be reviewed & published:");
			LogHelper.warn ("* You will need to fill the contents rating questionnaire *");
			
			if (havePayments) LogHelper.warn ("* You will need to add or link a payment account *");
			
			LogHelper.println ("");
			LogHelper.println ("1. Open the contents rating questionnaire page.");
			LogHelper.println ("2. Open the application edit page.");
			LogHelper.println ("3. Open the application listing page.");
			LogHelper.println ("q. I'm fine, thanks.");
			
			answer = CLIHelper.ask ("Open the questionnaire now?", ["1", "2", "3", "q"]);
			
			switch (answer) {
				
				case CUSTOM (x):
					
					switch (x) {
						
						case "1": ProcessHelper.openURL (urlContentRatings); 
						case "2": ProcessHelper.openURL (devUrlApp);
						case "3": ProcessHelper.openURL (urlApp);
						case _:
						
					}
				
				default:
					
				
			}
			
			LogHelper.println ("");
			LogHelper.println ("Your application listing page is:");
			LogHelper.println ('$urlApp');
			LogHelper.println ("");
			LogHelper.println ("Goodbye!");
			
		} else {
			
			LogHelper.println (" FAILED");
			LogHelper.println ("");
			
			var errorMsg = "The following errors where presented:";
			
			var errors:List<Dynamic> = Lambda.filter (response.validation.messages, function(m) return m.type == "error");
			for (error in errors) {
				
				errorMsg += ('\n\t- ${error.description.join(" ")}');
				
			}
			
			errorMsg += "\nPlease refer to the documentation to fix the issues.";
			marketplace.close();
			LogHelper.error (errorMsg);
			
		}
		
		marketplace.close();
		
	}
	
	
	public static function setup (?askServer:Bool = true, ?devServer:Bool = false):Void {
		
		var defines = PlatformSetup.getDefines ();
		var existsProd = defines.exists("FIREFOX_MARKETPLACE_KEY") && defines.exists("FIREFOX_MARKETPLACE_SECRET");
		var existsDev = defines.exists("FIREFOX_MARKETPLACE_DEV_KEY") && defines.exists("FIREFOX_MARKETPLACE_DEV_SECRET");

		// TODO warning about the override of the account

		LogHelper.println("To publish your application to the Firefox Marketplace you need to setup an account.");
		var answer = CLIHelper.ask ("Do you want to setup an account now?", ["y", "n"]);

		if(answer == NO) Sys.exit(0);

		var server = "";

		if(askServer) {
			LogHelper.println("");
			LogHelper.println("First of all you need to select the server you want to setup your account.");
			LogHelper.println("Each server has its own configuration and can't be shared.");
			LogHelper.println("\t1. Production server (" + FirefoxHelper.PRODUCTION_SERVER_URL + ")");
			LogHelper.println("\t2. Development server (" + FirefoxHelper.DEVELOPMENT_SERVER_URL + ")");
			LogHelper.println("\tq. Cancel");
			answer = CLIHelper.ask ("Choose the server to setup your Firefox Marketplace account.", ["1", "2", "q"]);
		} else {
			answer = devServer ? CUSTOM("2") : CUSTOM("1");
		}

		switch(answer) {
			case CUSTOM(x):
				switch(x) {
					case "1": 
						server = FirefoxHelper.PRODUCTION_SERVER_URL;
						devServer = false;

					case "2": 
						server = FirefoxHelper.DEVELOPMENT_SERVER_URL; 
						devServer = true;

					case _: Sys.exit(0);
				}
			case _:
		}

		if ((existsProd && !devServer) || (existsDev && devServer)) {

			LogHelper.println("");
			LogHelper.warn ("You will override your account settings!");
			answer = CLIHelper.ask ("Are you sure?", ["y", "n"]);
			if(answer == NO) {
				Sys.exit(0);
			}

		}

		LogHelper.println("");
		LogHelper.println("Follow this instructions once the webpage has opened:");
		LogHelper.println("\t*) Create a new account or login with an existing account.");
		LogHelper.println("\t*) Create a developer API key at: " + server + "/developers/api");
		LogHelper.println("\t*) Choose 'Command line' as the 'Client type' and hit 'Create'.");
		answer = CLIHelper.ask ("Open the webpage?", ["y", "n", "s"]);

		if (answer == YES || answer.match (CUSTOM ("s"))) {

			if(answer == YES) {

				ProcessHelper.openURL(server + "/developers/api");
				LogHelper.println("Once the OAuth key/secret pair has been created, hit Enter.");
				Sys.stdin().readLine();

			}

			var isValid = false;

			LogHelper.println("");
			LogHelper.println("Fill the following fields with the OAuth key/secret pair recently created:");
			var key = StringTools.trim (CLIHelper.param ("Key"));
			var secret = StringTools.trim (CLIHelper.param ("Secret"));

			LogHelper.println("");
			var marketplace = new MarketplaceAPI(key, secret, devServer);
			var name:String = "";
			var account:Dynamic;

			do {

				LogHelper.println("Checking...");
				account = marketplace.getUserAccount();
				
				if (account != null && account.display_name != null) {

					name = account.display_name;
					isValid = true;

				}

				if (!isValid) {

					LogHelper.println("");
					LogHelper.println("There was a problem authenticating your account.");
					answer = CLIHelper.ask ("Do you want to try again?", ["y", "n"]);
					if (answer == YES) {

						key = StringTools.trim (CLIHelper.param ("Key"));
						secret = StringTools.trim (CLIHelper.param ("Secret"));

						marketplace.client.consumer.key = key;
						marketplace.client.consumer.secret = secret;

					} else {

						marketplace.close();
						Sys.exit(0);

					}

				}
			} while (!isValid);
			
			LogHelper.println("");
			LogHelper.println("Hello " + name + " :)");


			defines.set("FIREFOX_MARKETPLACE" + (devServer ? "_DEV_" : "_") + "KEY", key);
			defines.set("FIREFOX_MARKETPLACE" + (devServer ? "_DEV_" : "_") + "SECRET", secret);

			PlatformSetup.writeConfig (defines.get ("HXCPP_CONFIG"), defines);
			LogHelper.println("");
		}

	}
	
	
}


class FirefoxHelper {

	public static inline var PRODUCTION_SERVER_URL = "https://marketplace.firefox.com";
	public static inline var DEVELOPMENT_SERVER_URL = "https://marketplace-dev.allizom.org";

	private static inline var TITLE_MAX_CHARS = 127;
	private static inline var MAX_CATEGORIES = 2;
	private static var MIN_WH_SCREENSHOT = { width: 320, height: 480 };

	public static function validate (project:HXProject):{errors:Array<String>, warnings:Array<String>} {

		var errors:Array<String> = [];
		var warnings:Array<String> = [];

		// We will check if the project has the minimal required fields for publishing to the Firefox Marketplace
		if(project.meta.title == "") {
			errors.push("The project title is empty.");
		}
		if(project.meta.title.length > TITLE_MAX_CHARS) {
			errors.push("The project title is too long.");
		}
		if(project.meta.description == "" && project.config.getString ("firefox-marketplace.description") == "") {
			errors.push("The project description is empty.");
		}
		if(project.meta.company == "") {
			errors.push("The project company is empty.");
		}
		if(project.meta.companyUrl == "") {
			errors.push("The project company url is empty.");
		}

		var categories = project.config.getArrayString ("firefox-marketplace.categories.category", "name");

		if(categories.length == 0 || categories.length > MAX_CATEGORIES) {
			errors.push("The project doesn't have enough categories. Please provide up to 2.");
		}

		if(project.config.getString ("firefox-marketplace.privacyPolicy") == "") {
			errors.push("The privacy policy is empty.");
		}
		if(project.config.getString ("firefox-marketplace.support.email") == "") {
			errors.push("The project support email is empty.");
		}

		var screenshots = project.config.getArrayString ("firefox-marketplace.screenshots.screenshot", "path");

		if(screenshots.length == 0) {
			errors.push("At least 1 screenshot is needed.");
		} else {
			for(path in screenshots) {
				if (!isScreenshotValid(path)) {
					errors.push("Screenshot '" + haxe.io.Path.withoutDirectory(path) + "' doesn't exists or isn't valid.");
				}
			}
		}

		return {errors: errors, warnings: warnings};

	}

	private static function isScreenshotValid(path:String):Bool {

		if (FileSystem.exists(path)) {

			var img = Image.fromFile(path);
			var portrait = img.width >= MIN_WH_SCREENSHOT.width && img.height >= MIN_WH_SCREENSHOT.height;
			var landscape = img.width >= MIN_WH_SCREENSHOT.height && img.height >= MIN_WH_SCREENSHOT.width;
			return portrait || landscape;

		}

		return false;

	}

}

class MarketplaceAPI {

	private static inline var API_PATH = "/api/v1/";

	public var client:OAuthClient;
	private var loader:URLLoader;
	private var entryPoint:String;


	public function new (?key:String, ?secret:String, ?devServer:Bool = false) {

		loader = new URLLoader();
		if(key != null && secret != null) {

			client = new OAuthClient(OAuthVersion.V1, new OAuthConsumer(key, secret));
			
		}
		
		entryPoint = (devServer ? FirefoxHelper.DEVELOPMENT_SERVER_URL : FirefoxHelper.PRODUCTION_SERVER_URL) + API_PATH;

	}

	public function close() {

		loader.close();

	}

	public function getUserAccount():Dynamic {

		var response = load(GET, "account/settings/mine/", null);
		return response;

	}

	public function submitForValidation(path:String, type:String = "application/zip"):Dynamic {

		var p = new Path(path);
		var response:Dynamic = {};

		if (FileSystem.exists(path) && p.ext == "zip") {

			var base = Base64.encode(File.getBytes(path));
			var filename = p.file + "." + p.ext;

			var upload = {
				upload: {
					type: type,
					name: filename,
					data: base
				}
			};

			response = load(POST, "apps/validation/", Json.stringify(upload), "Uploading:");

		} else {
			response.error = true;
			response.customError = 'File $path doesn\'t exist';
		}

		return response;

	}

	public function checkValidationStatus(uploadID:String) {

		var response = load(GET, 'apps/validation/$uploadID/', null);
		return response;

	}

	public function createApp(uploadID:String) {

		var response = load(POST, 'apps/app/', Json.stringify({upload: uploadID}));
		return response;

	}

	public function updateAppInformation(appID:Int, project:HXProject) {
		
		var config:Dynamic = project.config;
		var object = {
			name: project.meta.title,
			categories: config.categories,
			description: config.description,
			privacy_policy: config.privacyPolicy,
			homepage: config.applicationURL,
			support_url: config.supportURL,
			support_email: config.supportEmail,
			device_types: config.deviceTypes,
			premium_type: Std.string(config.premiumType),
			price: Std.string(config.price),
		};

		var response = load(PUT, 'apps/app/$appID/', Json.stringify(object));

		return response;
		
	}

	public function uploadScreenshot(appID:Int, position:Int, path:String) {

		var response:Dynamic = {};

		if (FileSystem.exists(path)) {
			var p = new Path(path);
			var type = p.ext == "png" ? "image/png" : "image/jpeg";
			var base = Base64.encode(File.getBytes(path));
			var filename = p.file + "." + p.ext;

			var screenshot = {
				position: position,
				file: {
					type: type,
					name: filename,
					data: base,
				}
			};

			response = load(POST, 'apps/app/$appID/preview/', Json.stringify(screenshot), '\tUploading ($filename):'); 

		} else {
		
			response.error = true;
			response.customError = 'File $path doesn\'t exist';
		
		}

		return response;

	}

	public function getUserApps():Array<Dynamic> {
		var result:Array<Dynamic> = [];
		var response = load(GET, 'apps/app/', null);

		if(!response.error && response.objects != null) {

			for(obj in cast (response.objects, Array<Dynamic>)) {
				result.push(obj);
			}

		}

		return result;
	}

	private function load(method:URLRequestMethod, path:String, ?data:String, ?progressMsg:String):Dynamic {

		var response:Dynamic = {};
		var status = 0;
		var request = customRequest(method, path, data);
		var withProgress = progressMsg != null && progressMsg.length > 0 && data != null;

		var uploadingFunc:URLLoader->Int->Int->Void = null;
		if(withProgress) {

			uploadingFunc = function(l, up, dl) CLIHelper.progress ('$progressMsg', up, data.length);
			loader.onProgress.add(uploadingFunc);

		}

		loader.onHTTPStatus.add(function(_, s) status = s, true);

		loader.onComplete.add (
			function(l) {
				response = Json.parse(l.data);
				if(withProgress)
					l.onProgress.remove(uploadingFunc);
			}
			, true);

		loader.load(request);

		response.error = false;

		if(status >= 400) {
			response.error = true;
		}

		return response;
		
	}

	public function customRequest(method:URLRequestMethod, path:String, ?data:Dynamic):URLRequest {
		
		var request:URLRequest;
		if(client == null) {

			request = new URLRequest(entryPoint + path);

		} else {

			request = client.createRequest(method, entryPoint + path);

		}

		request.method = method;
		request.data = data;
		request.contentType = "application/json";

		return request;

	}

}

@:enum abstract DeviceType(String) {

	var FirefoxOS = "firefoxos";
	var Desktop = "desktop";
	var Mobile = "mobile";
	var Tablet = "tablet";

}

@:enum abstract PremiumType(String) {

	var Free = "free";
	var FreeInApp = "free-inapp";
	var Premium = "premium";
	var PremiumInApp = "premium-inapp";
	var Other = "other";

}