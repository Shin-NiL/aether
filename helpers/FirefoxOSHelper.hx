package helpers;

import project.HXProject;

class FirefoxOSHelper {

	public static function validate (project:HXProject):{errors:Array<String>, warnings:Array<String>} {

		var errors:Array<String> = [];
		var warnings:Array<String> = [];

		// We will check if the project has the minimal required fields for publishing to the Firefox Marketplace
		if(project.meta.title == "") {
			errors.push("The project title is empty.");
		}
		if(project.meta.title.length > 127) {
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

		if(categories.length == 0 || categories.length > 2) {
			errors.push("The project doesn't have enough categories. Please provide up to 2.");
		}

		if(project.config.firefoxos.privacyPolicy == "") {
			errors.push("The privacy policy is empty.");
		}
		if(project.config.firefoxos.supportEmail == "") {
			errors.push("The project support email is empty.");
		}

		return {errors: errors, warnings: warnings};

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