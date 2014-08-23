package project;


import helpers.ArrayHelper;
import helpers.ObjectHelper;
import helpers.FirefoxOSHelper.DeviceType;
import helpers.FirefoxOSHelper.PremiumType;


class PlatformConfig {
	
	
	public var android:AndroidConfig;
	public var cpp:CPPConfig;
	public var ios:IOSConfig;
	public var firefoxos:FirefoxOSConfig;
	
	private static var defaultAndroid:AndroidConfig = {
		
		extensions: [],
		installLocation: "preferExternal",
		minimumSDKVersion: 9,
		permissions: [ "android.permission.WAKE_LOCK", "android.permission.INTERNET", "android.permission.VIBRATE", "android.permission.ACCESS_NETWORK_STATE" ],
		targetSDKVersion: 16
		
	};
	
	private static var defaultCPP:CPPConfig = {
		
		buildLibrary: "hxcpp",
		requireBuild: true
		
	}
	
	private static var defaultIOS:IOSConfig = {
		
		compiler: "clang",
		deployment: /*3.2*/ 5,
		device: IOSConfigDevice.UNIVERSAL,
		linkerFlags: [],
		prerenderedIcon: false
		
	};

	private static var defaultFirefoxOS:FirefoxOSConfig = {
		description: "",
		privacyPolicy: "",
		categories: [],
		applicationURL: "",
		supportURL: "",
		supportEmail: "",
		deviceTypes: [DeviceType.FirefoxOS],
		premiumType: PremiumType.Free,
		price: 0.0,
	}
	
	
	public function new () {
		
		android = { };
		cpp = { };
		ios = { };
		firefoxos = { };
		
		ObjectHelper.copyFields (defaultAndroid, android);
		ObjectHelper.copyFields (defaultCPP, cpp);
		ObjectHelper.copyFields (defaultIOS, ios);
		ObjectHelper.copyFields (defaultFirefoxOS, firefoxos);
		
	}
	
	
	public function clone ():PlatformConfig {
		
		var copy = new PlatformConfig ();
		
		ObjectHelper.copyFields (android, copy.android);
		ObjectHelper.copyFields (defaultCPP, copy.cpp);
		ObjectHelper.copyFields (ios, copy.ios);
		ObjectHelper.copyFields (firefoxos, copy.firefoxos);

		copy.ios.linkerFlags = ios.linkerFlags.copy ();
		
		return copy;
		
	}
	
	
	public function merge (config:PlatformConfig):Void {
		
		var extensions = ArrayHelper.concatUnique (android.extensions, config.android.extensions);
		var permissions = ArrayHelper.concatUnique (android.permissions, config.android.permissions);
		
		ObjectHelper.copyUniqueFields (config.android, android, defaultAndroid);
		
		android.extensions = extensions;
		android.permissions = permissions;

		var linkerFlags = ArrayHelper.concatUnique (ios.linkerFlags, config.ios.linkerFlags);

		ObjectHelper.copyUniqueFields (config.cpp, cpp, defaultCPP);
		ObjectHelper.copyUniqueFields (config.ios, ios, defaultIOS);

		ios.linkerFlags = linkerFlags;

		var categories = ArrayHelper.concatUnique (firefoxos.categories, config.firefoxos.categories);
		var deviceTypes = ArrayHelper.concatUnique (firefoxos.deviceTypes, config.firefoxos.deviceTypes);
		
		ObjectHelper.copyUniqueFields (config.firefoxos, firefoxos, defaultFirefoxOS);

		firefoxos.categories = categories;
		firefoxos.deviceTypes = deviceTypes;
		
	}
	
	
	public function populate ():Void {
		
		ObjectHelper.copyMissingFields (android, defaultAndroid);
		ObjectHelper.copyMissingFields (cpp, defaultCPP);
		ObjectHelper.copyMissingFields (ios, defaultIOS);
		ObjectHelper.copyMissingFields (firefoxos, defaultFirefoxOS);
		
	}
	
	
}


typedef AndroidConfig = {
	
	@:optional var extensions:Array<String>;
	@:optional var installLocation:String;
	@:optional var minimumSDKVersion:Int;
	@:optional var permissions:Array<String>;
	@:optional var targetSDKVersion:Int;
	
}


typedef CPPConfig = {
	
	@:optional var buildLibrary:String;
	@:optional var requireBuild:Bool;
	
}


typedef IOSConfig = {
	
	@:optional var compiler:String;
	@:optional var deployment:Float;
	@:optional var device:IOSConfigDevice;
	@:optional var linkerFlags:Array<String>;
	@:optional var prerenderedIcon:Bool;
	
}

typedef FirefoxOSConfig = {
	@:optional var description:String;
	@:optional var privacyPolicy:String;
	@:optional var categories:Array<String>;
	@:optional var applicationURL:String;
	@:optional var supportURL:String;
	@:optional var supportEmail:String;
	@:optional var deviceTypes:Array<DeviceType>;
	@:optional var premiumType:PremiumType;
	@:optional var price:Float;
}

enum IOSConfigDevice {
	
	UNIVERSAL;
	IPHONE;
	IPAD;
	
}
