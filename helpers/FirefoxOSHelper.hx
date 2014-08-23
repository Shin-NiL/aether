package helpers;

import project.HXProject;
import lime.graphics.Image;
import sys.FileSystem;

class FirefoxOSHelper {

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