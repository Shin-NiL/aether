package helpers;

import haxe.crypto.Base64;
import haxe.io.Path;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import project.HXProject;
import lime.graphics.Image;
import lime.net.*;
import lime.net.oauth.*;
import helpers.LogHelper;
import project.PlatformConfig;

class FirefoxOSHelper {

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
		if(project.meta.description == "" && project.config.firefoxos.description == "") {
			errors.push("The project description is empty.");
		}
		if(project.meta.company == "") {
			errors.push("The project company is empty.");
		}
		if(project.meta.companyUrl == "") {
			errors.push("The project company url is empty.");
		}

		var categories = project.config.firefoxos.categories;

		if(categories.length == 0 || categories.length > MAX_CATEGORIES) {
			errors.push("The project doesn't have enough categories. Please provide up to 2.");
		}

		if(project.config.firefoxos.privacyPolicy == "") {
			errors.push("The privacy policy is empty.");
		}
		if(project.config.firefoxos.supportEmail == "") {
			errors.push("The project support email is empty.");
		}

		var screenshots = project.config.firefoxos.screenshots;

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
		
		entryPoint = (devServer ? FirefoxOSHelper.DEVELOPMENT_SERVER_URL : FirefoxOSHelper.PRODUCTION_SERVER_URL) + API_PATH;

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

		var config = project.config.firefoxos;
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

			uploadingFunc = function(l, up, dl) LogHelper.progress ('$progressMsg', up, data.length);
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