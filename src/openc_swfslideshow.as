package {
	
	import flash.display.*;
	import flash.events.*;
	import flash.net.*;
	import flash.utils.*;

	[SWF (width="600", height="300", frameRate="21", backgroundColor="0xf0f0f0", pageTitle="openc.swfslideshow")]
	
	public class openc_swfslideshow extends Sprite {
		
		private var configuration:XML;
		
		private var slides:Array;
		
		private var resourcesDirectory:String = "../resources/";
		
		// Main constuctor
		public function openc_swfslideshow() {
			
			// Load configuration file, assume name and location TODO: allow config URL to be passed in as QS
			var loader:URLLoader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			loader.addEventListener(Event.COMPLETE, handleXMLLoadComplete);
			loader.load(new URLRequest(this.resourcesDirectory + 'config.xml'));
		}
		
		private function readConfiguration():void {
			trace('Reading configuration XML');
			for each(var element:XML in this.configuration.elements()) {
				
				var src:String = this.resourcesDirectory + element.@src;
				
				// Try to load the requested swf
				var loader:Loader = new Loader();
				loader.contentLoaderInfo.addEventListener(Event.INIT, this.handleSlideLoadInit);
				try {
					loader.load(new URLRequest(src));
				}
				catch(e:Error) {
					trace("Couldn't load", src);
					trace(e.message);
				}
				
			}
		}
		
		private function handleSlideLoadInit(e:Event):void {
			
			var movie:MovieClip = e.target.content as MovieClip;
			movie.gotoAndStop(1);
			 
			//trace(MovieClip(e.target.content).totalFrames);
			this.addChild(movie);
		}
		
		private function handleXMLLoadComplete(event:Event):void {
			
			// Try to parse the XML
			try {
				this.configuration = new XML(event.target.data);
				this.readConfiguration();
			}
			catch(e:TypeError) {
				trace("Could not parse configuration XML:");
				trace(e.message);
			}

		}
	}
}
