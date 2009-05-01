package {
	
	import flash.display.*;
	import flash.events.*;
	import flash.net.*;
	import flash.utils.*;

	[SWF (width="600", height="300", frameRate="21", backgroundColor="0xf0f0f0", pageTitle="openc.swfslideshow")]
	
	public class openc_swfslideshow extends Sprite {
		
		private var configuration:XML;
		
		public function openc_swfslideshow() {
			
			// Load configuration file, assume name and location TODO: allow config URL to be passed in as QS
			var loader:URLLoader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			loader.addEventListener(Event.COMPLETE, handleXMLLoadComplete);
			loader.load(new URLRequest('../resources/config.xml'));
		}
		
		private function handleXMLLoadComplete(event:Event):void {
			trace("Load complete");			
		}
	}
}
