package helpers;


//import openfl.display.Bitmap;
//import openfl.display.BitmapData;
//import openfl.display.Shape;
//import openfl.geom.Matrix;
import lime.graphics.Image;
//import format.SVG;


class ImageHelper {
	
	
	public static function rasterizeSVG (svg:Dynamic /*SVG*/, width:Int, height:Int, backgroundColor:Int = null):Image {
		
		/*if (backgroundColor == null) {
			
			backgroundColor = 0x00FFFFFF;
			
		}
		
		var shape = new Shape ();
		svg.render (shape.graphics, 0, 0, width, height);
		
		var bitmapData = new BitmapData (width, height, true, backgroundColor);
		bitmapData.draw (shape);
		
		return bitmapData;*/
		return null;
		
	}
	
	
	public static function resizeImage (image:Image, width:Int, height:Int):Image {
		
		if (image.width == width && image.height == height) {
			
			return image;
			
		}
		
		image.resize (width, height);
		
		return image;
		
	}
	
	
}