package {
	
	import flash.display.*;
	import flash.events.*;
	import flash.net.*;
	import flash.utils.*;

	[SWF (width="600", height="300", frameRate="21", backgroundColor="0xf0f0f0", pageTitle="openc.swfslideshow")]
	
	public class openc_swfslideshow extends Sprite {
		
		private var numSlides:uint;
		
		private var resourcesDirectory:String = "../resources/";
		
		// Main constuctor
		public function openc_swfslideshow() {
			
			var loader:URLLoader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			loader.addEventListener(Event.COMPLETE, handleXMLLoadComplete);
			loader.load(new URLRequest(this.resourcesDirectory + 'config.xml'));
		}

		private function handleXMLLoadComplete(event:Event):void {

			try {
				var config:XML = new XML(event.target.data);
				
				numSlides = config.slide.length();
				var count:uint = 0;
				for each(var slide:XML in config.slide) {
					var src:String = this.resourcesDirectory + slide.@src;
					var loader:Loader = new Loader();
					loader.contentLoaderInfo.addEventListener(
						Event.COMPLETE,
						function(index:uint):Function {
							return function(e:Event):void {
								handleSlideComplete(e, index);
							}
						}(count++)
					);
					loader.load(new URLRequest(src));
				}
			}
			catch(e:TypeError) {
				trace(e.message);
			}
		}
		
		private function handleSlideComplete(e:Event, index:uint):void {
			var movie:MovieClip = e.target.content as MovieClip;
			movie.gotoAndStop(1);
			movie.index = index;
			//movie.visible = false;
			this.addChild(movie);
			
			// If all the slides have loaded
			if(numChildren == numSlides) {
			}
		}
	}
	
}
