package helpers;


import haxe.io.Eof;
import haxe.io.Bytes;
import helpers.PlatformHelper;
import neko.Lib;
import project.Platform;
import sys.io.Process;


class LogHelper {
	
	
	public static var enableColor:Bool = true;
	public static var mute:Bool;
	public static var verbose:Bool = false;
	
	private static var colorCodes:EReg = ~/\x1b\[[^m]+m/g;
	private static var colorSupported:Null<Bool>;
	private static var sentWarnings:Map <String, Bool> = new Map <String, Bool> ();
	
	
	public static function error (message:String, verboseMessage:String = "", e:Dynamic = null):Void {
		
		if (message != "" && !mute) {
			
			var output;
			
			if (verbose && verboseMessage != "") {
				
				output = "\x1b[31;1mError:\x1b[0m\x1b[1m " + verboseMessage + "\x1b[0m\n";
				
			} else {
				
				output = "\x1b[31;1mError:\x1b[0m \x1b[1m" + message + "\x1b[0m\n";
				
			}
			
			Sys.stderr ().write (Bytes.ofString (stripColor (output)));
			
		}
		
		if (verbose && e != null) {
			
			Lib.rethrow (e);
			
		}
		
		Sys.exit (1);
		
	}
	
	
	public static function info (message:String, verboseMessage:String = ""):Void {
		
		if (!mute) {
			
			if (verbose && verboseMessage != "") {
				
				println (verboseMessage);
				
			} else if (message != "") {
				
				println (message);
				
			}
			
		}
		
	}
	
	
	public static function print (message:String):Void {
		
		Sys.print (stripColor (message));
		
	}
	
	
	public static function println (message:String):Void {
		
		Sys.println (stripColor (message));
		
	}
	
	
	private static function stripColor (output:String):String {
		
		if (colorSupported == null) {
			
			if (PlatformHelper.hostPlatform != Platform.WINDOWS) {
				
				var result = -1;
				
				try {
					
					var process = new Process ("tput", [ "colors" ]);
					result = process.exitCode ();
					process.close ();
					
				} catch (e:Dynamic) {};
				
				colorSupported = (result == 0);
				
			} else {
				
				colorSupported = false;
				
				if (Sys.getEnv ("TERM") == "xterm" || Sys.getEnv ("ANSICON") != null) {
					
					colorSupported = true;
					
				}
				
			}
			
		}
		
		if (enableColor && colorSupported) {
			
			return output;
			
		} else {
			
			return colorCodes.replace (output, "");
			
		}
		
	}

	public static function progress (prefix:String, now:Int, total:Int):Void {

		print('\r$prefix ( $now / $total )');

	}
	
	
	public static function warn (message:String, verboseMessage:String = "", allowRepeat:Bool = false):Void {
		
		if (!mute) {
			
			var output = "";
			
			if (verbose && verboseMessage != "") {
				
				output = "\x1b[33;1mWarning:\x1b[0m \x1b[1m" + verboseMessage + "\x1b[0m";
				
			} else if (message != "") {
				
				output = "\x1b[33;1mWarning:\x1b[0m \x1b[1m" + message + "\x1b[0m";
				
			}
			
			if (!allowRepeat && sentWarnings.exists (output)) {
				
				return;
				
			}
			
			sentWarnings.set (output, true);
			println (output);
			
		}
		
	}

	public static inline function getChar () {
	   return Sys.getChar (false);
	}

	public static inline function readLine () {
		return Sys.stdin ().readLine ();
	}

	public static function ask (question:String, ?options:Array<String>):Answer {
		
		if (options == null) {

			options = ["y", "n", "a"];

		}

		while (true) {
			
			print ("\x1b[1m" + question + "\x1b[0m \x1b[3;37m[" + options.join("/") + "]\x1b[0m ? ");
			
			switch (readLine ()) {
				case "n": return No;
				case "y": return Yes;
				case "a": return Always;
				case _ => x if(options.indexOf(x) > -1): return Custom(x);
			}
			
		}
		
		return null;
		
	}

	public static function param (name:String, ?passwd:Bool):String {
		
		print (name + ": ");
		
		if (passwd) {
			var s = new StringBuf ();
			var c;
			while ((c = getChar ()) != 13)
				s.addChar (c);
			Lib.print ("");
			Sys.println ("");
			
			return s.toString ();
		}
		
		try {
			
			return readLine ();
			
		} catch (e:Eof) {
			
			return "";
			
		}
		
	}

}

enum Answer {
	Yes;
	No;
	Always;
	Custom(answer:String);
}
