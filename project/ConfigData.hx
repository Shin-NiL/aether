package project;


import haxe.xml.Fast;
import helpers.LogHelper;
import helpers.ObjectHelper;


abstract ConfigData(Dynamic) to Dynamic from Dynamic {
	
	
	public function new () {
		
		this = { };
		
	}
	
	
	private function addBucket (bucket:String, parent:Dynamic):Dynamic {
		
		if (!Reflect.hasField (parent, bucket)) {
			
			log ("config data > adding a bucketType " + bucket);
			Reflect.setField (parent, bucket, { });
			
		}
		
		return Reflect.field (parent, bucket);
		
	}
	
	
	public function clone ():ConfigData {
		
		return ObjectHelper.deepCopy (this);
		
	}
	
	
	public function exists (id:String):Bool {
		
		var tree = id.split ('.');
		
		if (tree.length <= 1) {
			
			return Reflect.hasField (this, id);
			
		}
		
		var current = this;
		
		for (leaf in tree) {
			
			if (Reflect.hasField (current, leaf)) {
				
				current = Reflect.field (current, leaf);
				
			} else {
				
				return false;
				
			}
			
		}
		
		return true;
		
	}
	
	
	public function get (id:String):ConfigData {
		
		var tree = id.split ('.');
		
		if (tree.length <= 1) {
			
			return Reflect.field (this, id);
			
		}
		
		var current = this;
		
		for (leaf in tree) {
			
			current = Reflect.field (current, leaf);
			
			if (current == null) {
				
				return null;
				
			}
			
		}
		
		return current;
		
	}
	
	
	public function getArray (id:String, defaultValue:Array<Dynamic> = null):Array<Dynamic> {
		
		var tree = id.split ('.');
		var array:Array<Dynamic> = null;
		
		if (tree.length <= 1) {
			
			array = Reflect.field (this, id + "___array");
			
			if (array == null && Reflect.hasField (this, id)) {
				
				array = [ Reflect.field (this, id) ];
				
			}
			
		} else {
			
			var current = this;
			var field = tree.pop ();
			
			for (leaf in tree) {
				
				current = Reflect.field (current, leaf);
				
				if (current == null) {
					
					break;
					
				}
				
			}
			
			if (current != null) {
				
				array = Reflect.field (current, field + "___array");
				
				if (array == null && Reflect.hasField (current, field)) {
					
					array = [ Reflect.field (current, field) ];
					
				}
				
			}
			
		}
		
		if (array != null) {
			
			return array;
			
		}
		
		if (defaultValue == null) {
			
			defaultValue = [];
			
		}
		
		return defaultValue;
		
	}
	
	
	public function getArrayString (id:String, childField:String = null, defaultValue:Array<String> = null):Array<String> {
		
		var array = getArray (id);
		
		if (array.length > 0) {
			
			var value = [];
			
			if (childField == null) {
				
				for (item in array) {
					
					value.push (Std.string (item));
					
				}
				
			} else {
				
				for (item in array) {
					
					value.push (Std.string (Reflect.field (item, childField)));
					
				}
				
			}
			
			return value;
			
		}
		
		if (defaultValue == null) {
			
			defaultValue = [];
			
		}
		
		return defaultValue;
		
	}
	
	
	public function getBool (id:String, defaultValue:Bool = true):Bool {
		
		if (exists (id)) {
			
			return get (id) == "true";
			
		}
		
		return defaultValue;
		
	}
	
	
	public function getInt (id:String, defaultValue:Int = 0):Int {
		
		if (exists (id)) {
			
			return Std.parseInt (get (id));
			
		}
		
		return defaultValue;
		
	}
	
	
	public function getFloat (id:String, defaultValue:Float = 0):Float {
		
		if (exists (id)) {
			
			return Std.parseFloat (get (id));
			
		}
		
		return defaultValue;
		
	}
	
	
	public function getString (id:String, defaultValue:String = ""):String {
		
		if (exists (id)) {
			
			return Std.string (get (id));
			
		}
		
		return defaultValue;
		
	}
	
	
	private function log (v:Dynamic):Void {
		
		if (LogHelper.verbose) {
			
			//LogHelper.println (v);
			
		}
		
	}
	
	
	public function merge (other:ConfigData):Void {
		
		if (other != null) {
			
			ObjectHelper.copyFieldsPreferObjectOverValue (other, this);
			
		}
		
	}
	
	
	public function parse (elem:Fast):Void {
		
		var bucket = this;
		var bucketType = "";
		
		if (StringTools.startsWith (elem.name, "config:")) {
			
			var items = elem.name.split(':');
			bucketType = items[1];
			
		}
		
		if (elem.has.type) {
			
			bucketType = elem.att.type;
			
		}
		
		if (bucketType != "") {
			
			bucket = addBucket (bucketType, this);
			
		}
		
		parseAttributes (elem, bucket);
		parseChildren (elem, bucket);
		
		log ("> current config : " + this);
		
	}
	
	
	private function parseAttributes (elem:Fast, bucket:Dynamic):Void {
		
		for (attrName in elem.x.attributes ()) {
			
			if (attrName != "type") {
				
				var attrValue = elem.x.get (attrName);
				setNode (bucket, attrName, attrValue);
				
			}
			
		}
		
	}
	
	
	private function parseChildren (elem:Fast, bucket:Dynamic, depth:Int = 0):Void {
		
		for (child in elem.elements) {
			
			if (child.name != "config") {
				
				// log("config data > child : " + child.name);
				
				var d = depth + 1;
				
				var hasChildren = child.x.elements ().hasNext ();
				var hasAttributes = child.x.attributes ().hasNext ();
				
				if (Reflect.hasField (bucket, child.name)) {
					
					if (!Reflect.hasField (bucket, child.name + "___array")) {
						
						Reflect.setField (bucket, child.name + "___array", [ ObjectHelper.deepCopy (Reflect.field (bucket, child.name)) ]);
						
					}
					
					var array:Array<Dynamic> = Reflect.field (bucket, child.name + "___array");
					var arrayBucket = { };
					array.push (arrayBucket);
					
					if (hasAttributes) {
						
						parseAttributes (child, arrayBucket);
						
					}
					
					if (hasChildren) {
						
						parseChildren (child, arrayBucket, d);
						
					}
					
					if (!hasChildren && !hasAttributes) {
						
						parseValue (child, arrayBucket);
						
					}
					
				}
				
				var childBucket = addBucket (child.name, bucket);
				
				if (hasAttributes) {
					
					parseAttributes (child, childBucket);
					
				}
				
				if (hasChildren) {
					
					parseChildren (child, childBucket, d);
					
				}
				
				if (!hasChildren && !hasAttributes) {
					
					parseValue (child, bucket);
					
				}
				
			}
		}
		
	}
	
	
	private function parseValue (elem:Fast, bucket:Dynamic):Void {
		
		if (elem.innerHTML != "") {
			
			setNode (bucket, elem.name, elem.innerHTML);
			
		}
		
	}
	
	
	public function set (id:String, value:Dynamic):Void {
		
		var tree = id.split ('.');
		
		if (tree.length <= 1) {
			
			Reflect.setField (this, id, value);
			
		}
		
		var current = this;
		var field = tree.pop ();
		
		for (leaf in tree) {
			
			current = Reflect.field (current, leaf);
			
			if (current == null) {
				
				return;
				
			}
			
		}
		
		Reflect.setField (current, field, value);
		
	}
	
	
	private function setNode (bucket:Dynamic, node:String, value:Dynamic):Void {
		
		// log("config data > setting a node " + node + " to " + value + " on " + bucket);
		
		var doCopy = true;
		var exists = Reflect.hasField (bucket, node);
		
		if (exists) {
			
			var valueDest = Reflect.field (bucket, node);
			var typeSource = Type.typeof (value).getName ();
			var typeDest = Type.typeof (valueDest).getName ();
			
			// trace(node + " / existed in dest as " + type_dest + " / " + type_source );
			
			if (typeSource != "TObject" && typeDest == "TObject") {
				
				doCopy = false;
				log (node + " not merged by preference over object");
				
			}
			
		}
		
		if (doCopy) {
			
			Reflect.setField (bucket, node, value);
			
		}
		
	}
	
	
}